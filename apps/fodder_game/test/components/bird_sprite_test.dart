import 'package:flutter_test/flutter_test.dart';

import 'package:fodder_game/game/components/bird_sprite.dart';

void main() {
  group('BirdDirection', () {
    test('has left and right values', () {
      expect(BirdDirection.values, hasLength(2));
      expect(BirdDirection.left, isNotNull);
      expect(BirdDirection.right, isNotNull);
    });
  });

  group('BirdSprite constants', () {
    test('frame Y offsets have correct length and values', () {
      // Verify the bobbing pattern from the spec:
      // frames 0-3 = 0, frame 4 = 1, frame 5 = 3.
      expect(frameYOffsets, hasLength(6));
      expect(frameYOffsets[0], 0);
      expect(frameYOffsets[1], 0);
      expect(frameYOffsets[2], 0);
      expect(frameYOffsets[3], 0);
      expect(frameYOffsets[4], 1);
      expect(frameYOffsets[5], 3);
    });

    test('base speed is approximately 50 px/s', () {
      // 1.5 px/tick × 16.67 tps × 2 scale ≈ 50
      expect(baseSpeed, closeTo(50, 1));
    });

    test('fast speed is approximately 67 px/s', () {
      // 2.0 px/tick × 16.67 tps × 2 scale ≈ 66.7
      expect(fastSpeed, closeTo(66.7, 1));
    });

    test('warm-up time is approximately 0.48 seconds', () {
      expect(warmUpTime, closeTo(0.48, 0.01));
    });

    test('respawn time is approximately 3.78 seconds', () {
      expect(respawnTime, closeTo(3.78, 0.01));
    });
  });
}
