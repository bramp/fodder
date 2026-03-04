import 'package:flutter_test/flutter_test.dart';

import 'package:fodder_game/game/components/environment_sprite.dart';

void main() {
  group('environmentSpriteFrames', () {
    test('maps all five environment sprite names', () {
      expect(environmentSpriteFrames, hasLength(5));
    });

    test('shrub maps to env_shrub frame', () {
      expect(environmentSpriteFrames['shrub'], 'ingame/env_shrub_0');
    });

    test('tree maps to env_tree frame', () {
      expect(environmentSpriteFrames['tree'], 'ingame/env_tree_0');
    });

    test('buildingRoof maps to env_building_roof frame', () {
      expect(
        environmentSpriteFrames['buildingRoof'],
        'ingame/env_building_roof_0',
      );
    });

    test('snowman maps to env_snowman frame', () {
      expect(environmentSpriteFrames['snowman'], 'ingame/env_snowman_0');
    });

    test('shrub2 maps to env_shrub2 frame', () {
      expect(environmentSpriteFrames['shrub2'], 'ingame/env_shrub2_0');
    });
  });

  group('environmentSpriteNames', () {
    test('contains exactly the five environment names', () {
      expect(
        environmentSpriteNames,
        {'shrub', 'tree', 'buildingRoof', 'snowman', 'shrub2'},
      );
    });

    test('does not contain player or enemy names', () {
      expect(environmentSpriteNames.contains('player'), isFalse);
      expect(environmentSpriteNames.contains('enemy'), isFalse);
      expect(environmentSpriteNames.contains('enemyRocket'), isFalse);
    });

    test('does not contain bird name', () {
      expect(environmentSpriteNames.contains('birdLeft'), isFalse);
    });
  });
}
