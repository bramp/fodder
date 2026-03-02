import 'package:a_star_algorithm/a_star_algorithm.dart';
import 'package:flame/components.dart';

import 'package:fodder_game/game/map/level_map.dart';
import 'package:fodder_game/game/systems/walkability_grid.dart';

/// Wraps the `a_star_algorithm` package to find paths on a [WalkabilityGrid].
class Pathfinder {
  Pathfinder(this._grid);

  final WalkabilityGrid _grid;

  /// Pre-computed barrier list (lazily built on first use).
  List<(int, int)>? _barriers;

  /// Returns the list of impassable tile coordinates.
  List<(int, int)> get barriers {
    if (_barriers != null) return _barriers!;

    final result = <(int, int)>[];
    for (var y = 0; y < _grid.height; y++) {
      for (var x = 0; x < _grid.width; x++) {
        if (!_grid.isWalkable(x, y)) {
          result.add((x, y));
        }
      }
    }
    _barriers = result;
    return result;
  }

  /// Finds a path from [startTile] to [endTile] and returns waypoints in
  /// **pixel coordinates** (tile centre at 2× scale).
  ///
  /// Returns an empty list if no path exists or start == end.
  List<Vector2> findPath({
    required (int, int) startTile,
    required (int, int) endTile,
  }) {
    if (startTile == endTile) return [];

    // Clamp to grid bounds.
    final (sx, sy) = startTile;
    final (ex, ey) = endTile;
    if (sx < 0 || sx >= _grid.width || sy < 0 || sy >= _grid.height) {
      return [];
    }
    if (ex < 0 || ex >= _grid.width || ey < 0 || ey >= _grid.height) {
      return [];
    }

    // If end tile is not walkable, don't even try.
    if (!_grid.isWalkable(ex, ey)) return [];

    final aStar = AStar(
      rows: _grid.height,
      columns: _grid.width,
      start: startTile,
      end: endTile,
      barriers: barriers,
    );

    final path = aStar.findThePath();
    if (path.isEmpty) return [];

    // Convert tile coordinates to pixel-space waypoints (tile centre).
    const tileSize = LevelMap.destTileSize;
    return path.map((record) {
      final (x, y) = record;
      return Vector2(
        x * tileSize + tileSize / 2,
        y * tileSize + tileSize / 2,
      );
    }).toList();
  }
}
