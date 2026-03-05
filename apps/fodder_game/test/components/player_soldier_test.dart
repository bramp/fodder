import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fodder_game/game/components/bullet.dart';
import 'package:fodder_game/game/components/direction8.dart';
import 'package:fodder_game/game/components/player_soldier.dart';
import 'package:fodder_game/game/components/soldier.dart';
import 'package:fodder_game/game/components/soldier_animations.dart';
import 'package:fodder_game/game/config/game_config.dart' as config;
import 'package:fodder_game/game/config/weapon_data.dart';
import 'package:fodder_game/game/systems/walkability_grid.dart';

/// Minimal fake [Image] for testing (1×1 pixel).
class _FakeImage extends Fake implements Image {
  @override
  int get width => 1;

  @override
  int get height => 1;
}

/// Builds a fake [SoldierAnimations] with 1×1 transparent sprites.
SoldierAnimations _buildFakeAnims({
  bool includeCombatAnims = false,
  bool includeSwimAnims = false,
}) {
  final image = _FakeImage();
  final walkAnims = <Direction8, SpriteAnimation>{};
  final idleAnims = <Direction8, SpriteAnimation>{};
  final firingAnims = <Direction8, SpriteAnimation>{};
  final throwAnims = <Direction8, SpriteAnimation>{};
  final deathAnims = <Direction8, SpriteAnimation>{};
  final swimAnims = <Direction8, SpriteAnimation>{};

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

    if (includeSwimAnims) {
      swimAnims[dir] = SpriteAnimation.spriteList(
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
    swimAnimations: swimAnims,
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

    test('bullet starts offset from soldier position', () {
      // Target to the east → offset is 16px east.
      final bullet = soldier.fire(Vector2(200, 100));

      expect(bullet!.position.x, closeTo(116, 0.01));
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

    test('does not change soldier animation state', () {
      soldier.fire(Vector2(200, 100));

      expect(soldier.current, SoldierState.idle);
      expect(soldier.isFiring, isTrue);
    });

    test('does not change facing direction', () {
      soldier
        ..facing = Direction8.south
        ..fire(Vector2(200, 100)); // East target

      expect(soldier.facing, Direction8.south);
    });

    test('returns null when dead', () {
      soldier.die();
      final bullet = soldier.fire(Vector2(200, 100));

      expect(bullet, isNull);
    });

    test('returns null when on cooldown', () {
      soldier.fire(Vector2(200, 100));
      final secondBullet = soldier.fire(Vector2(300, 100));

      expect(secondBullet, isNull);
    });

    test('returns null when target equals position', () {
      final bullet = soldier.fire(Vector2(100, 100));

      expect(bullet, isNull);
    });
  });

  group('PlayerSoldier fire cooldown', () {
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

    test('isFiring true during cooldown', () {
      final cooldown = soldier.weaponStats.cooldown;
      soldier
        ..fire(Vector2(200, 100))
        ..update(cooldown * 0.5);

      expect(soldier.isFiring, isTrue);
    });

    test('isFiring false after cooldown expires', () {
      final cooldown = soldier.weaponStats.cooldown;
      soldier
        ..fire(Vector2(200, 100))
        ..update(cooldown + 0.01);

      expect(soldier.isFiring, isFalse);
    });

    test('soldier keeps moving during cooldown', () {
      soldier.followPath([Vector2(300, 100)]);
      final posBefore = soldier.position.clone();
      soldier
        ..fire(Vector2(200, 100))
        ..update(0.1);

      // Soldier should have moved toward waypoint.
      expect(soldier.position.x, greaterThan(posBefore.x));
    });

    test('can fire again after cooldown expires', () {
      final cooldown = soldier.weaponStats.cooldown;
      soldier
        ..fire(Vector2(200, 100))
        ..update(cooldown + 0.01);

      final bullet = soldier.fire(Vector2(200, 100));
      expect(bullet, isNotNull);
    });
  });

  group('PlayerSoldier water mechanics', () {
    late PlayerSoldier soldier;

    /// Builds a 4×4 grid: top-left is land, top-right is water.
    WalkabilityGrid waterGrid() {
      return WalkabilityGrid.fromData([
        [
          TerrainType.land,
          TerrainType.land,
          TerrainType.water,
          TerrainType.water,
        ],
        [
          TerrainType.land,
          TerrainType.land,
          TerrainType.water,
          TerrainType.water,
        ],
        [
          TerrainType.land,
          TerrainType.land,
          TerrainType.land,
          TerrainType.land,
        ],
        [
          TerrainType.land,
          TerrainType.land,
          TerrainType.land,
          TerrainType.land,
        ],
      ]);
    }

    setUp(() {
      soldier =
          PlayerSoldier(
              soldierAnimations: _buildFakeAnims(
                includeCombatAnims: true,
                includeSwimAnims: true,
              ),
            )
            ..position =
                Vector2(16, 16) // tile (0, 0) = land
            ..walkabilityGrid = waterGrid()
            ..updateAnimations()
            ..current = SoldierState.idle;
    });

    test('speed is normal on land', () {
      // Ensure terrain is checked.
      soldier.update(0.01);
      expect(soldier.speed, config.playerSpeedNormal);
    });

    test('speed is forced to water speed on water tile', () {
      // Move to tile (2, 0) = water. destTileSize=32, so x=80.
      soldier
        ..position = Vector2(80, 16)
        ..followPath([Vector2(90, 16)])
        ..update(0.01);

      expect(soldier.isInWater, isTrue);
      expect(soldier.speed, config.playerSpeedWater);
    });

    test('switches to swimming state when walking on water', () {
      soldier
        ..position = Vector2(80, 16)
        ..followPath([Vector2(90, 16)])
        ..update(0.01);

      expect(soldier.current, SoldierState.swimming);
    });

    test('returns to walking state when leaving water', () {
      // Start on water.
      soldier
        ..position = Vector2(80, 16)
        ..followPath([Vector2(90, 16)])
        ..update(0.01);
      expect(soldier.isInWater, isTrue);

      // Move back to land: tile (0, 0).
      soldier
        ..position = Vector2(16, 16)
        ..followPath([Vector2(20, 16)])
        ..update(0.01);

      expect(soldier.isInWater, isFalse);
      expect(soldier.current, SoldierState.walking);
    });

    test('isInWater is true for waterEdge terrain', () {
      final grid = WalkabilityGrid.fromData([
        [TerrainType.waterEdge, TerrainType.land],
        [TerrainType.land, TerrainType.land],
      ]);
      soldier
        ..walkabilityGrid = grid
        ..position =
            Vector2(16, 16) // tile (0, 0) = waterEdge
        ..followPath([Vector2(20, 16)])
        ..update(0.01);

      expect(soldier.isInWater, isTrue);
    });

    test('isInWater is true for sink terrain', () {
      final grid = WalkabilityGrid.fromData([
        [TerrainType.sink, TerrainType.land],
        [TerrainType.land, TerrainType.land],
      ]);
      soldier
        ..walkabilityGrid = grid
        ..position =
            Vector2(16, 16) // tile (0, 0) = sink
        ..followPath([Vector2(20, 16)])
        ..update(0.01);

      expect(soldier.isInWater, isTrue);
    });

    test('idle on water uses swimming state', () {
      soldier
        ..position = Vector2(80, 16)
        // No path — stationary but on water.
        ..update(0.01)
        // Give it a path that completes immediately (same position).
        ..followPath([Vector2(80, 16)])
        ..update(0.01);

      // Position matches waypoint → path clears → idle-on-water = swimming.
      expect(soldier.current, SoldierState.swimming);
    });
  });

  group('PlayerSoldier drop/cliff mechanics', () {
    late PlayerSoldier soldier;

    /// Builds a 4×4 grid with drop terrain on tile (1, 0) and land elsewhere.
    WalkabilityGrid dropGrid() {
      return WalkabilityGrid.fromData([
        [
          TerrainType.land,
          TerrainType.drop,
          TerrainType.land,
          TerrainType.land,
        ],
        [
          TerrainType.land,
          TerrainType.land,
          TerrainType.land,
          TerrainType.land,
        ],
        [
          TerrainType.land,
          TerrainType.land,
          TerrainType.land,
          TerrainType.land,
        ],
        [
          TerrainType.land,
          TerrainType.land,
          TerrainType.land,
          TerrainType.land,
        ],
      ]);
    }

    /// Builds a 4×4 grid with drop2 terrain on tile (1, 0) and land
    /// elsewhere.
    WalkabilityGrid drop2Grid() {
      return WalkabilityGrid.fromData([
        [
          TerrainType.land,
          TerrainType.drop2,
          TerrainType.land,
          TerrainType.land,
        ],
        [
          TerrainType.land,
          TerrainType.land,
          TerrainType.land,
          TerrainType.land,
        ],
        [
          TerrainType.land,
          TerrainType.land,
          TerrainType.land,
          TerrainType.land,
        ],
        [
          TerrainType.land,
          TerrainType.land,
          TerrainType.land,
          TerrainType.land,
        ],
      ]);
    }

    /// Builds a grid that is all drop terrain to force death.
    WalkabilityGrid allDropGrid() {
      return WalkabilityGrid.fromData(
        List.generate(
          10,
          (_) => List.filled(10, TerrainType.drop),
        ),
      );
    }

    setUp(() {
      soldier =
          PlayerSoldier(
              soldierAnimations: _buildFakeAnims(
                includeCombatAnims: true,
                includeSwimAnims: true,
              ),
            )
            ..position =
                Vector2(16, 16) // tile (0, 0) = land
            ..updateAnimations()
            ..current = SoldierState.idle;
    });

    test('stepping on Drop terrain starts falling', () {
      soldier
        ..walkabilityGrid = dropGrid()
        ..position =
            Vector2(48, 16) // tile (1, 0) = drop
        ..followPath([Vector2(60, 16)])
        ..update(0.01);

      expect(soldier.isFalling, isTrue);
      expect(soldier.isStumbling, isFalse);
    });

    test('stepping on Drop2 terrain starts stumbling', () {
      soldier
        ..walkabilityGrid = drop2Grid()
        ..position =
            Vector2(48, 16) // tile (1, 0) = drop2
        ..followPath([Vector2(60, 16)])
        ..update(0.01);

      expect(soldier.isStumbling, isTrue);
      expect(soldier.isFalling, isFalse);
    });

    test('falling soldier slides downward (Drop)', () {
      soldier
        ..walkabilityGrid = allDropGrid()
        ..position = Vector2(48, 16)
        ..followPath([Vector2(60, 16)])
        ..update(0.01); // enters falling

      final yAfterFirstFrame = soldier.position.y;

      // Second update should continue falling and move further down.
      soldier.update(0.1);

      expect(soldier.position.y, greaterThan(yAfterFirstFrame));
    });

    test('stumbling soldier stays in place (Drop2)', () {
      soldier
        ..walkabilityGrid = drop2Grid()
        ..position =
            Vector2(48, 16) // tile (1, 0) = drop2
        ..followPath([Vector2(60, 16)])
        ..update(0.01); // enters stumbling

      final yAfterFirstFrame = soldier.position.y;

      // Stumble does NOT move the soldier downward.
      soldier.update(0.05);

      expect(soldier.position.y, yAfterFirstFrame);
    });

    test('soldier dies after sustained fall on Drop terrain', () {
      soldier
        ..walkabilityGrid = allDropGrid()
        ..position = Vector2(48, 16)
        ..followPath([Vector2(60, 16)]);

      // Tick frames — all-drop grid means no escape; soldier must die.
      for (var i = 0; i < 100; i++) {
        soldier.update(0.05);
        if (!soldier.isAlive) break;
      }

      expect(soldier.isAlive, isFalse);
    });

    test('soldier dies quickly from Drop2 stumble', () {
      soldier
        ..walkabilityGrid = drop2Grid()
        ..position =
            Vector2(48, 16) // tile (1, 0) = drop2
        ..followPath([Vector2(60, 16)]);

      // Drop2 kills in ~0.3 s. Tick small steps.
      for (var i = 0; i < 20; i++) {
        soldier.update(0.05);
        if (!soldier.isAlive) break;
      }

      expect(soldier.isAlive, isFalse);
    });

    test('soldier survives short fall onto land (Drop)', () {
      // dropGrid(): tile (1, 0) = drop, tile (0, 0) = land.
      // Soldier starts on drop, begins falling, but the downward slide
      // moves them into land territory before the timer expires.
      soldier
        ..walkabilityGrid = dropGrid()
        ..position =
            Vector2(48, 16) // tile (1, 0) = drop
        ..followPath([Vector2(60, 16)])
        ..update(0.01); // enters falling

      expect(soldier.isFalling, isTrue);

      // Relocate to land tile before the timer expires.
      soldier
        ..position =
            Vector2(16, 48) // tile (0, 1) = land
        ..update(0.01);

      // Should have survived — landed on solid ground in time.
      expect(soldier.isAlive, isTrue);
      expect(soldier.isFalling, isFalse);
    });

    test('falling soldier dies when sliding off the map edge', () {
      // Small 2×2 grid with drop at tile (0, 1). The soldier starts
      // falling and slides downward past the grid boundary. Out-of-bounds
      // returns block terrain, which must NOT count as a safe landing.
      final edgeGrid = WalkabilityGrid.fromData([
        [TerrainType.land, TerrainType.land],
        [TerrainType.drop, TerrainType.drop],
      ]);

      soldier
        ..walkabilityGrid = edgeGrid
        ..position =
            Vector2(16, 48) // tile (0, 1) = drop
        ..followPath([Vector2(20, 48)]);

      // Tick until dead — the fall should carry them past Y = 64 (map
      // bottom), and they should die rather than getting stuck.
      for (var i = 0; i < 100; i++) {
        soldier.update(0.05);
        if (!soldier.isAlive) break;
      }

      expect(soldier.isAlive, isFalse);
    });

    test('isFalling is false on normal terrain', () {
      soldier
        ..walkabilityGrid = dropGrid()
        ..position =
            Vector2(16, 16) // tile (0, 0) = land
        ..followPath([Vector2(20, 16)])
        ..update(0.01);

      expect(soldier.isFalling, isFalse);
      expect(soldier.isStumbling, isFalse);
    });

    test('falling state is set during Drop fall', () {
      soldier
        ..walkabilityGrid = allDropGrid()
        ..position = Vector2(48, 16)
        ..followPath([Vector2(60, 16)])
        ..update(0.01);

      // Falling state should be set (falls back to walking if no animation).
      expect(
        soldier.current,
        anyOf(SoldierState.falling, SoldierState.walking),
      );
    });

    test('stumbling state is set during Drop2 stumble', () {
      soldier
        ..walkabilityGrid = drop2Grid()
        ..position =
            Vector2(48, 16) // tile (1, 0) = drop2
        ..followPath([Vector2(60, 16)])
        ..update(0.01);

      // Stumbling state should be set (falls back to dying if no animation).
      expect(
        soldier.current,
        anyOf(SoldierState.stumbling, SoldierState.dying),
      );
    });
  });
}
