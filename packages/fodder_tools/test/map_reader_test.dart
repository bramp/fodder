import 'dart:typed_data';

import 'package:fodder_tools/map_reader.dart';
import 'package:test/test.dart';

void main() {
  group('MapData.parse', () {
    /// Builds a minimal valid .map file for testing.
    Uint8List buildMapBytes({
      String baseBlock = 'junbase.blk',
      String subBlock = 'junsub0.blk',
      int width = 2,
      int height = 2,
      List<int>? tiles,
    }) {
      final tileData = tiles ?? List.filled(width * height, 0);
      final data = Uint8List(0x60 + tileData.length * 2);
      final bd = ByteData.sublistView(data);

      // Base block filename at 0x00 (null-padded).
      for (var i = 0; i < baseBlock.length && i < 11; i++) {
        data[i] = baseBlock.codeUnitAt(i);
      }
      // Sub block filename at 0x10 (null-padded).
      for (var i = 0; i < subBlock.length && i < 11; i++) {
        data[0x10 + i] = subBlock.codeUnitAt(i);
      }

      // Marker "cfed" at 0x50.
      data[0x50] = 0x63; // 'c'
      data[0x51] = 0x66; // 'f'
      data[0x52] = 0x65; // 'e'
      data[0x53] = 0x64; // 'd'

      // Width and height (big-endian uint16) at 0x54 and 0x56.
      bd.setUint16(0x54, width, Endian.big);
      bd.setUint16(0x56, height, Endian.big);

      // Tile data (big-endian uint16) starting at 0x60.
      for (var i = 0; i < tileData.length; i++) {
        bd.setUint16(0x60 + i * 2, tileData[i], Endian.big);
      }

      return data;
    }

    test('reads header filenames', () {
      final data = buildMapBytes();
      final map = MapData.parse(data);
      expect(map.baseBlockFilename, 'junbase.blk');
      expect(map.subBlockFilename, 'junsub0.blk');
    });

    test('reads map dimensions', () {
      final data = buildMapBytes(width: 19, height: 15);
      final map = MapData.parse(data);
      expect(map.width, 19);
      expect(map.height, 15);
    });

    test('reads tile data', () {
      final tiles = [0x0003, 0x00F1, 0x2005, 0x0000];
      final data = buildMapBytes(tiles: tiles);
      final map = MapData.parse(data);
      expect(map.rawTiles, tiles);
    });

    test('extracts tile graphic index (lower 9 bits)', () {
      expect(MapData.tileIndex(0x01FF), 0x1FF);
      expect(MapData.tileIndex(0xE0FF), 0xFF);
      expect(MapData.tileIndex(0x00F0), 0xF0);
      expect(MapData.tileIndex(0x0000), 0);
    });

    test('extracts track/zone data (upper 3 bits)', () {
      expect(MapData.tileTrack(0x0000), 0);
      expect(MapData.tileTrack(0x2000), 1);
      expect(MapData.tileTrack(0x4000), 2);
      expect(MapData.tileTrack(0xE000), 7);
      expect(MapData.tileTrack(0xE1FF), 7);
    });

    test('terrainPrefix returns first 3 chars of base block', () {
      final data = buildMapBytes(baseBlock: 'desbase.blk');
      final map = MapData.parse(data);
      expect(map.terrainPrefix, 'des');
    });

    test('throws on file too small for header', () {
      expect(
        () => MapData.parse(Uint8List(0x10)),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws on file too small for tile data', () {
      // Header says 10x10 tiles but only provide header bytes.
      final data = buildMapBytes(width: 10, height: 10);
      final truncated = Uint8List.sublistView(data, 0, 0x62);
      expect(() => MapData.parse(truncated), throwsA(isA<FormatException>()));
    });

    test('throws on zero dimensions', () {
      final data = buildMapBytes(width: 0, height: 5);
      expect(() => MapData.parse(data), throwsA(isA<FormatException>()));
    });

    test('warns on bad marker', () {
      final data = buildMapBytes();
      // Overwrite marker at 0x50 with "XXXX".
      data[0x50] = 0x58;
      data[0x51] = 0x58;
      data[0x52] = 0x58;
      data[0x53] = 0x58;
      final warnings = <String>[];
      MapData.parse(data, warn: warnings.add);
      expect(warnings, contains(contains('marker')));
    });

    test('warns on excess bytes', () {
      final data = buildMapBytes();
      // Append extra bytes.
      final padded = Uint8List(data.length + 10)..setAll(0, data);
      // Need to keep the marker valid.
      padded[0x50] = 0x63;
      padded[0x51] = 0x66;
      padded[0x52] = 0x65;
      padded[0x53] = 0x64;
      final warnings = <String>[];
      MapData.parse(padded, warn: warnings.add);
      expect(warnings, contains(contains('excess')));
    });

    test('warns on non-zero gap bytes', () {
      final data = buildMapBytes();
      // Set a byte in gap1 (0x0B–0x0F) to non-zero.
      data[0x0C] = 0x42;
      final warnings = <String>[];
      MapData.parse(data, warn: warnings.add);
      expect(warnings, contains(contains('gap1')));
    });

    test('warns on out-of-range tile index', () {
      // Tile index 480 (> 479) in bits 0–8.
      final tiles = [0x01E0]; // 0x01E0 = 480
      final data = buildMapBytes(width: 1, height: 1, tiles: tiles);
      final warnings = <String>[];
      MapData.parse(data, warn: warnings.add);
      expect(warnings, contains(contains('out-of-range')));
    });

    test('emits summary line', () {
      final data = buildMapBytes();
      final warnings = <String>[];
      MapData.parse(data, warn: warnings.add);
      expect(warnings, contains(contains('MAP 2x2')));
    });
  });
}
