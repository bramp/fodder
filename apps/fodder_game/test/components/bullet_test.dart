import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fodder_game/game/components/bullet.dart';
import 'package:fodder_game/game/systems/walkability_grid.dart';

void main() {
  group('Bullet', () {
    test('can be instantiated with player faction', () {
      final bullet = Bullet(
        position: Vector2.zero(),
        velocity: Vector2(100, 0),
        faction: Faction.player,
      );

      expect(bullet, isNotNull);
      expect(bullet.faction, Faction.player);
    });

    test('can be instantiated with enemy faction', () {
      final bullet = Bullet(
        position: Vector2.zero(),
        velocity: Vector2(100, 0),
        faction: Faction.enemy,
      );

      expect(bullet.faction, Faction.enemy);
    });

    test('defaults to 400 maxRange and 5 maxLifetime', () {
      final bullet = Bullet(
        position: Vector2.zero(),
        velocity: Vector2(100, 0),
        faction: Faction.player,
      );

      expect(bullet.maxRange, 400);
      expect(bullet.maxLifetime, 5);
    });

    test('starts with zero distance travelled', () {
      final bullet = Bullet(
        position: Vector2.zero(),
        velocity: Vector2(100, 0),
        faction: Faction.player,
      );

      expect(bullet.distanceTravelled, 0);
    });

    test('update moves bullet by velocity * dt', () {
      final bullet = Bullet(
        position: Vector2.zero(),
        velocity: Vector2(200, 0),
        faction: Faction.player,
      )..update(0.5);

      expect(bullet.position.x, closeTo(100, 0.01));
      expect(bullet.position.y, closeTo(0, 0.01));
    });

    test('update accumulates distanceTravelled', () {
      final bullet =
          Bullet(
              position: Vector2.zero(),
              velocity: Vector2(100, 0),
              faction: Faction.player,
            )
            ..update(0.1)
            ..update(0.1);

      expect(bullet.distanceTravelled, closeTo(20, 0.01));
    });

    test('has a 4x4 size and center anchor', () {
      final bullet = Bullet(
        position: Vector2(10, 20),
        velocity: Vector2(100, 0),
        faction: Faction.player,
      );

      expect(bullet.size.x, 4);
      expect(bullet.size.y, 4);
      expect(bullet.anchor, Anchor.center);
    });
  });

  group('Faction', () {
    test('has player and enemy values', () {
      expect(Faction.values, contains(Faction.player));
      expect(Faction.values, contains(Faction.enemy));
    });
  });

  group('Bullet terrain collision', () {
    // Each tile = 32px, sub-tile = 4px. A 2×2 tile grid:
    //   (0,0)=land, (1,0)=block
    //   (0,1)=land, (1,1)=land
    WalkabilityGrid blockGrid() {
      return WalkabilityGrid.fromData([
        [TerrainType.land, TerrainType.block],
        [TerrainType.land, TerrainType.land],
      ]);
    }

    test('bullet is removed when entering blocked terrain', () {
      final grid = blockGrid();
      // Start on land (x=16), moving east toward block tile (x≥32).
      final bullet = Bullet(
        position: Vector2(16, 16),
        velocity: Vector2(500, 0),
        faction: Faction.player,
        walkabilityGrid: grid,
      )..update(0.1); // moves 50px east → x=66, deep into block tile

      // Bullet detects blocked terrain and marks itself destroyed.
      expect(bullet.isDestroyed, isTrue);
    });

    test('bullet survives on walkable terrain', () {
      final grid = blockGrid();
      // Start on land, move south (stays in land tiles).
      final bullet = Bullet(
        position: Vector2(16, 16),
        velocity: Vector2(0, 50),
        faction: Faction.player,
        walkabilityGrid: grid,
      )..update(0.1);

      expect(bullet.isDestroyed, isFalse);
    });

    test('bullet without grid ignores terrain', () {
      // No walkabilityGrid → bullet cannot check terrain.
      final bullet = Bullet(
        position: Vector2(50, 16),
        velocity: Vector2(100, 0),
        faction: Faction.player,
      )..update(0.1);

      expect(bullet.isDestroyed, isFalse);
    });
  });
}
