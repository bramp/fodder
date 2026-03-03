import 'package:flutter_test/flutter_test.dart';
import 'package:fodder_game/game/config/fire_rotation.dart';

void main() {
  group('fireRotation', () {
    test('index 0 is empty (unused)', () {
      expect(fireRotation[0], isEmpty);
    });

    test('solo soldier fires alone', () {
      expect(fireRotation[1], [0, -1]);
    });

    test('two soldiers alternate', () {
      expect(fireRotation[2], [0, 1, -1]);
    });

    test('three soldiers: leader fires every other turn', () {
      expect(fireRotation[3], [0, 1, 0, 2, -1]);
    });

    test('all patterns end with -1 sentinel', () {
      for (var size = 1; size < fireRotation.length; size++) {
        expect(
          fireRotation[size].last,
          -1,
          reason: 'pattern for size $size should end with -1',
        );
      }
    });

    test('has patterns for squad sizes 1 through 8', () {
      expect(fireRotation.length, 9); // indices 0-8
    });
  });

  group('fireRotationForSize', () {
    test('returns correct pattern for valid sizes', () {
      for (var size = 1; size <= 8; size++) {
        expect(fireRotationForSize(size), fireRotation[size]);
      }
    });

    test('returns empty for size 0', () {
      expect(fireRotationForSize(0), isEmpty);
    });

    test('returns empty for negative size', () {
      expect(fireRotationForSize(-1), isEmpty);
    });

    test('returns empty for size > 8', () {
      expect(fireRotationForSize(9), isEmpty);
    });
  });
}
