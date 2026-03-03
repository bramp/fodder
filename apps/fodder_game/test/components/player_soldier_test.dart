import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fodder_game/game/components/bullet.dart';
import 'package:fodder_game/game/components/direction8.dart';
import 'package:fodder_game/game/components/player_soldier.dart';
import 'package:fodder_game/game/components/soldier.dart';
import 'package:fodder_game/game/components/soldier_animations.dart';
import 'package:fodder_game/game/config/weapon_data.dart';

/// Minimal fake [Image] for testing (1×1 pixel).
class _FakeImage extends Fake implements Image {
  @override
  int get width => 1;

  @override
  int get height => 1;
}

/// Builds a fake [SoldierAnimations] with 1×1 transparent sprites.
SoldierAnimations _buildFakeAnims({bool includeCombatAnims = false}) {
  final image = _FakeImage();
  final walkAnims = <Direction8, SpriteAnimation>{};
  final idleAnims = <Direction8, SpriteAnimation>{};
  final firingAnims = <Direction8, SpriteAnimation>{};
  final throwAnims = <Direction8, SpriteAnimation>{};
  final deathAnims = <Direction8, SpriteAnimation>{};

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

    if (includeCombatAnims) {
      firingAnims[dir] = SpriteAnimation.spriteList(
        [sprite],
        stepTime: double.infinity,
      );
      throwAnims[dir] = SpriteAnimation.spriteList(
        [sprite, sprite, sprite],
        stepTime: 0.12,
      );
      deathAnims[dir] = SpriteAnimation.spriteList(
        [sprite, sprite],
        stepTime: 0.2,
      );
    }
  }

  return SoldierAnimations.fromMaps(
    walkAnimations: walkAnims,
    idleAnimations: idleAnims,
    firingAnimations: firingAnims,
    throwAnimations: throwAnims,
    deathAnimations: deathAnims,
  );
}

