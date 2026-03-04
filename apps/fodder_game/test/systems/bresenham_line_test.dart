import 'package:flutter_test/flutter_test.dart';

import 'package:fodder_game/game/systems/bresenham_line.dart';

void main() {
  group('bresenhamLine', () {
    test('single point when start equals end', () {
      final cells = bresenhamLine(5, 5, 5, 5).toList();
      expect(cells, [(5, 5)]);
    });

    test('horizontal line left to right', () {
      final cells = bresenhamLine(0, 0, 4, 0).toList();
      expect(cells, [(0, 0), (1, 0), (2, 0), (3, 0), (4, 0)]);
    });

    test('horizontal line right to left', () {
      final cells = bresenhamLine(4, 0, 0, 0).toList();
      expect(cells, [(4, 0), (3, 0), (2, 0), (1, 0), (0, 0)]);
    });

    test('vertical line top to bottom', () {
      final cells = bresenhamLine(0, 0, 0, 3).toList();
      expect(cells, [(0, 0), (0, 1), (0, 2), (0, 3)]);
    });

    test('vertical line bottom to top', () {
      final cells = bresenhamLine(0, 3, 0, 0).toList();
      expect(cells, [(0, 3), (0, 2), (0, 1), (0, 0)]);
    });

    test('diagonal line', () {
      final cells = bresenhamLine(0, 0, 3, 3).toList();
      expect(cells, [(0, 0), (1, 1), (2, 2), (3, 3)]);
    });

    test('diagonal line negative direction', () {
      final cells = bresenhamLine(3, 3, 0, 0).toList();
      expect(cells, [(3, 3), (2, 2), (1, 1), (0, 0)]);
    });

    test('steep line (dy > dx)', () {
      final cells = bresenhamLine(0, 0, 1, 4).toList();
      // Should visit 5 cells.
      expect(cells.length, 5);
      expect(cells.first, (0, 0));
      expect(cells.last, (1, 4));
      // Y should be monotonically increasing.
      for (var i = 1; i < cells.length; i++) {
        expect(cells[i].$2, greaterThan(cells[i - 1].$2));
      }
    });

    test('shallow line (dx > dy)', () {
      final cells = bresenhamLine(0, 0, 4, 1).toList();
      // Should visit 5 cells.
      expect(cells.length, 5);
      expect(cells.first, (0, 0));
      expect(cells.last, (4, 1));
      // X should be monotonically increasing.
      for (var i = 1; i < cells.length; i++) {
        expect(cells[i].$1, greaterThan(cells[i - 1].$1));
      }
    });

    test('includes both endpoints', () {
      final cells = bresenhamLine(2, 3, 7, 5).toList();
      expect(cells.first, (2, 3));
      expect(cells.last, (7, 5));
    });

    test('works with negative coordinates', () {
      final cells = bresenhamLine(-2, -1, 2, 1).toList();
      expect(cells.first, (-2, -1));
      expect(cells.last, (2, 1));
      // Should be contiguous (each step differs by at most 1 in each axis).
      for (var i = 1; i < cells.length; i++) {
        expect((cells[i].$1 - cells[i - 1].$1).abs(), lessThanOrEqualTo(1));
        expect((cells[i].$2 - cells[i - 1].$2).abs(), lessThanOrEqualTo(1));
      }
    });

    test('line is symmetric in cell count', () {
      // Forward and reverse should visit the same number of cells.
      final forward = bresenhamLine(1, 2, 8, 5).toList();
      final reverse = bresenhamLine(8, 5, 1, 2).toList();
      expect(forward.length, reverse.length);
    });
  });
}
