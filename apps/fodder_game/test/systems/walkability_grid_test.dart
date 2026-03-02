import 'package:flutter_test/flutter_test.dart';

import 'package:fodder_game/game/systems/walkability_grid.dart';

/// Shorthand aliases for readability.
const TerrainType _land = TerrainType.land;
const TerrainType _block = TerrainType.block;
const TerrainType _water = TerrainType.water;

void main() {
  group('WalkabilityGrid', () {
    test('fromData creates grid with correct dimensions', () {
      final grid = WalkabilityGrid.fromData([
        [_land, _block, _land],
        [_land, _land, _block],
      ]);
      expect(grid.width, 3);
      expect(grid.height, 2);
    });

    test('isWalkable returns correct values', () {
      final grid = WalkabilityGrid.fromData([
        [_land, _block, _land],
        [_block, _land, _block],
      ]);
      expect(grid.isWalkable(0, 0), isTrue);
      expect(grid.isWalkable(1, 0), isFalse);
      expect(grid.isWalkable(2, 0), isTrue);
      expect(grid.isWalkable(0, 1), isFalse);
      expect(grid.isWalkable(1, 1), isTrue);
      expect(grid.isWalkable(2, 1), isFalse);
    });

    test('terrainAt returns correct terrain types', () {
      final grid = WalkabilityGrid.fromData([
        [_land, _water, _block],
      ]);
      expect(grid.terrainAt(0, 0), TerrainType.land);
      expect(grid.terrainAt(1, 0), TerrainType.water);
      expect(grid.terrainAt(2, 0), TerrainType.block);
    });

    test('out-of-bounds returns false / block', () {
      final grid = WalkabilityGrid.fromData([
        [_land, _land],
        [_land, _land],
      ]);
      expect(grid.isWalkable(-1, 0), isFalse);
      expect(grid.isWalkable(0, -1), isFalse);
      expect(grid.isWalkable(2, 0), isFalse);
      expect(grid.isWalkable(0, 2), isFalse);
      expect(grid.isWalkable(100, 100), isFalse);
      expect(grid.terrainAt(-1, 0), TerrainType.block);
    });

    test('empty grid has zero dimensions', () {
      final grid = WalkabilityGrid.fromData([]);
      expect(grid.width, 0);
      expect(grid.height, 0);
      expect(grid.isWalkable(0, 0), isFalse);
    });
  });

  group('TerrainType', () {
    test('fromValue returns correct enum for known values', () {
      expect(TerrainType.fromValue(0), TerrainType.land);
      expect(TerrainType.fromValue(3), TerrainType.block);
      expect(TerrainType.fromValue(6), TerrainType.water);
      expect(TerrainType.fromValue(14), TerrainType.jump);
    });

    test('fromValue returns land for unknown / negative values', () {
      expect(TerrainType.fromValue(-1), TerrainType.land);
      expect(TerrainType.fromValue(99), TerrainType.land);
    });

    test('blocksWalking is true only for block', () {
      expect(TerrainType.block.blocksWalking, isTrue);
      expect(TerrainType.land.blocksWalking, isFalse);
      expect(TerrainType.water.blocksWalking, isFalse);
      expect(TerrainType.drop.blocksWalking, isFalse);
    });

    test('label returns human-readable name', () {
      expect(TerrainType.land.label, 'Land');
      expect(TerrainType.quickSand.label, 'Quick Sand');
      expect(TerrainType.waterEdge.label, 'Water Edge');
    });

    group('fromRawHit', () {
      test('positive values: masks lower 4 bits', () {
        // Raw value 3 → Block
        expect(TerrainType.fromRawHit(3), TerrainType.block);
        // Raw value 0x33 (51) → lower nibble 3 → Block
        expect(TerrainType.fromRawHit(0x33), TerrainType.block);
        // Raw value 0x73 (115) → lower nibble 3 → Block
        expect(TerrainType.fromRawHit(0x73), TerrainType.block);
        // Raw value 0x30 (48) → lower nibble 0 → Land
        expect(TerrainType.fromRawHit(0x30), TerrainType.land);
      });

      test('negative values: resolves mixed terrain with block', () {
        // 0x8030 → primary=Land(0), secondary=Block(3) → Block wins
        expect(TerrainType.fromRawHit(-32720), TerrainType.block); // 0x8030
        // 0x8003 → primary=Block(3), secondary=Land(0) → Block
        expect(TerrainType.fromRawHit(-32765), TerrainType.block); // 0x8003
        // 0x8073 → primary=Block(3), secondary=Snow(7) → Block
        expect(TerrainType.fromRawHit(-32653), TerrainType.block); // 0x8073
      });

      test('negative values: non-blocking mixed returns interesting type', () {
        // 0x8070 → primary=Land(0), secondary=Snow(7) → Snow
        expect(TerrainType.fromRawHit(-32656), TerrainType.snow); // 0x8070
        // 0x8002 → primary=Rocky2(2), secondary=Land(0) → Rocky2
        expect(TerrainType.fromRawHit(-32766), TerrainType.rocky2); // 0x8002
        // 0x8050 → primary=Land(0), secondary=WaterEdge(5) → WaterEdge
        expect(
          TerrainType.fromRawHit(-32688),
          TerrainType.waterEdge,
        ); // 0x8050
      });

      test('zero returns land', () {
        expect(TerrainType.fromRawHit(0), TerrainType.land);
      });
    });
  });
}
