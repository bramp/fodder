import 'dart:typed_data';

import 'package:fodder_tools/bht_reader.dart';
import 'package:test/test.dart';

void main() {
  group('readBhtFile', () {
    test('parses file with correct number of tiles', () {
      // 3 tiles × 8 bytes = 24 bytes. Fill tile 0 with 0xAA, tile 1 with
      // 0xBB, tile 2 with 0xCC (for easy identification).
      final data = Uint8List(24);
      for (var i = 0; i < 8; i++) {
        data[i] = 0xAA;
      }
      for (var i = 8; i < 16; i++) {
        data[i] = 0xBB;
      }
      for (var i = 16; i < 24; i++) {
        data[i] = 0xCC;
      }

      final masks = readBhtFile(data, tileCount: 3);

      expect(masks.length, 3);
      expect(masks[0], everyElement(0xAA));
      expect(masks[1], everyElement(0xBB));
      expect(masks[2], everyElement(0xCC));
    });

    test('pads with zeros when tileCount exceeds file data', () {
      // 2 tiles in file, request 4.
      final data = Uint8List(16);
      for (var i = 0; i < 16; i++) {
        data[i] = 0xFF;
      }

      final warnings = <String>[];
      final masks = readBhtFile(data, tileCount: 4, warn: warnings.add);

      expect(masks.length, 4);
      expect(masks[0], everyElement(0xFF));
      expect(masks[1], everyElement(0xFF));
      // Padded tiles are all-zero.
      expect(masks[2], everyElement(0));
      expect(masks[3], everyElement(0));
      expect(warnings, contains(contains('2 tiles but 4 were requested')));
    });

    test('handles empty file', () {
      final warnings = <String>[];
      final masks = readBhtFile(Uint8List(0), tileCount: 2, warn: warnings.add);

      expect(masks.length, 2);
      expect(masks[0], everyElement(0));
      expect(masks[1], everyElement(0));
      expect(warnings, contains(contains('0 tiles but 2 were requested')));
    });

    test('warns on unexpected file size', () {
      // Not a standard base (1920) or sub (1280) size.
      final warnings = <String>[];
      readBhtFile(Uint8List(100), tileCount: 10, warn: warnings.add);

      expect(warnings, contains(contains('is unexpected')));
    });

    test('warns on non-multiple-of-8 file size', () {
      final warnings = <String>[];
      readBhtFile(Uint8List(13), tileCount: 1, warn: warnings.add);

      expect(warnings, contains(contains('not a multiple of')));
    });

    test('accepts standard base size without unexpected-size warning', () {
      final warnings = <String>[];
      readBhtFile(Uint8List(1920), tileCount: 240, warn: warnings.add);

      expect(warnings.where((w) => w.contains('is unexpected')), isEmpty);
    });

    test('accepts standard sub size without unexpected-size warning', () {
      final warnings = <String>[];
      readBhtFile(Uint8List(1280), tileCount: 160, warn: warnings.add);

      expect(warnings.where((w) => w.contains('is unexpected')), isEmpty);
    });
  });

  group('buildCombinedBhtMasks', () {
    test('produces 480 entries from base + sub data', () {
      final base = Uint8List(1920); // 240 tiles
      final sub = Uint8List(1280); // 160 tiles (padded to 240)

      final masks = buildCombinedBhtMasks(baseBhtData: base, subBhtData: sub);

      expect(masks.length, 480);
    });

    test('base tile data appears in first 240 entries', () {
      // Fill base tile 0 with 0x42.
      final base = Uint8List(1920);
      for (var i = 0; i < 8; i++) {
        base[i] = 0x42;
      }
      final sub = Uint8List(1280);

      final masks = buildCombinedBhtMasks(baseBhtData: base, subBhtData: sub);

      expect(masks[0], everyElement(0x42));
      expect(masks[239], everyElement(0)); // last base tile: zeros
    });

    test('sub tile data appears at index 240+', () {
      final base = Uint8List(1920);
      // Fill sub tile 0 (index 240 in combined) with 0xBB.
      final sub = Uint8List(1280);
      for (var i = 0; i < 8; i++) {
        sub[i] = 0xBB;
      }

      final masks = buildCombinedBhtMasks(baseBhtData: base, subBhtData: sub);

      expect(masks[240], everyElement(0xBB));
    });

    test('prefixes warn messages with base/sub', () {
      final warnings = <String>[];
      buildCombinedBhtMasks(
        baseBhtData: Uint8List(100), // unusual size
        subBhtData: Uint8List(50), // unusual size
        warn: warnings.add,
      );

      expect(warnings.where((w) => w.startsWith('base:')), isNotEmpty);
      expect(warnings.where((w) => w.startsWith('sub:')), isNotEmpty);
    });
  });
}
