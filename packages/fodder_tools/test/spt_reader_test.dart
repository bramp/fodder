import 'dart:typed_data';

import 'package:fodder_tools/spt_reader.dart';
import 'package:test/test.dart';

/// Builds a minimal .spt binary with the given sprite entries.
///
/// Each entry is (direction, padding, x, y, type) as raw uint16 values
/// (before the +0x10 X offset that parseSpt applies).
Uint8List _buildSptBytes(List<(int, int, int, int, int)> entries) {
  final data = Uint8List(entries.length * 10);
  final view = ByteData.sublistView(data);
  for (var i = 0; i < entries.length; i++) {
    final (direction, padding, x, y, type) = entries[i];
    final offset = i * 10;
    view
      ..setUint16(offset, direction, Endian.big)
      ..setUint16(offset + 2, padding, Endian.big)
      ..setUint16(offset + 4, x, Endian.big)
      ..setUint16(offset + 6, y, Endian.big)
      ..setUint16(offset + 8, type, Endian.big);
  }
  return data;
}

void main() {
  group('parseSpt', () {
    test('returns empty list for empty data', () {
      expect(parseSpt(Uint8List(0)), isEmpty);
    });

    test('parses a single player sprite', () {
      final data = _buildSptBytes([(0x007C, 0, 100, 200, 0)]);
      final sprites = parseSpt(data);
      expect(sprites, hasLength(1));
      expect(sprites[0].x, 100 + 0x10); // +16 offset
      expect(sprites[0].y, 200);
      expect(sprites[0].type, 0);
    });

    test('applies +0x10 offset to X coordinate', () {
      final data = _buildSptBytes([(0x007C, 0, 0, 50, 5)]);
      final sprites = parseSpt(data);
      expect(sprites[0].x, 16); // 0 + 0x10
      expect(sprites[0].y, 50);
    });

    test('parses multiple sprites in order', () {
      final data = _buildSptBytes([
        (0x007C, 0, 123, 213, 0), // Player
        (0x007C, 0, 138, 220, 0), // Player
        (0x007C, 0, 81, 49, 5), // Enemy
        (0x007C, 0, 212, 36, 5), // Enemy
        (0x007C, 0, 46, 76, 13), // Shrub
        (0x007C, 0, 176, 84, 14), // Tree
        (0x007C, 0, 260, 25, 66), // BirdLeft
      ]);
      final sprites = parseSpt(data);
      expect(sprites, hasLength(7));

      // Verify order and types.
      expect(sprites[0].type, 0); // Player
      expect(sprites[1].type, 0); // Player
      expect(sprites[2].type, 5); // Enemy
      expect(sprites[3].type, 5); // Enemy
      expect(sprites[4].type, 13); // Shrub
      expect(sprites[5].type, 14); // Tree
      expect(sprites[6].type, 66); // BirdLeft
    });

    test('warns on non-multiple-of-10 length', () {
      final data = Uint8List(13); // 1 full entry + 3 trailing bytes
      String? warning;
      final sprites = parseSpt(data, warn: (msg) => warning = msg);
      expect(sprites, hasLength(1)); // Only one full 10-byte entry
      expect(warning, contains('not a multiple of 10'));
    });

    test('ignores direction and padding fields', () {
      // Use non-standard direction/padding values.
      final data = _buildSptBytes([(0xAAAA, 0xBBBB, 50, 60, 5)]);
      final sprites = parseSpt(data);
      expect(sprites, hasLength(1));
      expect(sprites[0].x, 50 + 0x10);
      expect(sprites[0].y, 60);
      expect(sprites[0].type, 5);
    });
  });

  group('SpriteType', () {
    test('fromValue returns known types', () {
      expect(SpriteType.fromValue(0), SpriteType.player);
      expect(SpriteType.fromValue(5), SpriteType.enemy);
      expect(SpriteType.fromValue(36), SpriteType.enemyRocket);
      expect(SpriteType.fromValue(106), SpriteType.enemyLeader);
      expect(SpriteType.fromValue(13), SpriteType.shrub);
      expect(SpriteType.fromValue(14), SpriteType.tree);
      expect(SpriteType.fromValue(66), SpriteType.birdLeft);
    });

    test('fromValue returns null for unknown types', () {
      expect(SpriteType.fromValue(999), isNull);
      expect(SpriteType.fromValue(-1), isNull);
      expect(SpriteType.fromValue(1), isNull);
    });

    test('isPlayer returns true only for player type', () {
      expect(SpriteType.player.isPlayer, isTrue);
      expect(SpriteType.enemy.isPlayer, isFalse);
      expect(SpriteType.shrub.isPlayer, isFalse);
    });

    test('isEnemy returns true for enemy, enemyRocket, and enemyLeader', () {
      expect(SpriteType.enemy.isEnemy, isTrue);
      expect(SpriteType.enemyRocket.isEnemy, isTrue);
      expect(SpriteType.enemyLeader.isEnemy, isTrue);
      expect(SpriteType.player.isEnemy, isFalse);
      expect(SpriteType.tree.isEnemy, isFalse);
    });

    test('isEnvironment returns true for decoration types', () {
      expect(SpriteType.shrub.isEnvironment, isTrue);
      expect(SpriteType.tree.isEnvironment, isTrue);
      expect(SpriteType.buildingRoof.isEnvironment, isTrue);
      expect(SpriteType.snowman.isEnvironment, isTrue);
      expect(SpriteType.shrub2.isEnvironment, isTrue);
      // Non-environment types.
      expect(SpriteType.player.isEnvironment, isFalse);
      expect(SpriteType.enemy.isEnvironment, isFalse);
      expect(SpriteType.birdLeft.isEnvironment, isFalse);
    });

    test('value property matches expected integers', () {
      expect(SpriteType.player.value, 0);
      expect(SpriteType.enemy.value, 5);
      expect(SpriteType.enemyRocket.value, 36);
      expect(SpriteType.enemyLeader.value, 106);
      expect(SpriteType.hostage.value, 72);
    });
  });

  group('SptSprite', () {
    test('spriteType getter resolves known types', () {
      const sprite = SptSprite(x: 100, y: 200, type: 0);
      expect(sprite.spriteType, SpriteType.player);
    });

    test('spriteType getter returns null for unknown types', () {
      const sprite = SptSprite(x: 100, y: 200, type: 999);
      expect(sprite.spriteType, isNull);
    });

    test('toString includes type name for known types', () {
      const sprite = SptSprite(x: 100, y: 200, type: 5);
      expect(sprite.toString(), contains('enemy'));
    });

    test('toString includes raw type for unknown types', () {
      const sprite = SptSprite(x: 100, y: 200, type: 999);
      expect(sprite.toString(), contains('Type999'));
    });
  });
}
