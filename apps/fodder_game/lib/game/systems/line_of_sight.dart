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
  var x0 = (startX / subTileSize).floor();
  var y0 = (startY / subTileSize).floor();
  final x1 = (endX / subTileSize).floor();
  final y1 = (endY / subTileSize).floor();

  // Bresenham's line algorithm.
  final dx = (x1 - x0).abs();
  final dy = -(y1 - y0).abs();
  final sx = x0 < x1 ? 1 : -1;
  final sy = y0 < y1 ? 1 : -1;
  var error = dx + dy;

  for (;;) {
    if (!grid.isSubTileWalkable(x0, y0)) return false;

    if (x0 == x1 && y0 == y1) break;

    final e2 = 2 * error;
    if (e2 >= dy) {
      error += dy;
      x0 += sx;
    }
    if (e2 <= dx) {
      error += dx;
      y0 += sy;
    }
  }

  return true;
}
