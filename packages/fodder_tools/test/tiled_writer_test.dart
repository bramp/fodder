import 'dart:typed_data';

import 'package:fodder_tools/map_reader.dart';
import 'package:fodder_tools/tiled_writer.dart';
import 'package:fodder_tools/tileset_builder.dart';
import 'package:test/test.dart';

void main() {
  group('generateTsx', () {
    test('produces valid XML with correct attributes', () {
      final tsx = generateTsx(
        name: 'jungle',
        imageFilename: 'jungle.png',
        imageWidth: 320,
        imageHeight: 384,
      );
      expect(tsx, contains('<?xml version="1.0"'));
      expect(tsx, contains('name="jungle"'));
      expect(tsx, contains('tilewidth="$tileSize"'));
      expect(tsx, contains('tileheight="$tileSize"'));
      expect(tsx, contains('tilecount="$totalTileCount"'));
      expect(tsx, contains('columns="$blkColumns"'));
      expect(tsx, contains('source="jungle.png"'));
      expect(tsx, contains('width="320"'));
      expect(tsx, contains('height="384"'));
    });
  });

  group('generateTmx', () {
    late MapData map;

    setUp(() {
      // Build a small 3×2 map.
      map = MapData.parse(
        _buildMapBytes(width: 3, height: 2, tiles: [1, 2, 3, 240, 241, 0xE005]),
      );
    });

    test('produces valid XML with correct map dimensions', () {
      final tmx = generateTmx(map: map, tilesetTsxFilename: 'jungle.tsx');
      expect(tmx, contains('<?xml version="1.0"'));
      expect(tmx, contains('orientation="orthogonal"'));
      expect(tmx, contains('width="3" height="2"'));
      expect(tmx, contains('source="jungle.tsx"'));
    });

    test('tile GIDs are 1-based (tile index + 1)', () {
      final tmx = generateTmx(map: map, tilesetTsxFilename: 'test.tsx');

      // First row: tile indices 1, 2, 3 → GIDs 2, 3, 4.
      expect(tmx, contains('2,3,4,'));
      // Second row: tile 240 → GID 241, tile 241 → GID 242,
      // tile 0xE005 → index 5 → GID 6.
      expect(tmx, contains('241,242,6'));
    });

    test('track layer encodes upper 3 bits', () {
      final tmx = generateTmx(map: map, tilesetTsxFilename: 'test.tsx');

      // Tiles 1, 2, 3, 240, 241 have track = 0.
      // Tile 0xE005 has track = 7 (0xE000 >> 13).
      // The track layer should contain a "7" for the last tile.
      final trackLayerStart = tmx.indexOf('name="Track"');
      expect(trackLayerStart, isPositive);

      // Extract the CSV data from the Track layer.
      final dataStart = tmx.indexOf('<data encoding="csv">', trackLayerStart);
      final dataEnd = tmx.indexOf('</data>', dataStart);
      final csvBlock = tmx.substring(dataStart, dataEnd);
      expect(csvBlock, contains('0,0,7'));
    });
  });
}

/// Builds a minimal valid .map file for testing.
///
/// Shared with [map_reader_test.dart]; duplicated here to keep tests
/// self-contained.
// ignore: prefer_expression_function_bodies
Uint8List _buildMapBytes({
  String baseBlock = 'junbase.blk',
  String subBlock = 'junsub0.blk',
  int width = 2,
  int height = 2,
  List<int>? tiles,
}) {
  final tileData = tiles ?? List.filled(width * height, 0);
  final data = Uint8List(0x60 + tileData.length * 2);
  final bd = ByteData.sublistView(data);

  for (var i = 0; i < baseBlock.length && i < 11; i++) {
    data[i] = baseBlock.codeUnitAt(i);
  }
  for (var i = 0; i < subBlock.length && i < 11; i++) {
    data[0x10 + i] = subBlock.codeUnitAt(i);
  }

  bd.setUint16(0x54, width, Endian.big);
  bd.setUint16(0x56, height, Endian.big);

  for (var i = 0; i < tileData.length; i++) {
    bd.setUint16(0x60 + i * 2, tileData[i], Endian.big);
  }

  return data;
}
