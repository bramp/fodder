import 'package:fodder_game/game/map/spawn_type.dart';
import 'package:test/test.dart';

void main() {
  group('SpawnType', () {
    group('fromName', () {
      test('maps known names to enum values', () {
        expect(SpawnType.fromName('player'), SpawnType.player);
        expect(SpawnType.fromName('enemy'), SpawnType.enemy);
        expect(SpawnType.fromName('birdLeft'), SpawnType.birdLeft);
        expect(SpawnType.fromName('birdRight'), SpawnType.birdRight);
        expect(SpawnType.fromName('enemyRocket'), SpawnType.enemyRocket);
        expect(SpawnType.fromName('enemyLeader'), SpawnType.enemyLeader);
        expect(SpawnType.fromName('shrub'), SpawnType.shrub);
        expect(SpawnType.fromName('tree'), SpawnType.tree);
        expect(SpawnType.fromName('buildingRoof'), SpawnType.buildingRoof);
      });

      test('returns unknown for unrecognised names', () {
        expect(SpawnType.fromName('Type85'), SpawnType.unknown);
        expect(SpawnType.fromName(''), SpawnType.unknown);
        expect(SpawnType.fromName('nosuchtype'), SpawnType.unknown);
      });
    });

    group('classification helpers', () {
      test('isPlayer', () {
        expect(SpawnType.player.isPlayer, isTrue);
        expect(SpawnType.enemy.isPlayer, isFalse);
      });

      test('isEnemy includes all enemy variants', () {
        expect(SpawnType.enemy.isEnemy, isTrue);
        expect(SpawnType.enemyRocket.isEnemy, isTrue);
        expect(SpawnType.enemyLeader.isEnemy, isTrue);
        expect(SpawnType.player.isEnemy, isFalse);
        expect(SpawnType.birdLeft.isEnemy, isFalse);
      });

      test('isBird', () {
        expect(SpawnType.birdLeft.isBird, isTrue);
        expect(SpawnType.birdRight.isBird, isTrue);
        expect(SpawnType.player.isBird, isFalse);
      });

      test('isEnvironment includes decoration types', () {
        expect(SpawnType.shrub.isEnvironment, isTrue);
        expect(SpawnType.tree.isEnvironment, isTrue);
        expect(SpawnType.buildingRoof.isEnvironment, isTrue);
        expect(SpawnType.snowman.isEnvironment, isTrue);
        expect(SpawnType.shrub2.isEnvironment, isTrue);
        expect(SpawnType.enemy.isEnvironment, isFalse);
      });
    });
  });
}
