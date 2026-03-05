import 'package:flutter_test/flutter_test.dart';

import 'package:fodder_game/game/sprites/sprite_frames.dart';

void main() {
  group('SoldierAnimations group name constants', () {
    test('walkGroupPlayer is player_walk', () {
      expect(walkGroupPlayer, 'player_walk');
    });

    test('walkGroupEnemy is enemy_walk', () {
      expect(walkGroupEnemy, 'enemy_walk');
    });

    test('firingGroupPlayer is player_firing', () {
      expect(firingGroupPlayer, 'player_firing');
    });

    test('firingGroupEnemy is enemy_firing', () {
      expect(firingGroupEnemy, 'enemy_firing');
    });

    test('throwGroupPlayer is player_throw', () {
      expect(throwGroupPlayer, 'player_throw');
    });

    test('throwGroupEnemy is enemy_throw', () {
      expect(throwGroupEnemy, 'enemy_throw');
    });

    test('deathGroupPlayer is player_death', () {
      expect(deathGroupPlayer, 'player_death');
    });

    test('deathGroupEnemy is enemy_death', () {
      expect(deathGroupEnemy, 'enemy_death');
    });
  });
}
