import 'package:flutter_test/flutter_test.dart';

import 'package:fodder_game/game/systems/pathfinder.dart';
import 'package:fodder_game/game/systems/walkability_grid.dart';

/// Shorthand aliases.
const TerrainType _l = TerrainType.land;
const TerrainType _b = TerrainType.block;

void main() {
  group('Pathfinder (sub-tile resolution)', () {
    test('finds path on open grid', () {
      // 5×5 tile grid → 40×40 sub-tile grid.
      final grid = WalkabilityGrid.fromData(
        List.generate(5, (_) => List.filled(5, _l)),
      );
      final pathfinder = Pathfinder(grid);

      // Sub-tile coords: tile (0,0) → (0,0), tile (4,4) → (32,32).
      final path = pathfinder.findPath(start: (0, 0), end: (32, 32));

      expect(path, isNotEmpty);
      // First waypoint should be near start, last near end.
      expect(path.first.x, greaterThanOrEqualTo(0));
      expect(path.last.x, greaterThan(path.first.x));
    });

    test('returns empty path when start equals end', () {
      final grid = WalkabilityGrid.fromData(
        List.generate(3, (_) => List.filled(3, _l)),
      );
      final pathfinder = Pathfinder(grid);

      final path = pathfinder.findPath(start: (8, 8), end: (8, 8));

      expect(path, isEmpty);
    });

    test('returns empty path when end is blocked', () {
      final grid = WalkabilityGrid.fromData([
        [_l, _l, _l],
        [_l, _b, _l],
        [_l, _l, _l],
      ]);
      final pathfinder = Pathfinder(grid);

      // Tile (1,1) is block → sub-tiles (8..15, 8..15) are all blocked.
      final path = pathfinder.findPath(start: (0, 0), end: (8, 8));

      expect(path, isEmpty);
    });

    test('avoids barriers', () {
      // Wall in the middle row except edges.
      final grid = WalkabilityGrid.fromData([
        [_l, _l, _l, _l, _l],
        [_l, _l, _l, _l, _l],
        [_l, _b, _b, _b, _l],
        [_l, _l, _l, _l, _l],
        [_l, _l, _l, _l, _l],
      ]);
      final pathfinder = Pathfinder(grid);

      // Tile (2,0) → sub-tile (16,0), tile (2,4) → sub-tile (16,32).
      final path = pathfinder.findPath(start: (16, 0), end: (16, 32));

      // Should find a path around the wall.
      expect(path, isNotEmpty);
    });

    test('returns empty path for unreachable target', () {
      // Target surrounded by barriers.
      final grid = WalkabilityGrid.fromData([
        [_l, _l, _l, _l, _l],
        [_l, _b, _b, _b, _l],
        [_l, _b, _l, _b, _l],
        [_l, _b, _b, _b, _l],
        [_l, _l, _l, _l, _l],
      ]);
      final pathfinder = Pathfinder(grid);

      // Tile (2,2) → sub-tile (16,16), which is walkable but unreachable.
      final path = pathfinder.findPath(start: (0, 0), end: (16, 16));

      expect(path, isEmpty);
    });

    test('returns empty path for out-of-bounds coordinates', () {
      final grid = WalkabilityGrid.fromData(
        List.generate(3, (_) => List.filled(3, _l)),
      );
      final pathfinder = Pathfinder(grid);

      expect(pathfinder.findPath(start: (-1, 0), end: (16, 16)), isEmpty);
      expect(pathfinder.findPath(start: (0, 0), end: (80, 80)), isEmpty);
    });
  });

  group('findNearestWalkableSubTile', () {
    test('returns target when target is already walkable', () {
      final grid = WalkabilityGrid.fromData(
        List.generate(3, (_) => List.filled(3, _l)),
      );
      final pathfinder = Pathfinder(grid);

      final result = pathfinder.findNearestWalkableSubTile(
        origin: (0, 0),
        target: (16, 16),
      );

      expect(result, (16, 16));
    });

    test('traces back from blocked target to near edge', () {
      // Row of blocks in the middle (tile row 1).
      final grid = WalkabilityGrid.fromData([
        [_l, _l, _l],
        [_b, _b, _b],
        [_l, _l, _l],
      ]);
      final pathfinder = Pathfinder(grid);

      // Origin at top-left, target inside the blocked row.
      // Trace back should find the last walkable cell before the block.
      final result = pathfinder.findNearestWalkableSubTile(
        origin: (0, 0),
        target: (10, 10), // inside block tile (1,1)
      );

      expect(result, isNotNull);
      // The result should be walkable.
      expect(grid.isSubTileWalkable(result!.$1, result.$2), isTrue);
      // And it should be between origin and target (y < 8, the block start).
      expect(result.$2, lessThan(8));
    });

    test('returns null when entire line is unwalkable', () {
      // All blocked except a tiny corner the line doesn't cross.
      final grid = WalkabilityGrid.fromData([
        [_b, _b],
        [_b, _b],
      ]);
      final pathfinder = Pathfinder(grid);

      final result = pathfinder.findNearestWalkableSubTile(
        origin: (0, 0),
        target: (8, 8),
      );

      expect(result, isNull);
    });

    test('finds edge of large blocked area (forest scenario)', () {
      // Big "forest" occupying tiles (1..3, 0..4) with walkable border.
      final grid = WalkabilityGrid.fromData([
        [_l, _b, _b, _b, _l],
        [_l, _b, _b, _b, _l],
        [_l, _b, _b, _b, _l],
        [_l, _b, _b, _b, _l],
        [_l, _b, _b, _b, _l],
      ]);
      final pathfinder = Pathfinder(grid);

      // Click deep inside forest, origin on the left.
      final result = pathfinder.findNearestWalkableSubTile(
        origin: (2, 16), // left walkable column
        target: (20, 16), // deep in forest
      );

      expect(result, isNotNull);
      expect(grid.isSubTileWalkable(result!.$1, result.$2), isTrue);
      // Should be on the near (left) edge of the forest.
      expect(result.$1, lessThan(8)); // tile column 0 is walkable (0..7)
    });

    test('origin equals target returns target if walkable', () {
      final grid = WalkabilityGrid.fromData(
        List.generate(2, (_) => List.filled(2, _l)),
      );
      final pathfinder = Pathfinder(grid);

      final result = pathfinder.findNearestWalkableSubTile(
        origin: (5, 5),
        target: (5, 5),
      );

      expect(result, (5, 5));
    });
  });
}
