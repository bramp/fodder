import 'dart:convert';

import 'package:fodder_tools/atlas_writer.dart';
import 'package:test/test.dart';

void main() {
  group('generateAtlasJson', () {
    test('produces valid TexturePacker JSON Hash format', () {
      final json = generateAtlasJson(
        imageFilename: 'test.png',
        imageWidth: 320,
        imageHeight: 256,
        entries: [
          const AtlasEntry(
            name: 'Font/00_0',
            x: 0,
            y: 0,
            width: 16,
            height: 17,
          ),
          const AtlasEntry(
            name: 'Font/00_1',
            x: 16,
            y: 0,
            width: 16,
            height: 17,
            anchorX: -3,
            anchorY: 5,
          ),
        ],
      );

      final parsed = jsonDecode(json) as Map<String, dynamic>;

      // Check meta section.
      final meta = parsed['meta'] as Map<String, dynamic>;
      expect(meta['image'], 'test.png');
      expect(meta['format'], 'RGBA8888');
      expect((meta['size'] as Map)['w'], 320);
      expect((meta['size'] as Map)['h'], 256);
      expect(meta['scale'], 1);

      // Check frames section.
      final frames = parsed['frames'] as Map<String, dynamic>;
      expect(frames, hasLength(2));

      // First sprite — no anchor offset.
      final font00 = frames['Font/00_0'] as Map<String, dynamic>;
      final frame0 = font00['frame'] as Map<String, dynamic>;
      expect(frame0['x'], 0);
      expect(frame0['y'], 0);
      expect(frame0['w'], 16);
      expect(frame0['h'], 17);
      expect(font00['rotated'], false);
      expect(font00['trimmed'], false);

      final src0 = font00['spriteSourceSize'] as Map<String, dynamic>;
      expect(src0['x'], 0);
      expect(src0['y'], 0);
      expect(src0['w'], 16);
      expect(src0['h'], 17);

      final size0 = font00['sourceSize'] as Map<String, dynamic>;
      expect(size0['w'], 16);
      expect(size0['h'], 17);

      // Second sprite — with anchor offset.
      final font01 = frames['Font/00_1'] as Map<String, dynamic>;
      final anchor = font01['anchor'] as Map<String, dynamic>;
      expect(anchor['x'], -3);
      expect(anchor['y'], 5);
    });

    test('handles empty entries list', () {
      final json = generateAtlasJson(
        imageFilename: 'empty.png',
        imageWidth: 320,
        imageHeight: 100,
        entries: [],
      );

      final parsed = jsonDecode(json) as Map<String, dynamic>;
      final frames = parsed['frames'] as Map<String, dynamic>;
      expect(frames, isEmpty);
    });

    test('preserves sprite name ordering', () {
      final entries = [
        for (var i = 0; i < 5; i++)
          AtlasEntry(name: 'group_$i', x: i * 16, y: 0, width: 16, height: 16),
      ];

      final json = generateAtlasJson(
        imageFilename: 'test.png',
        imageWidth: 320,
        imageHeight: 16,
        entries: entries,
      );

      final parsed = jsonDecode(json) as Map<String, dynamic>;
      final frames = parsed['frames'] as Map<String, dynamic>;
      final keys = frames.keys.toList();

      expect(keys, ['group_0', 'group_1', 'group_2', 'group_3', 'group_4']);
    });

    test('output is valid JSON', () {
      final json = generateAtlasJson(
        imageFilename: 'sprites.png',
        imageWidth: 512,
        imageHeight: 512,
        entries: [
          const AtlasEntry(
            name: 'InGame/2a_3',
            x: 100,
            y: 200,
            width: 24,
            height: 32,
            anchorX: -7,
            anchorY: -12,
          ),
        ],
      );

      // Should not throw.
      final parsed = jsonDecode(json);
      expect(parsed, isA<Map<String, dynamic>>());
    });
  });
}
