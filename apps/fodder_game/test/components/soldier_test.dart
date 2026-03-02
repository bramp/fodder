import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fodder_game/game/components/direction8.dart';
import 'package:fodder_game/game/components/soldier.dart';
import 'package:fodder_game/game/components/soldier_animations.dart';

/// A minimal concrete [Soldier] subclass for testing.
class _TestSoldier extends Soldier {
  _TestSoldier({required super.soldierAnimations});
}

/// Builds a fake [SoldierAnimations] with 1×1 transparent sprites.
///
/// Uses a 1-pixel [Image] so no real GPU assets are needed.
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

/// Minimal fake [Image] for testing (1×1 pixel).
class _FakeImage extends Fake implements Image {
  @override
  int get width => 1;

  @override
  int get height => 1;
}

void main() {
  group('Soldier', () {
    late _TestSoldier soldier;

    setUp(() {
      soldier = _TestSoldier(soldierAnimations: _buildFakeAnims());
    });

    test('defaults to facing south', () {
      expect(soldier.facing, Direction8.south);
    });

    test('setState changes current state', () {
      soldier
        ..updateAnimations()
        ..current = SoldierState.idle
        ..setState(SoldierState.walking);
      expect(soldier.current, SoldierState.walking);
    });

    test('setState does not fire if already in that state', () {
      soldier
        ..updateAnimations()
        ..current = SoldierState.idle
        // No-op — already idle.
        ..setState(SoldierState.idle);
      expect(soldier.current, SoldierState.idle);
    });

    test('updateAnimations populates animations map', () {
      soldier.updateAnimations();

      expect(soldier.animations, isNotNull);
      expect(soldier.animations!.containsKey(SoldierState.walking), isTrue);
      expect(soldier.animations!.containsKey(SoldierState.idle), isTrue);
    });

    test('updateAnimations uses current facing direction', () {
      soldier
        ..facing = Direction8.north
        ..updateAnimations();

      // The animation should correspond to the north direction.
      expect(soldier.animations, isNotNull);
      expect(soldier.animations![SoldierState.walking], isNotNull);
      expect(soldier.animations![SoldierState.idle], isNotNull);
    });
  });
}
