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
      final path = pathfinder.findPath(
        start: (0, 0),
        end: (32, 32),
      );

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

      final path = pathfinder.findPath(
        start: (8, 8),
        end: (8, 8),
      );

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
      final path = pathfinder.findPath(
        start: (0, 0),
        end: (8, 8),
      );

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
      final path = pathfinder.findPath(
        start: (16, 0),
        end: (16, 32),
      );

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
      final path = pathfinder.findPath(
        start: (0, 0),
        end: (16, 16),
      );

      expect(path, isEmpty);
    });

    test('returns empty path for out-of-bounds coordinates', () {
      final grid = WalkabilityGrid.fromData(
        List.generate(3, (_) => List.filled(3, _l)),
      );
      final pathfinder = Pathfinder(grid);

      expect(
        pathfinder.findPath(start: (-1, 0), end: (16, 16)),
        isEmpty,
      );
      expect(
        pathfinder.findPath(start: (0, 0), end: (80, 80)),
        isEmpty,
      );
    });
  });
}