void main() {
  group('PlayerSoldier', () {
    late PlayerSoldier soldier;

    setUp(() {
      soldier =
          PlayerSoldier(
              soldierAnimations: _buildFakeAnims(includeCombatAnims: true),
            )
            ..updateAnimations()
            ..current = SoldierState.idle;
    });

    test('hitboxSize is 6×5', () {
      expect(soldier.hitboxSize, Vector2(6, 5));
    });

    test('opposingFaction is enemy', () {
      expect(soldier.opposingFaction, Faction.enemy);
    });

    test('defaults to normal speed (80 px/s)', () {
      expect(soldier.speed, 80);
    });

    test('starts not firing', () {
      expect(soldier.isFiring, isFalse);
    });

    test('currentPath is empty by default', () {
      expect(soldier.currentPath, isEmpty);
    });
  });

  group('PlayerSoldier.followPath', () {
    late PlayerSoldier soldier;

    setUp(() {
      soldier =
          PlayerSoldier(
              soldierAnimations: _buildFakeAnims(includeCombatAnims: true),
            )
            ..updateAnimations()
            ..current = SoldierState.idle;
    });

    test('sets walking state', () {
      soldier.followPath([Vector2(100, 0)]);
      expect(soldier.current, SoldierState.walking);
    });

    test('populates currentPath', () {
      final path = [Vector2(10, 0), Vector2(20, 0)];
      soldier.followPath(path);
      expect(soldier.currentPath, hasLength(2));
    });

    test('empty path does not change state', () {
      soldier
        ..current = SoldierState.idle
        ..followPath([]);
      expect(soldier.current, SoldierState.idle);
    });
  });

  group('PlayerSoldier.fire', () {
    late PlayerSoldier soldier;

    setUp(() {
      soldier =
          PlayerSoldier(
              soldierAnimations: _buildFakeAnims(includeCombatAnims: true),
            )
            ..position = Vector2(100, 100)
            ..updateAnimations()
            ..current = SoldierState.idle;
    });

    test('returns a Bullet with player faction', () {
      final bullet = soldier.fire(Vector2(200, 100));

      expect(bullet, isNotNull);
      expect(bullet!.faction, Faction.player);
    });

    test('bullet starts at soldier position', () {
      final bullet = soldier.fire(Vector2(200, 100));

      expect(bullet!.position.x, closeTo(100, 0.01));
      expect(bullet.position.y, closeTo(100, 0.01));
    });

    test('bullet velocity points toward target', () {
      // Target to the east.
      final bullet = soldier.fire(Vector2(200, 100));
      final expectedSpeed = fallbackWeaponStats(0).bulletSpeed;

      expect(bullet!.velocity.x, closeTo(expectedSpeed, 0.1));
      expect(bullet.velocity.y, closeTo(0, 0.1));
    });

    test('bullet velocity points toward target (south)', () {
      final bullet = soldier.fire(Vector2(100, 200));
      final expectedSpeed = fallbackWeaponStats(0).bulletSpeed;

      expect(bullet!.velocity.x, closeTo(0, 0.1));
      expect(bullet.velocity.y, closeTo(expectedSpeed, 0.1));
    });

    test('sets soldier to firing state', () {
      soldier.fire(Vector2(200, 100));

      expect(soldier.current, SoldierState.firing);
      expect(soldier.isFiring, isTrue);
    });

    test('updates facing direction toward target', () {
      soldier.fire(Vector2(200, 100)); // East

      expect(soldier.facing, Direction8.east);
    });

    test('updates facing direction toward target (north)', () {
      soldier.fire(Vector2(100, 0)); // North

      expect(soldier.facing, Direction8.north);
    });

    test('returns null when dead', () {
      soldier.die();
      final bullet = soldier.fire(Vector2(200, 100));

      expect(bullet, isNull);
    });

    test('returns null when already firing', () {
      soldier.fire(Vector2(200, 100));
      final secondBullet = soldier.fire(Vector2(300, 100));

      expect(secondBullet, isNull);
    });

    test('returns null when target equals position', () {
      final bullet = soldier.fire(Vector2(100, 100));

      expect(bullet, isNull);
    });
  });

  group('PlayerSoldier firing hold', () {
    late PlayerSoldier soldier;

    setUp(() {
      soldier =
          PlayerSoldier(
              soldierAnimations: _buildFakeAnims(includeCombatAnims: true),
            )
            ..position = Vector2(100, 100)
            ..updateAnimations()
            ..current = SoldierState.idle;
    });

    test('remains firing during hold duration', () {
      soldier
        ..fire(Vector2(200, 100))
        // Advance less than firingHoldDuration.
        ..update(firingHoldDuration * 0.5);

      expect(soldier.isFiring, isTrue);
      expect(soldier.current, SoldierState.firing);
    });

    test('returns to idle after hold duration', () {
      soldier
        ..fire(Vector2(200, 100))
        // Advance past firingHoldDuration.
        ..update(firingHoldDuration + 0.01);

      expect(soldier.isFiring, isFalse);
      expect(soldier.current, SoldierState.idle);
    });

    test('returns to walking if path was active', () {
      soldier
        ..followPath([Vector2(300, 100)])
        ..fire(Vector2(200, 100))
        // Path is still active, fire hold should remember we were walking.
        ..update(firingHoldDuration + 0.01);

      expect(soldier.isFiring, isFalse);
      expect(soldier.current, SoldierState.walking);
    });

    test('does not move while firing hold is active', () {
      soldier.followPath([Vector2(300, 100)]);
      final posBefore = soldier.position.clone();
      soldier
        ..fire(Vector2(200, 100))
        // Update should not move the soldier.
        ..update(0.1);

      expect(soldier.position.x, closeTo(posBefore.x, 0.01));
      expect(soldier.position.y, closeTo(posBefore.y, 0.01));
    });

    test('can fire again after hold expires', () {
      soldier
        ..fire(Vector2(200, 100))
        ..update(firingHoldDuration + 0.01);

      // Should be able to fire again.
      final bullet = soldier.fire(Vector2(200, 100));
      expect(bullet, isNotNull);
    });
  });
}
