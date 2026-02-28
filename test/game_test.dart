import 'package:flutter_test/flutter_test.dart';
import 'package:fodder/game/fodder_game.dart';

void main() {
  group('FodderGame', () {
    test('can be instantiated', () {
      final game = FodderGame();
      expect(game, isNotNull);
    });
  });
}
