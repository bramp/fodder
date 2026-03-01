import 'dart:io';
import 'dart:typed_data';

// ignore: always_use_package_imports // CLI tool
import 'decompressor.dart';

/// A single file entry within a Cannon Fodder `.DAT` archive.
///
/// Each entry records the file's name, its byte offset within the archive,
/// and its compressed size.
class ArchiveEntry {
  /// Creates an archive entry.
  const ArchiveEntry({
    required this.filename,
    required this.addressStart,
    required this.size,
  });

  /// The lowercase filename (e.g. `army.dat`, `int26.voc`).
  final String filename;

  /// Absolute byte offset in the `.DAT` file where this entry's compressed
  /// data begins.
  final int addressStart;

  /// Compressed size of the entry in bytes.
  final int size;

  @override
  String toString() =>
      'ArchiveEntry($filename, start: 0x${addressStart.toRadixString(16)}, '
      'size: $size)';
}

/// Reads the Cannon Fodder PC CD archive format (CF_ENG.DAT / FODDER.DAT).
///
/// The archive consists of a header dictionary followed by compressed file
/// payloads. The header layout is:
///
/// ```text
/// Offset  Size  Description
/// ------  ----  -----------
/// 0x00    2     End-of-dictionary offset (uint16 LE)
/// 0x02    2     Unused / padding
/// 0x04    …     Dictionary entries (repeated until end-of-dictionary offset):
///                 uint8          filename length
///                 char[length]   filename bytes
///                 uint32 LE      absolute offset of compressed payload
///                 uint32 LE      compressed payload size
/// ```
///
/// ## Usage
///
/// ```dart
/// final reader = DatReader(File('CF_ENG.DAT'));
/// reader.read();
///
/// for (final entry in reader.entries) {
///   final bytes = reader.getFileBytes(entry);
///   File(entry.filename).writeAsBytesSync(bytes);
/// }
/// ```
class DatReader {
  /// Creates a reader for the given archive [file].
  DatReader(this.file);

  /// The `.DAT` archive file to read.
  final File file;

  /// Raw archive bytes, populated by [read].
  late final Uint8List _data;

  /// The parsed file entries from the archive header.
  final List<ArchiveEntry> entries = [];

  /// Reads the archive file and parses its header into [entries].
  void read() {
    _data = file.readAsBytesSync();
    _parseHeader();
  }

  /// Decompresses and returns the file contents for the given [entry].
  ///
  /// The decompressor is given a view from the entry's start offset through
  /// the end of the archive. This matches the original game's `data_Read()`
  /// which reads in 0xA00-byte blocks without bounds-checking against the
  /// entry's stated size — the bitstream may slightly overrun into the next
  /// entry's data before the decompressor terminates.
  Uint8List getFileBytes(ArchiveEntry entry) {
    final compressedData = Uint8List.sublistView(_data, entry.addressStart);
    return Decompressor(compressedData).decompress();
  }

  /// Parses the archive header to populate [entries].
  void _parseHeader() {
    final byteData = ByteData.sublistView(_data);

    // The first uint16 LE is the byte offset marking the end of the
    // dictionary section. Entries are read from offset 4 up to this point.
    final dictionaryEnd = byteData.getUint16(0, Endian.little);

    var cursor = 4; // skip the 2-byte pointer and 2 bytes of padding
    while (cursor < dictionaryEnd) {
      // Read length-prefixed filename.
      final nameLength = byteData.getUint8(cursor);
      cursor++;

      final nameBytes = <int>[];
      for (var i = 0; i < nameLength; i++) {
        nameBytes.add(byteData.getUint8(cursor + i));
      }
      cursor += nameLength;

      final filename = String.fromCharCodes(nameBytes).toLowerCase();

      // Read the compressed payload location.
      final addressStart = byteData.getUint32(cursor, Endian.little);
      cursor += 4;

      final size = byteData.getUint32(cursor, Endian.little);
      cursor += 4;

      entries.add(
        ArchiveEntry(
          filename: filename,
          addressStart: addressStart,
          size: size,
        ),
      );
    }
  }
}
