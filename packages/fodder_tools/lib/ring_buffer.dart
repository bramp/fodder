import 'dart:typed_data';

/// A fixed-size circular byte buffer used for LZSS sliding-window
/// back-references.
///
/// Bytes are written sequentially via [writeByte]. Back-references are
/// resolved via [copyFrom], which copies `length` bytes starting at
/// `distance` positions behind the current write cursor, wrapping around
/// the buffer as needed.
///
/// The buffer is pre-filled with spaces (0x20) to match the original
/// Cannon Fodder decompressor's initialisation. This fill value matters
/// because early back-references can reach into the pre-filled region.
class RingBuffer {
  /// Creates a ring buffer of [size] bytes, pre-filled with `0x20` up to
  /// [initialPosition], with the write cursor at [initialPosition].
  RingBuffer({this.size = 1024, int initialPosition = 0, int fillByte = 0x00})
    : assert(size > 0 && (size & (size - 1)) == 0, 'size must be a power of 2'),
      _mask = size - 1,
      _data = Uint8List(size),
      _pos = initialPosition {
    _data.fillRange(0, initialPosition, fillByte);
  }

  /// Buffer size (must be a power of 2).
  final int size;
  final int _mask;
  final Uint8List _data;

  /// Current write position.
  int _pos;

  /// Writes a single [byte] at the current position and advances the cursor.
  void writeByte(int byte) {
    _data[_pos] = byte;
    _pos = (_pos + 1) & _mask;
  }

  /// Copies [length] bytes from [distance] positions behind the write cursor
  /// into [output], also writing each byte back into the ring buffer.
  ///
  /// This must write-then-advance for each byte (not batch-copy), because
  /// the source and destination regions can overlap when distance < length
  /// (used to repeat short patterns).
  void copyFrom(int distance, int length, List<int> output) {
    var src = (_pos - distance - 1) & _mask;
    for (var i = 0; i < length; i++) {
      final byte = _data[src];
      output.add(byte);
      _data[_pos] = byte;
      _pos = (_pos + 1) & _mask;
      src = (src + 1) & _mask;
    }
  }
}
