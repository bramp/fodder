import 'package:flutter_test/flutter_test.dart';

import 'package:fodder_game/game/sprites/sprite_frames.dart';

void main() {
  group('environmentFrameKey', () {
    test('converts simple names to atlas frame keys', () {
      expect(environmentFrameKey('shrub'), 'ingame/env_shrub_0');
      expect(environmentFrameKey('tree'), 'ingame/env_tree_0');
      expect(environmentFrameKey('snowman'), 'ingame/env_snowman_0');
      expect(environmentFrameKey('shrub2'), 'ingame/env_shrub2_0');
    });

    test('converts camelCase names to snake_case', () {
      expect(environmentFrameKey('buildingRoof'), 'ingame/env_building_roof_0');
    });
  });
}
