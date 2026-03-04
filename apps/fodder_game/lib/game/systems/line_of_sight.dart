import 'package:fodder_game/game/systems/bresenham_line.dart';
import 'package:fodder_game/game/systems/walkability_grid.dart';

/// Checks line-of-sight between two world positions using the sub-tile
/// walkability grid.
///
/// Uses Bresenham's line algorithm to step through sub-tile cells from
/// [startX],[startY] to [endX],[endY] (world pixel coordinates). Returns
/// `true` if every sub-tile along the line is walkable.
///
/// The [subTileSize] is the pixel width/height of one sub-tile cell
/// (typically 4.0 for 32 px display tiles with 8×8 sub-grid).
bool hasLineOfSight({
  required WalkabilityGrid grid,
  required double startX,
  required double startY,
  required double endX,
  required double endY,
  double subTileSize = 4.0,
}) {
  // Convert world positions to sub-tile coordinates.
  final x0 = (startX / subTileSize).floor();
  final y0 = (startY / subTileSize).floor();
  final x1 = (endX / subTileSize).floor();
  final y1 = (endY / subTileSize).floor();

  for (final (x, y) in bresenhamLine(x0, y0, x1, y1)) {
    if (!grid.isSubTileWalkable(x, y)) return false;
  }

  return true;
}
