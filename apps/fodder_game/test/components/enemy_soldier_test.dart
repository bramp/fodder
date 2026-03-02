import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fodder_game/game/components/direction8.dart';
import 'package:fodder_game/game/components/enemy_soldier.dart';
import 'package:fodder_game/game/components/soldier.dart';
import 'package:fodder_game/game/components/soldier_animations.dart';

/// Minimal fake [Image] for testing.
class _FakeImage extends Fake implements Image {
  @override
  int get width => 1;

  @override
  int get height => 1;
}

SoldierAnimations _buildFakeAnims() {
  final image = _FakeImage();
  final walkAnims = <Direction8, SpriteAnimation>{};
  final idleAnims = <Direction8, SpriteAnimation>{};

  for (final dir in Direction8.values) {
    final sprite = Sprite(image, srcSize: Vector2.all(16));
    walkAnims[dir] = SpriteAnimation.spriteList(
      [sprite, sprite, sprite],
      stepTime: 0.15,
    );
    idleAnims[dir] = SpriteAnimation.spriteList(
      [sprite],
      stepTime: double.infinity,
    );
  }

  return SoldierAnimations.fromMaps(
    walkAnimations: walkAnims,
    idleAnimations: idleAnims,
  );
}

void main() {
  group('EnemySoldier', () {
    test('can be instantiated', () {
      final enemy = EnemySoldier(soldierAnimations: _buildFakeAnims());
      expect(enemy, isNotNull);
    });

    test('is a Soldier', () {
      final enemy = EnemySoldier(soldierAnimations: _buildFakeAnims());
      expect(enemy, isA<Soldier>());
    });

    test('defaults to facing south and idle', () {
      final enemy = EnemySoldier(soldierAnimations: _buildFakeAnims());
      expect(enemy.facing, Direction8.south);
    });
  });
}
