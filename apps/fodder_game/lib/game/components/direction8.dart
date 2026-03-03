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
    final angle = atan2(dy, dx);
    final octant = (8 * angle / (2 * pi) + 8).round() % 8;
    // octant 0 is East (angle 0), fodder 0 is South (angle pi/2)
    // adjustment: (octant + 2) % 8 maps East(0)->South(2), etc.
    // wait, let's just use the standard mapping:
    // 0: E, 1: SE, 2: S, 3: SW, 4: W, 5: NW, 6: N, 7: NE
    return const [
      east,
      southeast,
      south,
      southwest,
      west,
      northwest,
      north,
      northeast,
    ][octant];
  }
}

/// A fixed-size container for values mapped to all eight [Direction8] values.
///
/// This provides O(1) lookup and ensures all directions are present.
class Directional<T> {
  /// Creates a [Directional] from a list of values.
  ///
  /// The [_values] must have exactly 8 elements, matching [Direction8.index].
  Directional(this._values)
    : assert(_values.length == 8, 'Directional must have exactly 8 values');

  /// Creates a [Directional] from a map.
  ///
  /// Asserts that all [Direction8] values are present in the map.
  Directional.fromMap(Map<Direction8, T> map)
    : _values = List.generate(8, (i) => map[Direction8.values[i]] as T),
      assert(
        map.length == 8 && Direction8.values.every(map.containsKey),
        'Map must contain all 8 directions',
      );

  final List<T> _values;

  /// Returns the value for the given [direction].
  T operator [](Direction8 direction) => _values[direction.index];

  /// Returns a list of all 8 values.
  List<T> get values => _values;
}
