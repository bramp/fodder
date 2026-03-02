import 'package:flutter_test/flutter_test.dart';

import 'package:fodder_game/game/systems/line_of_sight.dart';
import 'package:fodder_game/game/systems/walkability_grid.dart';

/// Helper: builds a WalkabilityGrid from a 2D list of booleans.
///
/// `true` = walkable (land), `false` = blocked.
/// Each cell represents one tile (8×8 sub-tiles).
WalkabilityGrid _gridFromBools(List<List<bool>> cells) {
  return WalkabilityGrid.fromData(
    cells
        .map(
          (row) =>
              row.map((w) => w ? TerrainType.land : TerrainType.block).toList(),
        )
        .toList(),
  );
}

void main() {
  group('hasLineOfSight', () {
    // Each tile is 8 sub-tiles wide/tall. Sub-tile size = 4 px.
    // So one tile = 32 world pixels (8 * 4).

    test('clear line on fully walkable grid', () {
      // 4×4 tiles, all walkable.
      final grid = _gridFromBools([
        [true, true, true, true],
        [true, true, true, true],
        [true, true, true, true],
        [true, true, true, true],
      ]);

      expect(
        hasLineOfSight(
          grid: grid,
          startX: 16,
          startY: 16, // tile (0,0)
          endX: 112,
          endY: 112, // tile (3,3)
        ),
        isTrue,
      );
    });

    test('blocked by wall tile in the middle', () {
      // 3×1 tiles: [walkable, blocked, walkable]
      final grid = _gridFromBools([
        [true, false, true],
      ]);

      // Line from tile 0 to tile 2 must cross tile 1 (blocked).
      expect(
        hasLineOfSight(
          grid: grid,
          startX: 4,
          startY: 2, // tile 0
          endX: 80,
          endY: 2, // tile 2
        ),
        isFalse,
      );
    });

    test('same point always has LOS', () {
      final grid = _gridFromBools([
        [true],
      ]);

      expect(
        hasLineOfSight(
          grid: grid,
          startX: 2,
          startY: 2,
          endX: 2,
          endY: 2,
        ),
        isTrue,
      );
    });

    test('adjacent walkable tiles have LOS', () {
      final grid = _gridFromBools([
        [true, true],
      ]);

      expect(
        hasLineOfSight(
          grid: grid,
          startX: 4,
          startY: 2,
          endX: 36,
          endY: 2,
        ),
        isTrue,
      );
    });

    test('diagonal line blocked by wall tile', () {
      // 3×3 grid with center blocked.
      final grid = _gridFromBools([
        [true, true, true],
        [true, false, true],
        [true, true, true],
      ]);

      // Diagonal from (0,0) to (2,2) passes through (1,1).
      expect(
        hasLineOfSight(
          grid: grid,
          startX: 4,
          startY: 4,
          endX: 68,
          endY: 68,
        ),
        isFalse,
      );
    });

    test('diagonal line avoids wall tile', () {
      // 3×3 grid with bottom-right blocked.
      final grid = _gridFromBools([
        [true, true, true],
        [true, true, true],
        [true, true, false],
      ]);

      // From (0,0) to (1,1) — doesn't touch (2,2).
      expect(
        hasLineOfSight(
          grid: grid,
          startX: 4,
          startY: 4,
          endX: 36,
          endY: 36,
        ),
        isTrue,
      );
    });

    test('diagonal line blocked by wall between start and end', () {
      // Wall runs vertically through the middle:
      // [open, blocked, open]
      // [open, blocked, open]
      // [open, blocked, open]
      final grid = _gridFromBools([
        [true, false, true],
        [true, false, true],
        [true, false, true],
      ]);

      // Straight horizontal line from tile 0 to tile 2 — blocked.
      expect(
        hasLineOfSight(
          grid: grid,
          startX: 4,
          startY: 36, // tile (0,1)
          endX: 68,
          endY: 36, // tile (2,1)
        ),
        isFalse,
      );

      // Diagonal line also blocked.
      expect(
        hasLineOfSight(
          grid: grid,
          startX: 4,
          startY: 4, // tile (0,0)
          endX: 68,
          endY: 68, // tile (2,2)
        ),
        isFalse,
      );
    });

    test('out of bounds coordinates are treated as blocked', () {
      final grid = _gridFromBools([
        [true, true],
      ]);

      // End point is far off the grid.
      expect(
        hasLineOfSight(
          grid: grid,
          startX: 4,
          startY: 2,
          endX: 200,
          endY: 2,
        ),
        isFalse,
      );
    });

    test('vertical line through walkable tiles', () {
      final grid = _gridFromBools([
        [true],
        [true],
        [true],
      ]);

      expect(
        hasLineOfSight(
          grid: grid,
          startX: 4,
          startY: 4,
          endX: 4,
          endY: 68,
        ),
        isTrue,
      );
    });

    test('vertical line blocked', () {
      final grid = _gridFromBools([
        [true],
        [false],
        [true],
      ]);

      expect(
        hasLineOfSight(
          grid: grid,
          startX: 4,
          startY: 4,
          endX: 4,
          endY: 68,
        ),
        isFalse,
      );
    });
  });
}
