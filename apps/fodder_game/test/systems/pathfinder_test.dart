import 'package:flutter_test/flutter_test.dart';

import 'package:fodder_game/game/systems/pathfinder.dart';
import 'package:fodder_game/game/systems/walkability_grid.dart';

/// Shorthand aliases.
const TerrainType _l = TerrainType.land;
const TerrainType _b = TerrainType.block;

void main() {
  group('Pathfinder', () {
    test('finds path on open grid', () {
      // 5×5 fully walkable grid.
      final grid = WalkabilityGrid.fromData(
        List.generate(5, (_) => List.filled(5, _l)),
      );
      final pathfinder = Pathfinder(grid);

      final path = pathfinder.findPath(
        startTile: (0, 0),
        endTile: (4, 4),
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
        startTile: (1, 1),
        endTile: (1, 1),
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

      final path = pathfinder.findPath(
        startTile: (0, 0),
        endTile: (1, 1),
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

      final path = pathfinder.findPath(
        startTile: (2, 0),
        endTile: (2, 4),
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

      final path = pathfinder.findPath(
        startTile: (0, 0),
        endTile: (2, 2),
      );

      expect(path, isEmpty);
    });

    test('returns empty path for out-of-bounds coordinates', () {
      final grid = WalkabilityGrid.fromData(
        List.generate(3, (_) => List.filled(3, _l)),
      );
      final pathfinder = Pathfinder(grid);

      expect(
        pathfinder.findPath(startTile: (-1, 0), endTile: (2, 2)),
        isEmpty,
      );
      expect(
        pathfinder.findPath(startTile: (0, 0), endTile: (10, 10)),
        isEmpty,
      );
    });
  });
}
