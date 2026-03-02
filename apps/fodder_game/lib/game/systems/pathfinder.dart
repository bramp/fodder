import 'dart:collection';

import 'package:flame/components.dart';

import 'package:fodder_game/game/map/level_map.dart';
import 'package:fodder_game/game/systems/walkability_grid.dart';

/// A* pathfinder operating on a [WalkabilityGrid] at **sub-tile** resolution
/// (8× the tile grid).
///
/// Each 16×16 tile is divided into an 8×8 grid of sub-tile cells. The
/// pathfinder queries [WalkabilityGrid.isSubTileWalkable] directly — no
/// barrier list or internal grid is ever allocated.
class Pathfinder {
  Pathfinder(this._grid);

  final WalkabilityGrid _grid;

  /// Finds a path from [start] to [end] (both in **sub-tile** coordinates)
  /// and returns waypoints in **pixel coordinates** (at 2× scale).
  ///
  /// Sub-tile coordinates are global grid indices where each tile has
  /// 8×8 sub-cells. Returns an empty list if no path exists or
  /// start == end.
  List<Vector2> findPath({
    required (int, int) start,
    required (int, int) end,
  }) {
    if (start == end) return [];

    final (sx, sy) = start;
    final (ex, ey) = end;

    // Bounds check.
    if (sx < 0 ||
        sx >= _grid.subTileWidth ||
        sy < 0 ||
        sy >= _grid.subTileHeight) {
      return [];
    }
    if (ex < 0 ||
        ex >= _grid.subTileWidth ||
        ey < 0 ||
        ey >= _grid.subTileHeight) {
      return [];
    }

    // If end sub-tile is not walkable, don't even try.
    if (!_grid.isSubTileWalkable(ex, ey)) return [];

    final path = _astar(sx, sy, ex, ey);
    if (path.isEmpty) return [];

    // Convert sub-tile coordinates to pixel-space waypoints (cell centre).
    const subTileSize = LevelMap.destSubTileSize;
    return path.map((node) {
      return Vector2(
        node.$1 * subTileSize + subTileSize / 2,
        node.$2 * subTileSize + subTileSize / 2,
      );
    }).toList();
  }

  /// Standard A* with 8-directional movement.
  ///
  /// Returns the path as a list of `(x, y)` sub-tile coordinates
  /// (excluding the start, including the end), or an empty list if
  /// no path exists.
  List<(int, int)> _astar(int sx, int sy, int ex, int ey) {
    final w = _grid.subTileWidth;

    // Encode (x,y) as a single int for cheap Set/Map keys.
    int key(int x, int y) => y * w + x;

    final startKey = key(sx, sy);
    final endKey = key(ex, ey);

    // g-score: cost from start to this node.
    final gScore = <int, double>{startKey: 0};

    // f-score: g + heuristic.
    final fScore = <int, double>{startKey: _heuristic(sx, sy, ex, ey)};

    // For path reconstruction: node → parent.
    final cameFrom = <int, int>{};

    // Open set as a min-heap ordered by f-score.
    final open = SplayTreeMap<double, List<int>>();
    void addOpen(int k, double f) {
      (open[f] ??= []).add(k);
    }

    void removeOpen(int k, double f) {
      final list = open[f];
      if (list != null) {
        list.remove(k);
        if (list.isEmpty) open.remove(f);
      }
    }

    addOpen(startKey, fScore[startKey]!);

    final closed = <int>{};

    // 8 neighbours: 4 cardinal + 4 diagonal.
    const dirs = [
      (1, 0),
      (-1, 0),
      (0, 1),
      (0, -1),
      (1, 1),
      (1, -1),
      (-1, 1),
      (-1, -1),
    ];
    const sqrt2 = 1.4142135623730951;

    while (open.isNotEmpty) {
      // Pop the node with the smallest f-score.
      final bestF = open.firstKey()!;
      final bucket = open[bestF]!;
      final currentKey = bucket.removeLast();
      if (bucket.isEmpty) open.remove(bestF);

      if (currentKey == endKey) {
        return _reconstruct(cameFrom, endKey, w);
      }

      closed.add(currentKey);

      final cx = currentKey % w;
      final cy = currentKey ~/ w;

      for (final (dx, dy) in dirs) {
        final nx = cx + dx;
        final ny = cy + dy;

        if (nx < 0 ||
            nx >= _grid.subTileWidth ||
            ny < 0 ||
            ny >= _grid.subTileHeight) {
          continue;
        }

        final nk = key(nx, ny);
        if (closed.contains(nk)) continue;

        if (!_grid.isSubTileWalkable(nx, ny)) {
          closed.add(nk); // mark unwalkable as closed so we never revisit
          continue;
        }

        // For diagonal moves, also check that the two adjacent cardinal
        // neighbours are walkable (prevents corner-cutting through walls).
        if (dx != 0 && dy != 0) {
          if (!_grid.isSubTileWalkable(cx + dx, cy) ||
              !_grid.isSubTileWalkable(cx, cy + dy)) {
            continue;
          }
        }

        final moveCost = (dx != 0 && dy != 0) ? sqrt2 : 1.0;
        final tentativeG = gScore[currentKey]! + moveCost;

        final prevG = gScore[nk];
        if (prevG != null && tentativeG >= prevG) continue;

        // Remove old entry from open set if present.
        if (prevG != null) {
          removeOpen(nk, fScore[nk]!);
        }

        cameFrom[nk] = currentKey;
        gScore[nk] = tentativeG;
        final f = tentativeG + _heuristic(nx, ny, ex, ey);
        fScore[nk] = f;
        addOpen(nk, f);
      }
    }

    return []; // No path found.
  }

  /// Chebyshev-style heuristic (consistent with 8-directional movement
  /// where diagonal cost = √2).
  static double _heuristic(int ax, int ay, int bx, int by) {
    final dx = (ax - bx).abs();
    final dy = (ay - by).abs();
    // Octile distance: straight moves cost 1, diagonal moves cost √2.
    const d = 1.0;
    const d2 = 1.4142135623730951;
    final mn = dx < dy ? dx : dy;
    final mx = dx > dy ? dx : dy;
    return d * (mx - mn) + d2 * mn;
  }

  /// Reconstructs the path from [cameFrom] map.
  static List<(int, int)> _reconstruct(
    Map<int, int> cameFrom,
    int endKey,
    int width,
  ) {
    final path = <(int, int)>[];
    var current = endKey;
    while (cameFrom.containsKey(current)) {
      path.add((current % width, current ~/ width));
      current = cameFrom[current]!;
    }
    return path.reversed.toList();
  }
}
