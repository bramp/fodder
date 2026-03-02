/// Assigns aggression values to enemies using a ping-pong pattern.
///
/// Given a min/max range, the assigner oscillates back and forth so that
/// enemies on the same map have varying aggression spread evenly across the
/// range.
///
/// See `docs/ENEMY_AI_SPEC.md` §4 for the original algorithm.
class AggressionAssigner {
  /// Creates an assigner that oscillates between [min] and [max].
  ///
  /// The initial value starts at the midpoint `(min + max) ~/ 2`.
  AggressionAssigner({this.min = 4, this.max = 8})
    : assert(min <= max, 'min must be <= max'),
      _current = (min + max) ~/ 2,
      _increment = 1;

  /// Minimum aggression value (inclusive).
  final int min;

  /// Maximum aggression value (inclusive).
  final int max;

  int _current;
  int _increment;

  /// Returns the next aggression value and advances the oscillator.
  int next() {
    final value = _current;

    _current += _increment;

    // Bounce off the boundaries.
    if (_current >= max) {
      _current = max;
      _increment = -1;
    } else if (_current <= min) {
      _current = min;
      _increment = 1;
    }

    return value;
  }

  /// Resets the assigner to the initial state.
  void reset() {
    _current = (min + max) ~/ 2;
    _increment = 1;
  }
}
