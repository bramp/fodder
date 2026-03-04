/// Yields all integer grid cells along a line from ([x0], [y0]) to
/// ([x1], [y1]) using Bresenham's line algorithm.
///
/// The line includes both endpoints. Cells are yielded in order from
/// start to end.
Iterable<(int, int)> bresenhamLine(int x0, int y0, int x1, int y1) sync* {
  final dx = (x1 - x0).abs();
  final dy = -(y1 - y0).abs();
  final sx = x0 < x1 ? 1 : -1;
  final sy = y0 < y1 ? 1 : -1;
  var error = dx + dy;

  var x = x0;
  var y = y0;

  for (;;) {
    yield (x, y);

    if (x == x1 && y == y1) break;

    final e2 = 2 * error;
    if (e2 >= dy) {
      error += dy;
      x += sx;
    }
    if (e2 <= dx) {
      error += dx;
      y += sy;
    }
  }
}
