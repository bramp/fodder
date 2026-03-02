import 'dart:typed_data';

import 'package:fodder_tools/hit_reader.dart';
import 'package:test/test.dart';

void main() {
  group('readHitFile', () {
    test('parses big-endian int16 values', () {
      // 4 entries: 0, 3, 6, -1 (0xFFFF)
      final data = Uint8List.fromList([
        0x00, 0x00, // 0 = Land
        0x00, 0x03, // 3 = Block
        0x00, 0x06, // 6 = Water
        0x80, 0x70, // negative (mixed terrain)
      ]);

      final result = readHitFile(data, tileCount: 4);
      expect(result, [0, 3, 6, -1]);
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
  });
}
