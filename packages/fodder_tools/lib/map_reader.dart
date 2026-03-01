import 'dart:typed_data';

/// Parsed header and tile data from a Cannon Fodder `.map` file.
///
/// The binary layout is:
///
/// | Offset | Size   | Content                                          |
/// |--------|--------|--------------------------------------------------|
/// | 0x00   | 11     | Base block filename (null-padded, e.g. `junbase.blk`) |
/// | 0x10   | 11     | Sub block filename (null-padded, e.g. `junsub0.blk`)  |
/// | 0x50   | 4      | Marker bytes (typically `cfed`)                   |
/// | 0x54   | 2      | Map width in tiles (big-endian uint16)            |
/// | 0x56   | 2      | Map height in tiles (big-endian uint16)           |
/// | 0x60   | w×h×2  | Tile data — big-endian uint16 per tile            |
///
/// Each tile uint16 encodes:
///   - Bits 0–8 (`& 0x1FF`): tile graphic index (0–239 base, 240–479 sub)
///   - Bits 13–15 (`& 0xE000`): track / music-zone data
class MapData {
  /// Creates a [MapData] by parsing the raw bytes of a `.map` file.
  factory MapData.parse(Uint8List data) {
    if (data.length < 0x62) {
      throw FormatException(
        'Map file too small: ${data.length} bytes (need >= 0x62)',
      );
    }

    final baseBlock = _readNullTerminated(data, 0x00, 11);
    final subBlock = _readNullTerminated(data, 0x10, 11);

    final bd = ByteData.sublistView(data);
    final width = bd.getUint16(0x54, Endian.big);
    final height = bd.getUint16(0x56, Endian.big);

    final expectedSize = 0x60 + width * height * 2;
    if (data.length < expectedSize) {
      throw FormatException(
        'Map file too small for ${width}x$height tiles: '
        '${data.length} bytes (need >= $expectedSize)',
      );
    }

    final tiles = List<int>.generate(width * height, (i) {
      return bd.getUint16(0x60 + i * 2, Endian.big);
    });

    return MapData._(
      baseBlockFilename: baseBlock,
      subBlockFilename: subBlock,
      width: width,
      height: height,
      rawTiles: tiles,
    );
  }

  MapData._({
    required this.baseBlockFilename,
    required this.subBlockFilename,
    required this.width,
    required this.height,
    required this.rawTiles,
  });

  /// Base tile block filename (e.g. `junbase.blk`).
  final String baseBlockFilename;

  /// Sub tile block filename (e.g. `junsub0.blk`).
  final String subBlockFilename;

  /// Map width in tiles.
  final int width;

  /// Map height in tiles.
  final int height;

  /// Raw tile values (big-endian uint16 from the file, one per cell).
  ///
  /// Use [tileIndex] to extract the graphic index and [tileTrack] for the
  /// track/music zone.
  final List<int> rawTiles;

  /// The terrain prefix (first 3 characters of the base block filename).
  ///
  /// e.g. `jun`, `des`, `ice`, `mor`, `int`.
  String get terrainPrefix => baseBlockFilename.substring(0, 3);

  /// Returns the graphic tile index for cell [i] (0–479).
  static int tileIndex(int raw) => raw & 0x1FF;

  /// Returns the track/music zone data for cell [i].
  static int tileTrack(int raw) => (raw & 0xE000) >> 13;

  /// Reads a null-terminated (or fixed-length) ASCII string from [data].
  static String _readNullTerminated(Uint8List data, int offset, int maxLen) {
    final end = offset + maxLen;
    final buf = StringBuffer();
    for (var i = offset; i < end; i++) {
      final c = data[i];
      if (c == 0) break;
      buf.writeCharCode(c);
    }
    return buf.toString();
  }
}
