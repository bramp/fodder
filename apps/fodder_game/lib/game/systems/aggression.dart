/// Hard cap on [AggressionAssigner.max] after escalation (original: 0x1E).
const int aggressionMaxCap = 30;

/// Assigns aggression values to enemies using a ping-pong pattern.
///
/// Given a min/max range, the assigner oscillates back and forth so that
/// enemies on the same map have varying aggression spread evenly across the
/// range.
///
/// See `docs/ENEMY_AI.md` §4 for the original algorithm.
class AggressionAssigner {
  /// Creates an assigner that oscillates between [min] and [max].
  ///
  /// The initial value starts at the midpoint `(min + max) ~/ 2`.
  AggressionAssigner({this.min = 4, int max = 8})
    : assert(min <= max, 'min must be <= max'),
      _max = max,
      _current = (min + max) ~/ 2,
      _increment = 1;

  /// Minimum aggression value (inclusive).
  final int min;

  /// Maximum aggression value (inclusive). Increases via [recordDynamicSpawn].
  int get max => _max;
  int _max;

  /// The average of [min] and [max] (`(min + max) ~/ 2`).
  ///
  /// Used as the threshold for movement-targeting precision:
  /// when `average < 5`, enemies scatter more widely.
  int get average => (min + _max) ~/ 2;

  int _current;
  int _increment;

  /// Counter of dynamic spawns since last escalation.
  int _spawnCount = 0;

  /// Returns the next aggression value and advances the oscillator.
  int next() {
    final value = _current;

    _current += _increment;

    // Bounce off the boundaries.
    if (_current >= _max) {
      _current = _max;
      _increment = -1;
    } else if (_current <= min) {
      _current = min;
      _increment = 1;
    }

    return value;
  }

  /// Records a dynamic enemy spawn and escalates [max] every
  /// 16 spawns, up to [aggressionMaxCap] (30).
  ///
  /// Call this for enemies spawned from buildings/holes — not for
  /// enemies placed statically on the map.
  void recordDynamicSpawn() {
    _spawnCount = (_spawnCount + 1) & 0x0F;
    if (_spawnCount == 0 && _max < aggressionMaxCap) {
      _max++;
    }
  }

  /// Resets the assigner to the initial state.
  void reset() {
    _current = (min + _max) ~/ 2;
    _increment = 1;
    _spawnCount = 0;
  }
}
