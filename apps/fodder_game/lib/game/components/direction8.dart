import 'dart:math';

/// The eight compass directions used for soldier facing / movement.
enum Direction8 {
  /// ↓ South (facing the camera).
  south,

  /// ↙ South-west.
  southwest,

  /// ← West.
  west,

  /// ↖ North-west.
  northwest,

  /// ↑ North (facing away).
  north,

  /// ↗ North-east.
  northeast,

  /// → East.
  east,

  /// ↘ South-east.
  southeast
  ;

  /// Short suffix used in atlas sprite names (e.g. `s`, `sw`, `nw`).
  ///
  /// Matches the naming convention produced by `fodder_tools`.
  String get suffix => const [
    's',
    'sw',
    'w',
    'nw',
    'n',
    'ne',
    'e',
    'se',
  ][index];

  /// Returns the [Direction8] closest to the given movement vector.
  ///
  /// Uses `atan2` to compute the angle and maps it to the nearest octant.
  /// A zero-length vector returns [south] (default facing).
  static Direction8 fromVector(double dx, double dy) {
    if (dx == 0 && dy == 0) return south;

    // atan2(x, y) gives angle from +Y axis (south in screen space),
    // positive clockwise. We want octant 0 = south.
    final angle = atan2(dx, dy); // range (-π, π]
    // Shift to [0, 2π) and divide into 8 octants.
    final octant = ((angle + 2 * pi) % (2 * pi) / (pi / 4)).round() % 8;

    // octant 0 = south, 1 = southeast, 2 = east, ... 7 = southwest
    const lookup = [
      Direction8.south,
      Direction8.southeast,
      Direction8.east,
      Direction8.northeast,
      Direction8.north,
      Direction8.northwest,
      Direction8.west,
      Direction8.southwest,
    ];
    return lookup[octant];
  }
}
