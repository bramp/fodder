import 'dart:typed_data';

/// A sequential reader over a [Uint8List] that provides byte-level and
/// big-endian 16-bit word access for the LZSS/Huffman bitstream.
///
/// This class handles the low-level byte consumption. Bit-level extraction
/// is intentionally left to the caller because the decompressor's two
/// bit-reading sites have subtly different reload timing that must remain
/// inline (see `_decodeSymbol` vs `_readDistance`).
class BitReader {
  /// Creates a reader starting at byte offset [start] in [data].
  BitReader(this.data, {this.start = 0}) : _pos = start;

  /// The backing byte buffer.
  final Uint8List data;

  /// The initial read offset (used for documentation/debugging).
  final int start;

  int _pos;

  /// Number of unread bits remaining in [word]. When zero, the next
  /// bit-reading operation should call [readWord] to reload.
  int bitsRemaining = 0;

  /// The current 16-bit word being consumed (MSB-first).
  int word = 0;

  /// Reads the next byte, returning `0` past the end of [data].
  int readByte() {
    if (_pos >= data.length) return 0;
    return data[_pos++];
  }

  /// Reads a big-endian 16-bit word (high byte first) and stores it
  /// in [word].
  int readWord() {
    return word = (readByte() << 8) | readByte();
  }

  /// Reads a little-endian unsigned 16-bit value from two consecutive bytes.
  int readUint16LE() => readByte() | (readByte() << 8);

  /// Reads a little-endian unsigned 32-bit value from two uint16 LE words.
  int readUint32LE() {
    final lo = readUint16LE();
    final hi = readUint16LE();
    return lo | (hi << 16);
  }
}
