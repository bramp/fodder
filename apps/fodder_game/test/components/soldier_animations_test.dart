import 'package:flutter_test/flutter_test.dart';

import 'package:fodder_game/game/components/soldier_animations.dart';

void main() {
  group('SoldierAnimations name prefix constants', () {
    test('walkPrefixPlayer is player_walk', () {
      expect(walkPrefixPlayer, 'player_walk');
    });

    test('walkPrefixEnemy is enemy_walk', () {
      expect(walkPrefixEnemy, 'enemy_walk');
    });

    test('firingPrefixPlayer is player_firing', () {
      expect(firingPrefixPlayer, 'player_firing');
    });

    test('firingPrefixEnemy is enemy_firing', () {
      expect(firingPrefixEnemy, 'enemy_firing');
    });

    test('throwPrefixPlayer is player_throw', () {
      expect(throwPrefixPlayer, 'player_throw');
    });

    test('throwPrefixEnemy is enemy_throw', () {
      expect(throwPrefixEnemy, 'enemy_throw');
    });

    test('deathPrefixPlayer is player_death', () {
      expect(deathPrefixPlayer, 'player_death');
    });

    test('deathPrefixEnemy is enemy_death', () {
      expect(deathPrefixEnemy, 'enemy_death');
    });
  });
}
