import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fodder_game/game/systems/audio_system.dart';

/// Trivial component that uses the [HasAudioSystem] mixin.
class _AudioConsumer extends Component with HasAudioSystem {}

/// Adds [audio] and [consumer] as children of a [FlameGame], then processes
/// the component queue so they are fully mounted.
Future<FlameGame> _buildTree({
  required SilentAudioSystem audio,
  required _AudioConsumer consumer,
}) async {
  final game = FlameGame();
  await game.onLoad();
  // Process the pending-add queue.
  game
    ..add(audio)
    ..add(consumer)
    ..update(0);
  return game;
}

void main() {
  group('SilentAudioSystem', () {
    test('can be instantiated', () {
      final audio = SilentAudioSystem();
      expect(audio, isA<AudioSystem>());
    });

    test('playDeathScream records call', () {
      final audio = SilentAudioSystem()..playDeathScream();
      expect(audio.calls, ['playDeathScream']);
    });

    test('playGunshot records call', () {
      final audio = SilentAudioSystem()..playGunshot();
      expect(audio.calls, ['playGunshot']);
    });

    test('playImpact records call', () {
      final audio = SilentAudioSystem()..playImpact();
      expect(audio.calls, ['playImpact']);
    });

    test('playExplosion records call', () {
      final audio = SilentAudioSystem()..playExplosion();
      expect(audio.calls, ['playExplosion']);
    });

    test('playGrenadeExplosion records call', () {
      final audio = SilentAudioSystem()..playGrenadeExplosion();
      expect(audio.calls, ['playGrenadeExplosion']);
    });

    test('playMissileLaunch records call', () {
      final audio = SilentAudioSystem()..playMissileLaunch();
      expect(audio.calls, ['playMissileLaunch']);
    });

    test('records multiple calls in order', () {
      final audio = SilentAudioSystem()
        ..playGunshot()
        ..playDeathScream()
        ..playImpact();
      expect(audio.calls, ['playGunshot', 'playDeathScream', 'playImpact']);
    });

    test('onLoad does not throw', () async {
      await SilentAudioSystem().onLoad();
    });

    test('onRemove does not throw', () {
      SilentAudioSystem().onRemove();
    });
  });

  group('AudioSystem', () {
    test('can be instantiated with default Random', () {
      final audio = AudioSystem();
      expect(audio, isNotNull);
    });

    test('can be instantiated with injected Random', () {
      final audio = AudioSystem(random: Random(42));
      expect(audio, isNotNull);
    });

    test('maxConcurrentSounds is 8', () {
      expect(AudioSystem.maxConcurrentSounds, 8);
    });
  });

  group('HasAudioSystem', () {
    test('resolves AudioSystem from game children', () async {
      final audio = SilentAudioSystem();
      final consumer = _AudioConsumer();
      await _buildTree(audio: audio, consumer: consumer);

      expect(consumer.audioSystem, same(audio));
    });

    test('caches the AudioSystem after first lookup', () async {
      final audio = SilentAudioSystem();
      final consumer = _AudioConsumer();
      await _buildTree(audio: audio, consumer: consumer);

      final first = consumer.audioSystem;
      final second = consumer.audioSystem;
      expect(identical(first, second), isTrue);
    });

    test('consumer can call audio methods via mixin', () async {
      final audio = SilentAudioSystem();
      final consumer = _AudioConsumer();
      await _buildTree(audio: audio, consumer: consumer);

      consumer.audioSystem.playGunshot();
      expect(audio.calls, ['playGunshot']);
    });

    test('falls back to SilentAudioSystem when no game tree', () {
      final consumer = _AudioConsumer();

      // No game tree at all — should silently fall back, not throw.
      final audio = consumer.audioSystem;
      expect(audio, isA<SilentAudioSystem>());
    });

    test('fallback is cached after first access', () {
      final consumer = _AudioConsumer();
      final first = consumer.audioSystem;
      final second = consumer.audioSystem;
      expect(identical(first, second), isTrue);
    });
  });
}
