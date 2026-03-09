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

    test('average returns (min + max) ~/ 2', () {
      expect(AggressionAssigner().average, 6);
      expect(AggressionAssigner(min: 2, max: 10).average, 6);
      expect(AggressionAssigner(min: 0, max: 1).average, 0);
      expect(AggressionAssigner(min: 5, max: 5).average, 5);
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

  group('AggressionAssigner.recordDynamicSpawn', () {
    test('escalates max after 16 spawns', () {
      final assigner = AggressionAssigner();
      expect(assigner.max, 8);

      // 15 spawns: no escalation.
      for (var i = 0; i < 15; i++) {
        assigner.recordDynamicSpawn();
      }
      expect(assigner.max, 8);

      // 16th spawn triggers escalation.
      assigner.recordDynamicSpawn();
      expect(assigner.max, 9);
    });

    test('escalates again after another 16 spawns', () {
      final assigner = AggressionAssigner();
      for (var i = 0; i < 32; i++) {
        assigner.recordDynamicSpawn();
      }
      expect(assigner.max, 10);
    });

    test('caps at aggressionMaxCap (30)', () {
      final assigner = AggressionAssigner(max: 29);

      // 16 spawns → max becomes 30.
      for (var i = 0; i < 16; i++) {
        assigner.recordDynamicSpawn();
      }
      expect(assigner.max, 30);

      // Another 16 → stays at 30.
      for (var i = 0; i < 16; i++) {
        assigner.recordDynamicSpawn();
      }
      expect(assigner.max, 30);
    });

    test('reset clears spawn counter', () {
      final assigner = AggressionAssigner();
      // Record 15 spawns (almost at threshold).
      for (var i = 0; i < 15; i++) {
        assigner.recordDynamicSpawn();
      }
      assigner
        ..reset()
        // One more spawn should NOT trigger escalation after reset.
        ..recordDynamicSpawn();
      expect(assigner.max, 8);
    });

    test('average updates after escalation', () {
      final assigner = AggressionAssigner();
      expect(assigner.average, 6);

      for (var i = 0; i < 16; i++) {
        assigner.recordDynamicSpawn();
      }
      // max is now 9, average = (4 + 9) ~/ 2 = 6.
      expect(assigner.average, 6);

      for (var i = 0; i < 16; i++) {
        assigner.recordDynamicSpawn();
      }
      // max is now 10, average = (4 + 10) ~/ 2 = 7.
      expect(assigner.average, 7);
    });

    test('next() respects escalated max', () {
      final assigner = AggressionAssigner(max: 5);
      // midpoint = 4, oscillation: 4, 5, 4, 5, ...

      // Escalate max to 6.
      for (var i = 0; i < 16; i++) {
        assigner.recordDynamicSpawn();
      }
      expect(assigner.max, 6);

      // Generate values — now can reach 6.
      final values = List.generate(20, (_) => assigner.next());
      expect(values, everyElement(inInclusiveRange(4, 6)));
      expect(values, contains(6));
    });
  });
}
