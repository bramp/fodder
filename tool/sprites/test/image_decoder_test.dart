import 'dart:typed_data';

import 'package:test/test.dart';

// Relative imports: tool/ packages lack pubspec.yaml.
// ignore: avoid_relative_lib_imports
import '../lib/image_decoder.dart';
// Relative imports: tool/ packages lack pubspec.yaml.
// ignore: avoid_relative_lib_imports
import '../lib/palette.dart';

void main() {
  /// Creates a palette with one non-transparent color at the given index.
  Palette paletteWith(int index, {int r = 63, int g = 63, int b = 63}) {
    final data = Uint8List(256 * 3);
    data[index * 3] = r;
    data[index * 3 + 1] = g;
    data[index * 3 + 2] = b;

    return Palette()..load(data: data, offset: 0, count: 256);
  }

  group('decode4Bit', () {
    test('decodes a 2x2 pixel block from one byte', () {
      // One byte at pitch=1 → 2 pixels wide, 1 row tall.
      // Byte 0x35 → left nibble 3, right nibble 5.
      final data = Uint8List.fromList([0x35]);

      // Set colors at indices 0xA3 and 0xA5.
      final palData = Uint8List(256 * 3);
      palData[0xA3 * 3] = 10;
      palData[0xA3 * 3 + 1] = 20;
      palData[0xA3 * 3 + 2] = 30;
      palData[0xA5 * 3] = 40;
      palData[0xA5 * 3 + 1] = 50;
      palData[0xA5 * 3 + 2] = 60;
      final palette = Palette()..load(data: palData, offset: 0, count: 256);

      final pixels = decode4Bit(
        data: data,
        palette: palette,
        basePaletteIndex: 0xA0,
        pitch: 1,
      );

      expect(pixels.length, 2); // 1 byte → 2 pixels
      // 10<<2=40, 20<<2=80, 30<<2=120
      expect(pixels[0], 0xFF285078);
      // 40<<2=160, 50<<2=200, 60<<2=240
      expect(pixels[1], 0xFFA0C8F0);
    });

    test('transparent nibble produces 0x00000000', () {
      // Byte 0x05 → left nibble 0 (transparent), right nibble 5.
      final data = Uint8List.fromList([0x05]);
      final palette = paletteWith(0xA5);

      final pixels = decode4Bit(
        data: data,
        palette: palette,
        basePaletteIndex: 0xA0,
        pitch: 1,
      );

      expect(pixels[0], 0x00000000); // transparent
      expect(pixels[1], isNot(0x00000000)); // opaque
    });

    test('respects paletteOffset to limit image height', () {
      // 4 bytes of data, palette offset at byte 2 → only 2 rows at pitch=1.
      final data = Uint8List.fromList([0x11, 0x22, 0xFF, 0xFF]);
      final palette = paletteWith(0xA1);

      final pixels = decode4Bit(
        data: data,
        palette: palette,
        basePaletteIndex: 0xA0,
        pitch: 1,
        paletteOffset: 2,
      );

      // 2 rows × 2 pixels = 4 pixels.
      expect(pixels.length, 4);
    });
  });

  group('decode8Bit', () {
    test('decodes bytes directly as palette indices', () {
      final palette = paletteWith(42, r: 10, g: 20, b: 30);
      final data = Uint8List.fromList([42, 0, 42]);

      final pixels = decode8Bit(
        data: data,
        palette: palette,
        width: 3,
      );

      expect(pixels.length, 3);
      expect(pixels[0], 0xFF285078); // color 42
      expect(pixels[1], 0x00000000); // index 0 is transparent (from palette)
      expect(pixels[2], 0xFF285078); // color 42 again
    });
  });

  group('decodePlanar', () {
    test('de-interleaves 4 planes correctly', () {
      // Tiny test: 4 pixels wide × 1 row = 4 bytes.
      // Plane 0: pixel at x=0
      // Plane 1: pixel at x=1
      // Plane 2: pixel at x=2
      // Plane 3: pixel at x=3
      final palData = Uint8List(256 * 3);
      for (var i = 1; i <= 4; i++) {
        palData[i * 3] = i * 10; // R
      }
      final palette = Palette()..load(data: palData, offset: 0, count: 256);

      // 4 planes × 1 row × 1 pixel per row = 4 bytes total.
      final data = Uint8List.fromList([1, 2, 3, 4]);

      final pixels = decodePlanar(
        data: data,
        palette: palette,
        width: 4,
        height: 1,
      );

      expect(pixels.length, 4);
      // Pixel at x=0 comes from plane 0 → index 1
      expect(pixels[0], palette.colors[1]);
      // Pixel at x=1 comes from plane 1 → index 2
      expect(pixels[1], palette.colors[2]);
      // Pixel at x=2 comes from plane 2 → index 3
      expect(pixels[2], palette.colors[3]);
      // Pixel at x=3 comes from plane 3 → index 4
      expect(pixels[3], palette.colors[4]);
    });
  });

  group('decodeTile', () {
    test('extracts 16x16 tile from canvas', () {
      // Canvas: 32 pixels wide (2 tiles across), 16 rows.
      // Fill data so tile 0 and tile 1 have distinct patterns.
      final data = Uint8List(32 * 16);
      for (var y = 0; y < 16; y++) {
        for (var x = 0; x < 16; x++) {
          data[y * 32 + x] = 1; // tile 0: index 1
          data[y * 32 + x + 16] = 2; // tile 1: index 2
        }
      }

      final palette = Palette()
        ..load(
          data: Uint8List(256 * 3)
            ..[1 * 3] =
                63 // index 1 = red
            ..[2 * 3 + 1] = 63, // index 2 = green
          offset: 0,
          count: 256,
        );

      // Extract tile 0.
      final tile0 = decodeTile(
        data: data,
        palette: palette,
        tileIndex: 0,
        canvasWidth: 32,
      );
      expect(tile0.length, 256); // 16×16
      expect(tile0[0], palette.colors[1]); // red-ish

      // Extract tile 1.
      final tile1 = decodeTile(
        data: data,
        palette: palette,
        tileIndex: 1,
        canvasWidth: 32,
      );
      expect(tile1[0], palette.colors[2]); // green-ish
    });
  });
}
