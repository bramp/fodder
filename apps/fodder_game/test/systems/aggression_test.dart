import 'package:flutter_test/flutter_test.dart';

import 'package:fodder_game/game/systems/aggression.dart';

void main() {
  group('AggressionAssigner', () {
    test('defaults to min=4 max=8', () {
      final assigner = AggressionAssigner();
      expect(assigner.min, 4);
      expect(assigner.max, 8);
    });

    test('first value is midpoint', () {
      final assigner = AggressionAssigner();
      // (4 + 8) ~/ 2 = 6
      expect(assigner.next(), 6);
    });

    test('oscillates upward then bounces', () {
      final assigner = AggressionAssigner();
      final values = List.generate(8, (_) => assigner.next());

      // Starts at 6, increments to 8, bounces down to 4, bounces up.
      expect(values, [6, 7, 8, 7, 6, 5, 4, 5]);
    });

    test('continues oscillating over many calls', () {
      final assigner = AggressionAssigner();
      final values = List.generate(16, (_) => assigner.next());

      // Full cycle is 8 values: 6,7,8,7,6,5,4,5 then repeats.
      expect(values, [6, 7, 8, 7, 6, 5, 4, 5, 6, 7, 8, 7, 6, 5, 4, 5]);
    });

    test('custom min/max range', () {
      final assigner = AggressionAssigner(min: 2, max: 4);
      // midpoint = 3
      final values = List.generate(6, (_) => assigner.next());

      expect(values, [3, 4, 3, 2, 3, 4]);
    });

    test('min equals max returns constant', () {
      final assigner = AggressionAssigner(min: 5, max: 5);
      final values = List.generate(4, (_) => assigner.next());

      expect(values, [5, 5, 5, 5]);
    });

    test('adjacent min/max oscillates between two values', () {
      final assigner = AggressionAssigner(min: 3, max: 4);
      // midpoint = 3
      final values = List.generate(6, (_) => assigner.next());

      expect(values, [3, 4, 3, 4, 3, 4]);
    });

    test('reset returns to initial state', () {
      // Consume a few values then reset.
      final assigner = AggressionAssigner()
        ..next()
        ..next()
        ..next()
        ..reset();

      // Should restart from midpoint.
      expect(assigner.next(), 6);
    });

    test('all values stay within min..max', () {
      final assigner = AggressionAssigner(min: 1, max: 10);
      final values = List.generate(50, (_) => assigner.next());

      for (final v in values) {
        expect(v, greaterThanOrEqualTo(1));
        expect(v, lessThanOrEqualTo(10));
      }
    });
  });
}
