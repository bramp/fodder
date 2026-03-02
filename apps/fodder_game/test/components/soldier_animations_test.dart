import 'package:flutter_test/flutter_test.dart';

import 'package:fodder_game/game/components/soldier_animations.dart';

void main() {
  group('SoldierAnimations constants', () {
    test('walkBaseGroupHuman is 0x00', () {
      expect(walkBaseGroupHuman, 0x00);
    });

    test('walkBaseGroupEnemy is 0x42', () {
      expect(walkBaseGroupEnemy, 0x42);
    });

    test('enemy base group differs from human by 0x42', () {
      expect(walkBaseGroupEnemy - walkBaseGroupHuman, 0x42);
    });
  });
}
