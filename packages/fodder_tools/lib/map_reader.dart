import 'dart:typed_data';

/// The expected ASCII marker at offset 0x50 in a `.map` file.
const _expectedMarker = 'cfed';

/// Maximum valid tile index (480 tiles: 240 base + 240 sub).
const _maxTileIndex = 479;

/// Bitmask for bits 9–12 of a tile uint16 (currently unused/unknown).
const _unusedBitsMask = 0x1E00;

/// Parsed header and tile data from a Cannon Fodder `.map` file.
///
/// The binary layout is:
///
/// | Offset | Size   | Content                                          |
/// |--------|--------|--------------------------------------------------|
/// | 0x00   | 11     | Base block filename (null-padded, e.g. `junbase.blk`) |
/// | 0x0B   |  5     | Gap / unknown (sometimes non-zero)               |
/// | 0x10   | 11     | Sub block filename (null-padded, e.g. `junsub0.blk`)  |
/// | 0x1B   | 53     | Gap / unknown (sometimes non-zero)               |
/// | 0x50   | 4      | Marker bytes (typically `cfed`)                   |
/// | 0x54   | 2      | Map width in tiles (big-endian uint16)            |
/// | 0x56   | 2      | Map height in tiles (big-endian uint16)           |
/// | 0x58   |  8     | Gap / unknown (sometimes non-zero)               |
/// | 0x60   | w×h×2  | Tile data — big-endian uint16 per tile            |
///
/// Each tile uint16 encodes:
///   - Bits 0–8 (`& 0x1FF`): tile graphic index (0–239 base, 240–479 sub)
///   - Bits 9–12 (`& 0x1E00`): unknown / unused (always zero in known files)
///   - Bits 13–15 (`& 0xE000`): track / music-zone data
class MapData {
  /// Creates a [MapData] by parsing the raw bytes of a `.map` file.
  ///
  /// Pass [warn] to receive diagnostic messages about unexpected data.
  factory MapData.parse(Uint8List data, {void Function(String)? warn}) {
    if (data.length < 0x62) {
      throw FormatException(
        'Map file too small: ${data.length} bytes (need >= 0x62)',
      );
    }

    final baseBlock = _readNullTerminated(data, 0x00, 11);
    final subBlock = _readNullTerminated(data, 0x10, 11);

    // Validate filenames contain only printable ASCII.
    _validateFilename(baseBlock, 'base block', warn);
    _validateFilename(subBlock, 'sub block', warn);

    // Check the marker at 0x50 — should be "cfed".
    final marker = String.fromCharCodes(data.sublist(0x50, 0x54));
    if (marker != _expectedMarker) {
      warn?.call(
        'Expected marker "$_expectedMarker" at 0x50 but got '
        '"$marker" (${data.sublist(0x50, 0x54)}).',
      );
    }

    // Report non-zero bytes in header gaps (unknown purpose).
    _checkGapBytes(data, 0x0B, 0x10, 'gap1 (0x0B–0x0F)', warn);
    _checkGapBytes(data, 0x1B, 0x50, 'gap2 (0x1B–0x4F)', warn);
    _checkGapBytes(data, 0x58, 0x60, 'gap3 (0x58–0x5F)', warn);

    final bd = ByteData.sublistView(data);
    final width = bd.getUint16(0x54);
    final height = bd.getUint16(0x56);

    if (width == 0 || height == 0) {
      throw FormatException('Map dimensions are zero: ${width}x$height');
    }

    final expectedSize = 0x60 + width * height * 2;
    if (data.length < expectedSize) {
      throw FormatException(
        'Map file too small for ${width}x$height tiles: '
        '${data.length} bytes (need >= $expectedSize)',
      );
    }

    final excess = data.length - expectedSize;
    if (excess > 0) {
      warn?.call(
        'Map file has $excess excess byte(s) after tile data '
        '(file=${data.length}, expected=$expectedSize).',
      );
    }

    var unusedBitsCount = 0;
    var oobCount = 0;
    final trackValues = <int>{};

    final tiles = List<int>.generate(width * height, (i) {
      final raw = bd.getUint16(0x60 + i * 2);

      // Check for non-zero bits 9–12 (currently unknown purpose).
      if (raw & _unusedBitsMask != 0) {
        if (unusedBitsCount == 0) {
          warn?.call(
            'Tile $i: bits 9–12 are non-zero '
            '(raw=0x${raw.toRadixString(16).padLeft(4, '0')}, '
            'bits=0x${(raw & _unusedBitsMask).toRadixString(16).padLeft(4, '0')}). '
            'Further occurrences will be summarised.',
          );
        }
        unusedBitsCount++;
      }

      // Check tile index range.
      final idx = raw & 0x1FF;
      if (idx > _maxTileIndex) {
        if (oobCount == 0) {
          warn?.call(
            'Tile $i: graphic index $idx exceeds $_maxTileIndex '
            '(raw=0x${raw.toRadixString(16).padLeft(4, '0')}).',
          );
        }
        oobCount++;
      }

      trackValues.add((raw & 0xE000) >> 13);

      return raw;
    });

    if (unusedBitsCount > 0) {
      warn?.call(
        'Total tiles with non-zero bits 9–12: '
        '$unusedBitsCount/${width * height}.',
      );
    }
    if (oobCount > 0) {
      warn?.call(
        'Total tiles with out-of-range index (>$_maxTileIndex): '
        '$oobCount/${width * height}.',
      );
    }

    warn?.call(
      'MAP ${width}x$height (${width * height} tiles), '
      'tracks=${trackValues.toList()..sort()}.',
    );

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

  /// Emits a warning if [name] contains non-printable-ASCII characters.
  static void _validateFilename(
    String name,
    String label,
    void Function(String)? warn,
  ) {
    if (name.isEmpty) {
      warn?.call('$label filename is empty.');
      return;
    }
    for (var i = 0; i < name.length; i++) {
      final c = name.codeUnitAt(i);
      if (c < 0x20 || c > 0x7E) {
        warn?.call(
          '$label filename "$name" contains non-printable character '
          '0x${c.toRadixString(16)} at position $i.',
        );
        return;
      }
    }
  }

  /// Emits a warning if any byte in the range [start]..[end) is non-zero.
  static void _checkGapBytes(
    Uint8List data,
    int start,
    int end,
    String label,
    void Function(String)? warn,
  ) {
    final hasNonZero = data.sublist(start, end).any((b) => b != 0);
    if (hasNonZero) {
      final hex = data
          .sublist(start, end)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(' ');
      warn?.call('$label has non-zero bytes: $hex');
    }
  }
}
