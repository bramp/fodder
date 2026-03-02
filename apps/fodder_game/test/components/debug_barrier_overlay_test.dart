import 'package:flutter_test/flutter_test.dart';

import 'package:fodder_game/game/systems/walkability_grid.dart';

void main() {
  group('DebugBarrierOverlay', () {
    test('can be instantiated with an empty grid', () {
      final grid = WalkabilityGrid.fromData([]);
      expect(grid.width, 0);
      expect(grid.height, 0);
    });

    test('can be instantiated with a small grid', () {
      final grid = WalkabilityGrid.fromData([
        [TerrainType.land, TerrainType.block],
        [TerrainType.block, TerrainType.land],
      ]);
      expect(grid.width, 2);
      expect(grid.height, 2);
    });
  });
}
