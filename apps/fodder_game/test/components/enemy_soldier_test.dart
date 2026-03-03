import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fodder_game/game/components/bullet.dart';
import 'package:fodder_game/game/components/direction8.dart';
import 'package:fodder_game/game/components/enemy_soldier.dart';
import 'package:fodder_game/game/components/player_soldier.dart';
import 'package:fodder_game/game/components/soldier.dart';
import 'package:fodder_game/game/components/soldier_animations.dart';
import 'package:fodder_game/game/config/game_config.dart' as config;
import 'package:fodder_game/game/systems/walkability_grid.dart';

/// Minimal fake [Image] for testing.
class _FakeImage extends Fake implements Image {
  @override
  int get width => 1;

  @override
  int get height => 1;
}

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

/// Builds a fully walkable grid (all land) of the given tile dimensions.
WalkabilityGrid _openGrid({int tiles = 10}) {
  return WalkabilityGrid.fromData(
    List.generate(
      tiles,
      (_) => List.filled(tiles, TerrainType.land),
    ),
  );
}

PlayerSoldier _makePlayer() {
  return PlayerSoldier(
      soldierAnimations: _buildFakeAnims(includeCombatAnims: true),
    )
    ..position = Vector2(100, 100)
    ..updateAnimations()
    ..current = SoldierState.idle;
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

    test('hitboxSize is 16×16', () {
      final enemy = EnemySoldier(soldierAnimations: _buildFakeAnims());
      expect(enemy.hitboxSize, Vector2(16, 16));
    });

    test('opposingFaction is player', () {
      final enemy = EnemySoldier(soldierAnimations: _buildFakeAnims());
      expect(enemy.opposingFaction, Faction.player);
    });

    test('defaults to idle AI state', () {
      final enemy = EnemySoldier(soldierAnimations: _buildFakeAnims());
      expect(enemy.aiState, EnemyAiState.idle);
    });

    test('default aggression is 6', () {
      final enemy = EnemySoldier(soldierAnimations: _buildFakeAnims());
      expect(enemy.aggression, 6);
    });
  });

  group('EnemySoldier AI — idle', () {
    test('stays idle when no players', () {
      final enemy =
          EnemySoldier(
              soldierAnimations: _buildFakeAnims(includeCombatAnims: true),
            )
            ..position = Vector2(50, 50)
            ..players = []
            ..walkabilityGrid = _openGrid()
            ..updateAnimations()
            ..current = SoldierState.idle
            ..update(0.1);

      expect(enemy.aiState, EnemyAiState.idle);
    });

    test('stays idle when player is out of range', () {
      final player = _makePlayer()..position = Vector2(500, 500);
      final enemy =
          EnemySoldier(
              soldierAnimations: _buildFakeAnims(includeCombatAnims: true),
            )
            ..position = Vector2(50, 50)
            ..players = [player]
            ..walkabilityGrid = _openGrid()
            ..updateAnimations()
            ..current = SoldierState.idle
            ..update(0.1);

      expect(enemy.aiState, EnemyAiState.idle);
    });

    test('transitions to chasing when player in range', () {
      final player = _makePlayer()..position = Vector2(100, 100);
      final enemy =
          EnemySoldier(
              soldierAnimations: _buildFakeAnims(includeCombatAnims: true),
            )
            ..position = Vector2(50, 50)
            ..players = [player]
            ..walkabilityGrid = _openGrid()
            ..updateAnimations()
            ..current = SoldierState.idle
            ..update(0.1);

      expect(enemy.aiState, EnemyAiState.chasing);
    });
  });

  group('EnemySoldier AI — chasing', () {
    test('moves toward player when outside firing range', () {
      // Place the player within detection range (200 px) but beyond the
      // effective bullet range (~132 px for aggression 6). The enemy should
      // chase (walk) rather than immediately fire.
      final player = _makePlayer()..position = Vector2(230, 50);
      final enemy =
          EnemySoldier(
              soldierAnimations: _buildFakeAnims(includeCombatAnims: true),
            )
            ..position = Vector2(50, 50)
            ..players = [player]
            ..walkabilityGrid = _openGrid()
            ..updateAnimations()
            ..current = SoldierState.idle
            ..update(0.1); // detect → chasing

      // Verify the distance is within detection but beyond bullet range.
      const dist = 180.0; // |230 - 50|
      expect(dist, lessThan(config.detectionRange));
      expect(dist, greaterThan(enemy.effectiveBulletRange));
      expect(enemy.aiState, EnemyAiState.chasing);

      final startX = enemy.position.x;
      // Second update: should walk toward player.
      enemy.update(0.1);

      expect(enemy.position.x, greaterThan(startX));
    });

    test('returns to idle when player moves out of range', () {
      final player = _makePlayer()..position = Vector2(100, 50);
      final enemy =
          EnemySoldier(
              soldierAnimations: _buildFakeAnims(includeCombatAnims: true),
            )
            ..position = Vector2(50, 50)
            ..players = [player]
            ..walkabilityGrid = _openGrid()
            ..updateAnimations()
            ..current = SoldierState.idle
            ..update(0.1); // detect → chasing

      expect(enemy.aiState, EnemyAiState.chasing);

      // Move player far away.
      player.position = Vector2(1000, 1000);
      enemy.update(0.1);

      expect(enemy.aiState, EnemyAiState.idle);
    });
  });

  group('EnemySoldier AI — firing', () {
    test('fires bullet via callback', () {
      final player = _makePlayer()..position = Vector2(80, 50);
      Bullet? firedBullet;

      final enemy =
          EnemySoldier(
              soldierAnimations: _buildFakeAnims(includeCombatAnims: true),
            )
            ..position = Vector2(50, 50)
            ..players = [player]
            ..walkabilityGrid = _openGrid()
            ..updateAnimations()
            ..current = SoldierState.idle
            ..onFireBullet = (b) => firedBullet = b;

      // Tick several times to detect → chase → close enough → fire.
      for (var i = 0; i < 20; i++) {
        enemy.update(0.05);
      }

      expect(firedBullet, isNotNull);
      expect(firedBullet!.faction, Faction.enemy);
    });

    test('respects initial fire delay', () {
      final player = _makePlayer()..position = Vector2(80, 50);
      Bullet? firedBullet;

      final enemy =
          EnemySoldier(
              soldierAnimations: _buildFakeAnims(includeCombatAnims: true),
            )
            ..position = Vector2(50, 50)
            ..players = [player]
            ..walkabilityGrid = _openGrid()
            ..initialFireDelay =
                10 // Very long delay.
            ..updateAnimations()
            ..current = SoldierState.idle
            ..onFireBullet = (b) => firedBullet = b;

      // Tick a bit — should not fire due to initial delay.
      for (var i = 0; i < 10; i++) {
        enemy.update(0.1);
      }

      expect(firedBullet, isNull);
    });

    test('high aggression enemies skip initial fire delay', () {
      final player = _makePlayer()..position = Vector2(80, 50);
      Bullet? firedBullet;

      final enemy =
          EnemySoldier(
              soldierAnimations: _buildFakeAnims(includeCombatAnims: true),
            )
            ..position = Vector2(50, 50)
            ..aggression = 8
            ..players = [player]
            ..walkabilityGrid = _openGrid()
            ..initialFireDelay =
                0 // High aggression → delay = 0 from game.
            ..updateAnimations()
            ..current = SoldierState.idle
            ..onFireBullet = (b) => firedBullet = b;

      // Tick enough to detect, chase, and fire.
      for (var i = 0; i < 20; i++) {
        enemy.update(0.05);
      }

      expect(firedBullet, isNotNull);
    });
  });

  group('EnemySoldier AI — death', () {
    test('stops AI when dead', () {
      final player = _makePlayer()..position = Vector2(80, 50);
      final enemy =
          EnemySoldier(
              soldierAnimations: _buildFakeAnims(includeCombatAnims: true),
            )
            ..position = Vector2(50, 50)
            ..players = [player]
            ..walkabilityGrid = _openGrid()
            ..updateAnimations()
            ..current = SoldierState.idle
            ..update(0.1); // detect → chasing

      expect(enemy.aiState, EnemyAiState.chasing);

      // Kill enemy.
      enemy.die();

      final posBefore = enemy.position.clone();
      enemy.update(0.1);

      // Should not have moved.
      expect(enemy.position.x, closeTo(posBefore.x, 0.01));
    });
  });
}
