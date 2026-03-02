import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:fodder_game/game/components/direction8.dart';

void main() {
  group('Direction8.fromVector', () {
    test('zero vector returns south', () {
      expect(Direction8.fromVector(0, 0), Direction8.south);
    });

    test('pure south (dx=0, dy=+1)', () {
      expect(Direction8.fromVector(0, 1), Direction8.south);
    });

    test('pure north (dx=0, dy=-1)', () {
      expect(Direction8.fromVector(0, -1), Direction8.north);
    });

    test('pure east (dx=+1, dy=0)', () {
      expect(Direction8.fromVector(1, 0), Direction8.east);
    });

    test('pure west (dx=-1, dy=0)', () {
      expect(Direction8.fromVector(-1, 0), Direction8.west);
    });

    test('southeast (dx=+1, dy=+1)', () {
      expect(Direction8.fromVector(1, 1), Direction8.southeast);
    });

    test('northeast (dx=+1, dy=-1)', () {
      expect(Direction8.fromVector(1, -1), Direction8.northeast);
    });

    test('southwest (dx=-1, dy=+1)', () {
      expect(Direction8.fromVector(-1, 1), Direction8.southwest);
    });

    test('northwest (dx=-1, dy=-1)', () {
      expect(Direction8.fromVector(-1, -1), Direction8.northwest);
    });

    test('all 8 directions are reachable', () {
      // Sweep 8 angles evenly around the circle.
      final expected = [
        Direction8.south,
        Direction8.southeast,
        Direction8.east,
        Direction8.northeast,
        Direction8.north,
        Direction8.northwest,
        Direction8.west,
        Direction8.southwest,
      ];

      for (var i = 0; i < 8; i++) {
        final angle = i * pi / 4;
        final dx = sin(angle);
        final dy = cos(angle);
        expect(
          Direction8.fromVector(dx, dy),
          expected[i],
          reason: 'angle=${i * 45}° dx=$dx dy=$dy',
        );
      }
    });
  });

  group('Direction8.suffix', () {
    test('returns correct short names for all directions', () {
      expect(Direction8.south.suffix, 's');
      expect(Direction8.southwest.suffix, 'sw');
      expect(Direction8.west.suffix, 'w');
      expect(Direction8.northwest.suffix, 'nw');
      expect(Direction8.north.suffix, 'n');
      expect(Direction8.northeast.suffix, 'ne');
      expect(Direction8.east.suffix, 'e');
      expect(Direction8.southeast.suffix, 'se');
    });
  });
}
