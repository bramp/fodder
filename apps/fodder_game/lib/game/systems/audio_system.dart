import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame_audio/flame_audio.dart';

/// Central audio component for Cannon Fodder sound effects.
///
/// Added as a child of the `FlameGame` so it benefits from Flame's component
/// lifecycle (`onLoad` for preloading, `onRemove` for cleanup).
///
/// Components in the tree access it via the [HasAudioSystem] mixin rather
/// than coupling to a concrete game class.
class AudioSystem extends Component {
  /// Creates an [AudioSystem].
  ///
  /// An optional [random] can be injected for deterministic testing.
  AudioSystem({Random? random}) : _random = random ?? Random();

  final Random _random;

  static const String _prefix = 'packages/fodder_assets/assets/cf1/audio/';

  /// Maximum number of concurrent sound effects allowed.
  ///
  /// Prevents audio glitches when many events fire simultaneously (e.g.
  /// rapid-fire gunshots or multiple deaths in a single frame).
  static const int maxConcurrentSounds = 8;

  /// Number of sounds currently playing.
  int _activeSounds = 0;

  /// List of all sound files to preload.
  static const List<String> _allFiles = [
    'death_1.wav',
    'death_2.wav',
    'death_3.wav',
    'death_4.wav',
    'death_5.wav',
    'death_6.wav',
    'explosion_1.wav',
    'explosion_2.wav',
    'explosion_3.wav',
    'explosion_4.wav',
    'grenade_explosion.wav',
    'gunshot_impact.wav',
    'gunshot_low.wav',
    'helicopter_idle.wav',
    'helicopter_rotor_1.wav',
    'helicopter_rotor_2.wav',
    'helicopter_rotor_3.wav',
    'helicopter_rotor_4.wav',
    'ice_ambience.wav',
    'ice_bird.wav',
    'interior_bird.wav',
    'jeep_engine_1.wav',
    'jeep_engine_2.wav',
    'jeep_engine_3.wav',
    'jeep_engine_4.wav',
    'jungle_bird.wav',
    'missile_launch.wav',
    'moor_bird.wav',
    'seal_footstep.wav',
    'tank_engine.wav',
  ];

  @override
  Future<void> onLoad() async {
    FlameAudio.audioCache.prefix = '';
    await FlameAudio.audioCache.loadAll(
      _allFiles.map((f) => '$_prefix$f').toList(),
    );
  }

  @override
  void onRemove() {
    // ignore: discarded_futures, clearAll returns void in practice.
    FlameAudio.audioCache.clearAll();
    super.onRemove();
  }

  /// Plays a sound file, respecting the concurrency limit.
  ///
  /// Returns immediately without playing if [maxConcurrentSounds] are already
  /// active.
  void _play(String file) {
    if (_activeSounds >= maxConcurrentSounds) return;
    _activeSounds++;
    unawaited(
      FlameAudio.play('$_prefix$file')
          .then((_) {
            _activeSounds--;
          })
          .catchError((_) {
            _activeSounds--;
          }),
    );
  }

  /// Plays a random death scream.
  void playDeathScream() {
    final n = _random.nextInt(6) + 1;
    _play('death_$n.wav');
  }

  /// Plays a random explosion sound.
  void playExplosion() {
    final n = _random.nextInt(4) + 1;
    _play('explosion_$n.wav');
  }

  /// Plays a gunshot sound.
  void playGunshot() {
    // Original game randomly picks between ALL16 and ALL17 (0x10 and 0x11).
    final file = _random.nextBool() ? 'gunshot_low.wav' : 'gunshot_impact.wav';
    _play(file);
  }

  /// Plays a bullet impact sound.
  void playImpact() {
    _play('gunshot_impact.wav');
  }

  /// Plays a grenade explosion.
  void playGrenadeExplosion() {
    _play('grenade_explosion.wav');
  }

  /// Plays a missile launch sound.
  void playMissileLaunch() {
    _play('missile_launch.wav');
  }
}

/// A silent [AudioSystem] replacement for tests.
///
/// Records every play call so tests can verify that the correct sounds are
/// triggered without loading real audio assets.
class SilentAudioSystem extends AudioSystem {
  /// Creates a silent audio system with an optional deterministic [random].
  SilentAudioSystem({super.random});

  /// Log of method names called, in order (e.g. `['playGunshot',
  /// 'playDeathScream']`).
  final List<String> calls = [];

  @override
  Future<void> onLoad() async {
    // No-op: don't load real audio.
  }

  @override
  void onRemove() {
    // No-op: nothing to clean up.
  }

  @override
  void playDeathScream() => calls.add('playDeathScream');

  @override
  void playExplosion() => calls.add('playExplosion');

  @override
  void playGunshot() => calls.add('playGunshot');

  @override
  void playImpact() => calls.add('playImpact');

  @override
  void playGrenadeExplosion() => calls.add('playGrenadeExplosion');

  @override
  void playMissileLaunch() => calls.add('playMissileLaunch');
}

/// Mixin that provides convenient access to the nearest [AudioSystem]
/// in the component tree.
///
/// If no [AudioSystem] is found (e.g. in unit tests that don't build a full
/// game tree), a [SilentAudioSystem] is used as a fallback and a warning is
/// logged once. This keeps tests frictionless while still surfacing
/// misconfiguration during development.
///
/// Usage:
/// ```dart
/// class MySoldier extends PositionComponent with HasAudioSystem {
///   void shoot() => audioSystem.playGunshot();
/// }
/// ```
mixin HasAudioSystem on Component {
  AudioSystem? _audioSystem;

  /// Shared silent fallback instance, lazily created.
  static final AudioSystem _fallback = SilentAudioSystem();

  /// Whether we have already logged the fallback warning.
  static bool _warnedFallback = false;

  /// The [AudioSystem] component found in the ancestor tree.
  ///
  /// Caches the result after the first lookup. Falls back to a silent no-op
  /// implementation when no [AudioSystem] exists in the tree (common in
  /// tests).
  AudioSystem get audioSystem {
    final cached = _audioSystem;
    if (cached != null) return cached;

    // AudioSystem lives as a direct child of the FlameGame root.
    final found = findGame()?.children.whereType<AudioSystem>().firstOrNull;

    if (found != null) {
      _audioSystem = found;
      return found;
    }

    // No AudioSystem in the tree — fall back silently.
    if (!_warnedFallback) {
      _warnedFallback = true;
      developer.log(
        'No AudioSystem found in the component tree. '
        'Falling back to SilentAudioSystem. '
        'Add AudioSystem as a child of your FlameGame to enable sound.',
        name: 'HasAudioSystem',
      );
    }
    _audioSystem = _fallback;
    return _fallback;
  }

  @override
  void onMount() {
    super.onMount();
    // Eagerly resolve on mount so it's cached before the first play call.
    _audioSystem ??= findGame()?.children.whereType<AudioSystem>().firstOrNull;
  }
}
