import 'dart:typed_data';

import 'package:test/test.dart';

// Relative import needed since tool/ packages lack pubspec.yaml.
// ignore: avoid_relative_lib_imports
import '../lib/palette.dart';

void main() {
  group('Palette', () {
    test('load reads 6-bit VGA triplets and scales to 8-bit', () {
      // 3 colors: (63, 0, 0), (0, 63, 0), (0, 0, 63)
      final data = Uint8List.fromList([
        63, 0, 0, // index 0 → red (but will be transparent)
        0, 63, 0, // index 1 → green
        0, 0, 63, // index 2 → blue
      ]);

      final palette = Palette()..load(data: data, offset: 0, count: 3);

      // Index 0 is always transparent.
      expect(palette.colors[0], 0x00000000);

      // Index 1: green (63 * 4 = 252)
      expect(palette.colors[1], 0xFF00FC00);

      // Index 2: blue
      expect(palette.colors[2], 0xFF0000FC);
    });

    test('load with startIndex writes to correct positions', () {
      final data = Uint8List.fromList([
        0, 0, 0, 0, 0, 0, // padding
        32, 16, 8, // color at offset 6
      ]);

      final palette = Palette()
        ..load(data: data, offset: 6, count: 1, startIndex: 0xA0);

      // 32 << 2 = 128, 16 << 2 = 64, 8 << 2 = 32
      expect(palette.colors[0xA0], 0xFF804020);
    });

    test('resolve4Bit returns transparent for nibble 0', () {
      // Palette() allocates a Uint32List, so it's not truly const.
      final palette = Palette();
      expect(palette.resolve4Bit(0, 0xA0), 0x00000000);
    });

    test('resolve4Bit combines nibble with base index', () {
      final data = Uint8List(256 * 3);
      // Set color at index 0xA5 (base 0xA0 | nibble 5)
      const idx = 0xA5;
      data[idx * 3] = 63; // R
      data[idx * 3 + 1] = 31; // G
      data[idx * 3 + 2] = 15; // B

      final palette = Palette()..load(data: data, offset: 0, count: 256);

      // 63<<2=252, 31<<2=124, 15<<2=60
      expect(palette.resolve4Bit(5, 0xA0), 0xFFFC7C3C);
    });

    test('resolve8Bit with zeroTransparent', () {
      final palette = Palette()
        ..load(
          data: Uint8List.fromList([10, 20, 30]),
          offset: 0,
          count: 1,
        );

      // Index 0 is opaque when zeroTransparent is false — but it's always
      // set to transparent by load().
      expect(palette.resolve8Bit(0), 0x00000000);
      expect(palette.resolve8Bit(0, zeroTransparent: true), 0x00000000);
    });
  });
}
