import 'package:flutter_test/flutter_test.dart';
import 'package:fodder_game/game/map/level_map.dart';

void main() {
  group('LevelMap', () {
    test('can be instantiated', () {
      final levelMap = LevelMap(mapFile: 'mapm1.tmx');
      expect(levelMap, isNotNull);
      expect(levelMap.mapFile, 'mapm1.tmx');
    });

    test('tiledComponent is null before load', () {
      final levelMap = LevelMap(mapFile: 'mapm1.tmx');
      expect(levelMap.tiledComponent, isNull);
      expect(levelMap.mapWidth, 0);
      expect(levelMap.mapHeight, 0);
    });
  });
}
