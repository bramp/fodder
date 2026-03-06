import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fodder_game/game/systems/squad_movement.dart';

void main() {
  group('buildChainPaths', () {
    test('single member gets path unchanged', () {
      final path = [Vector2(100, 200), Vector2(200, 300)];

      final result = buildChainPaths(memberCount: 1, pathToTarget: path);

      expect(result, hasLength(1));
      expect(result[0], hasLength(2));
      expect(result[0][0], Vector2(100, 200));
      expect(result[0][1], Vector2(200, 300));
    });

    test('all members get identical paths', () {
      final path = [Vector2(50, 0), Vector2(100, 0)];

      final result = buildChainPaths(memberCount: 3, pathToTarget: path);

      expect(result, hasLength(3));
      for (final memberPath in result) {
        expect(memberPath, hasLength(2));
        expect(memberPath[0], Vector2(50, 0));
        expect(memberPath[1], Vector2(100, 0));
      }
    });

    test('empty path gives empty lists for every member', () {
      final result = buildChainPaths(memberCount: 2, pathToTarget: <Vector2>[]);

      expect(result, hasLength(2));
      for (final memberPath in result) {
        expect(memberPath, isEmpty);
      }
    });

    test('each member path is an independent clone', () {
      final target = Vector2(100, 0);

      final result = buildChainPaths(memberCount: 2, pathToTarget: [target]);

      // Mutating the original target should not affect the result.
      target.setValues(999, 999);
      expect(result[0][0], Vector2(100, 0));
      expect(result[1][0], Vector2(100, 0));

      // Mutating one member's path should not affect the other.
      result[0][0].setValues(42, 42);
      expect(result[1][0], Vector2(100, 0));
    });

    test('squadMemberSpacing constant is 16', () {
      expect(squadMemberSpacing, 16);
    });
  });
}
