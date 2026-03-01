import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Writes an RGBA pixel buffer to a PNG file.
///
/// [pixels] is a [Uint32List] of ARGB values (0xAARRGGBB format as used by
/// `Palette`).
/// [width] and [height] define the image dimensions.
///
/// Returns the encoded PNG bytes.
Uint8List encodePng({
  required Uint32List pixels,
  required int width,
  required int height,
}) {
  final image = img.Image(width: width, height: height, numChannels: 4);

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final argb = pixels[y * width + x];
      final a = (argb >> 24) & 0xFF;
      final r = (argb >> 16) & 0xFF;
      final g = (argb >> 8) & 0xFF;
      final b = argb & 0xFF;
      image.setPixelRgba(x, y, r, g, b, a);
    }
  }

  return Uint8List.fromList(img.encodePng(image));
}
