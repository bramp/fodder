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

/// Semi-transparent green colour used for path dots.
const _pathColor = Color(0xAA00FF00);

/// Debug overlay that draws semi-transparent purple rectangles over
/// non-walkable tiles and visualises the player's current A* path.
///
/// Uses [HasVisibility] so it can stay in the component tree and be
/// toggled on/off cheaply via [isVisible] instead of add/remove.
class DebugBarrierOverlay extends Component with HasVisibility {
  DebugBarrierOverlay({
    required this.grid,
    required this.player,
    bool visible = false,
  }) : super(priority: 20) {
    isVisible = visible;
  }

  WalkabilityGrid grid;
  final PlayerSoldier player;

  @override
  void render(Canvas canvas) {
    const tileSize = LevelMap.destTileSize;

    // Draw terrain type overlays.
    for (var y = 0; y < grid.height; y++) {
      for (var x = 0; x < grid.width; x++) {
        final terrain = grid.terrainAt(x, y);
        final color = _terrainColors[terrain];
        if (color != null) {
          canvas.drawRect(
            Rect.fromLTWH(x * tileSize, y * tileSize, tileSize, tileSize),
            Paint()..color = color,
          );
        }
      }
    }

    // Draw the player's current path as small dots.
    final pathPaint = Paint()..color = _pathColor;
    const dotRadius = 3.0;
    for (final waypoint in player.currentPath) {
      canvas.drawCircle(
        Offset(waypoint.x, waypoint.y),
        dotRadius,
        pathPaint,
      );
    }
  }
}
