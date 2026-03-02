import 'dart:typed_data';

import 'package:fodder_tools/hit_reader.dart';
import 'package:test/test.dart';

void main() {
  group('readHitFile', () {
    test('parses big-endian int16 values', () {
      // 4 entries: 0, 3, 6, 0x8070 (negative mixed terrain)
      final data = Uint8List.fromList([
        0x00, 0x00, // 0 = Land
        0x00, 0x03, // 3 = Block
        0x00, 0x06, // 6 = Water
        0x80, 0x70, // negative (mixed terrain) = -32656 signed
      ]);

      final result = readHitFile(data, tileCount: 4);
      // Raw int16 values are preserved (negative values are NOT mapped to -1).
      expect(result, [0, 3, 6, -32656]);
    });

    test('pads with 0 when tileCount exceeds entries', () {
      final data = Uint8List.fromList([
        0x00, 0x03, // 3 = Block
      ]);

      final result = readHitFile(data, tileCount: 3);
      expect(result, [3, 0, 0]);
    });

    test('empty data returns all zeros', () {
      final result = readHitFile(Uint8List(0), tileCount: 5);
      expect(result, [0, 0, 0, 0, 0]);
    });

    test('warns on odd byte count', () {
      final data = Uint8List.fromList([0x00, 0x03, 0xFF]); // 3 bytes
      final warnings = <String>[];
      readHitFile(data, tileCount: 1, warn: warnings.add);
      expect(warnings, contains(contains('odd byte count')));
    });

    test('warns on unexpected file size', () {
      // 10 bytes — not 480 (base) or 320 (sub).
      final data = Uint8List(10);
      final warnings = <String>[];
      readHitFile(data, tileCount: 5, warn: warnings.add);
      expect(warnings, contains(contains('unexpected')));
    });

    test('warns when tileCount exceeds entries', () {
      final data = Uint8List.fromList([0x00, 0x03]);
      final warnings = <String>[];
      readHitFile(data, tileCount: 3, warn: warnings.add);
      expect(warnings, contains(contains('default to Land')));
    });

    test('warns on mixed-terrain nibble out of range', () {
      // 0x80FF → primary = 0x0F (15 > 14), secondary = 0x0F
      final data = Uint8List.fromList([0x80, 0xFF]);
      final warnings = <String>[];
      readHitFile(data, tileCount: 1, warn: warnings.add);
      expect(warnings, contains(contains('nibble outside')));
    });

    test('warns on positive value with primary nibble out of range', () {
      // 0x001F → raw=31, primary = 31 & 0x0F = 15 > 14
      final data = Uint8List.fromList([0x00, 0x1F]);
      final warnings = <String>[];
      readHitFile(data, tileCount: 1, warn: warnings.add);
      expect(warnings, contains(contains('primary nibble')));
    });

    test('emits summary line', () {
      final data = Uint8List.fromList([
        0x00, 0x00, // simple (0)
        0x00, 0x33, // positive with upper bits (0x33 = 51 > 14)
        0x80, 0x63, // negative / mixed
      ]);
      final warnings = <String>[];
      readHitFile(data, tileCount: 3, warn: warnings.add);
      expect(
        warnings,
        contains(allOf(contains('1 mixed-terrain'), contains('1 positive'))),
      );
    });
  });

  group('buildCombinedTerrainTypes', () {
    test('combines base and sub terrain data to 480 entries', () {
      // Minimal base: 1 entry of type 3.
      final baseData = Uint8List.fromList([0x00, 0x03]);
      // Minimal sub: 1 entry of type 6.
      final subData = Uint8List.fromList([0x00, 0x06]);

      final result = buildCombinedTerrainTypes(
        baseHitData: baseData,
        subHitData: subData,
      );

      expect(result.length, 480);
      expect(result[0], 3); // first base tile
      expect(result[1], 0); // padded
      expect(result[240], 6); // first sub tile
      expect(result[241], 0); // padded
    });

    test('prefixes warnings with base/sub label', () {
      final baseData = Uint8List(10); // unexpected size
      final subData = Uint8List(10);
      final warnings = <String>[];

      buildCombinedTerrainTypes(
        baseHitData: baseData,
        subHitData: subData,
        warn: warnings.add,
      );

      expect(warnings, contains(startsWith('base:')));
      expect(warnings, contains(startsWith('sub:')));
    });
  });
}
