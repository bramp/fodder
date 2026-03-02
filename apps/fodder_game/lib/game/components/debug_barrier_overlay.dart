import 'dart:ui';

import 'package:flame/components.dart';

import 'package:fodder_game/game/components/player_soldier.dart';
import 'package:fodder_game/game/map/level_map.dart';
import 'package:fodder_game/game/systems/walkability_grid.dart';

/// Semi-transparent colours for each terrain type in the debug overlay.
///
/// Only non-Land types are drawn (Land is left transparent).
const _terrainColors = <TerrainType, Color>{
  // TerrainType.land is not drawn (transparent).
  TerrainType.rocky: Color(0x55888888), // grey
  TerrainType.rocky2: Color(0x55666666), // dark grey
  TerrainType.block: Color(0x88800080), // purple (impassable)
  TerrainType.quickSand: Color(0x55FFD700), // gold
  TerrainType.waterEdge: Color(0x550055CC), // dark blue
  TerrainType.water: Color(0x550077FF), // blue
  TerrainType.snow: Color(0x55FFFFFF), // white
  TerrainType.quickSandEdge: Color(0x55CCAA00), // dark gold
  TerrainType.drop: Color(0x55CC4444), // dark red
  TerrainType.drop2: Color(0x55FF8800), // orange
  TerrainType.sink: Color(0x55FF00FF), // magenta
  TerrainType.terrainC: Color(0x55FF44FF), // light magenta
  TerrainType.terrainD: Color(0x5500CCCC), // teal
  TerrainType.jump: Color(0x5500AAAA), // dark teal
};

/// Pre-built [Paint] objects for each terrain colour. Created once to avoid
/// per-frame allocations.
final Map<TerrainType, Paint> _terrainPaints = {
  for (final entry in _terrainColors.entries)
    entry.key: (Paint()..color = entry.value),
};

/// Semi-transparent green colour used for path dots.
final Paint _pathPaint = Paint()..color = const Color(0xAA00FF00);

/// Debug overlay that draws semi-transparent coloured rectangles over
/// non-walkable tiles and visualises the player's current A* path.
///
/// For mixed-terrain tiles (tiles with sub-tile bitmask data), the overlay
/// renders each of the 8×8 sub-tile cells individually, showing the exact
/// terrain boundary within the tile.
///
/// The static terrain overlay is recorded into a [Picture] once and replayed
/// each frame. Only the path dots are drawn dynamically. Call
/// [invalidateCache] (or assign a new [grid]) to rebuild after a map change.
///
/// Uses [HasVisibility] so it can stay in the component tree and be
/// toggled on/off cheaply via [isVisible] instead of add/remove.
class DebugBarrierOverlay extends Component with HasVisibility {
  DebugBarrierOverlay({
    required WalkabilityGrid grid,
    required this.player,
    bool visible = false,
  }) : _grid = grid,
       super(priority: 20) {
    isVisible = visible;
  }

  WalkabilityGrid _grid;
  final PlayerSoldier player;

  /// Cached picture of the static terrain overlay.
  Picture? _cachedPicture;

  /// Updates the walkability grid and invalidates the cached picture.
  set grid(WalkabilityGrid value) {
    _grid = value;
    invalidateCache();
  }

  /// Returns the current walkability grid.
  WalkabilityGrid get grid => _grid;

  /// Forces the cached terrain picture to be rebuilt on the next render.
  void invalidateCache() {
    _cachedPicture?.dispose();
    _cachedPicture = null;
  }

  @override
  void onRemove() {
    _cachedPicture?.dispose();
    _cachedPicture = null;
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    // Draw cached static terrain overlay.
    _cachedPicture ??= _buildTerrainPicture();
    canvas.drawPicture(_cachedPicture!);

    // Draw the player's current path as small dots.
    const dotRadius = 1.5;
    for (final waypoint in player.currentPath) {
      canvas.drawCircle(
        Offset(waypoint.x, waypoint.y),
        dotRadius,
        _pathPaint,
      );
    }
  }

  /// Records all static terrain rectangles into a [Picture].
  Picture _buildTerrainPicture() {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    const tileSize = LevelMap.destTileSize;
    const subCellSize = LevelMap.destSubTileSize;

    for (var tileY = 0; tileY < _grid.height; tileY++) {
      for (var tileX = 0; tileX < _grid.width; tileX++) {
        if (_grid.hasSubTileData(tileX, tileY)) {
          _renderSubTileCells(canvas, tileX, tileY, tileSize, subCellSize);
        } else {
          final terrain = _grid.terrainAt(tileX, tileY);
          final paint = _terrainPaints[terrain];
          if (paint != null) {
            canvas.drawRect(
              Rect.fromLTWH(
                tileX * tileSize,
                tileY * tileSize,
                tileSize,
                tileSize,
              ),
              paint,
            );
          }
        }
      }
    }

    return recorder.endRecording();
  }

  /// Renders the 8×8 sub-tile grid for a mixed-terrain tile.
  void _renderSubTileCells(
    Canvas canvas,
    int tileX,
    int tileY,
    double tileSize,
    double subCellSize,
  ) {
    final baseX = tileX * 8;
    final baseY = tileY * 8;
    for (var sy = 0; sy < 8; sy++) {
      for (var sx = 0; sx < 8; sx++) {
        // Read terrain directly from the sub-tile grid since this is only
        // called for tiles that have sub-tile data.
        final gx = baseX + sx;
        final gy = baseY + sy;
        final terrain = _grid.subTileTerrainAtGlobal(gx, gy);
        final paint = _terrainPaints[terrain];
        if (paint != null) {
          canvas.drawRect(
            Rect.fromLTWH(
              tileX * tileSize + sx * subCellSize,
              tileY * tileSize + sy * subCellSize,
              subCellSize,
              subCellSize,
            ),
            paint,
          );
        }
      }
    }
  }
}
