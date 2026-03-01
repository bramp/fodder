import 'dart:typed_data';
// ignore: always_use_package_imports // CLI tool
import 'bit_reader.dart';
// ignore: always_use_package_imports // CLI tool
import 'ring_buffer.dart';

/// Decompresses data compressed with the Adaptive Huffman + LZSS algorithm
/// used by the PC CD version of Cannon Fodder (CF_ENG.DAT / FODDER.DAT).
///
/// The compression scheme combines two techniques:
///
/// 1. **Adaptive Huffman coding** – A dynamic Huffman tree that updates after
///    each decoded symbol, providing statistical compression.
/// 2. **LZSS (Lempel-Ziv-Storer-Szymanski)** – A sliding-window dictionary
///    scheme using a 4096-byte ring buffer for back-reference matching.
///
/// The symbol alphabet has 314 entries:
///   - Symbols 0x000–0x0FF (0–255): literal bytes.
///   - Symbols 0x100–0x139 (256–313): LZSS match-length codes.
///     The match length is `symbol - 256 + 3` (range 3–60).
///
/// When a match-length symbol is decoded, a variable-length distance value is
/// read from the bitstream to locate the source bytes in the ring buffer.
///
/// ## Compressed data layout
///
/// ```text
/// Offset  Size  Description
/// ------  ----  -----------
/// 0x00    2     Decompressed size, low word  (uint16 LE)
/// 0x02    2     Decompressed size, high word (uint16 LE)
/// 0x04    …     Compressed bitstream (big-endian 16-bit words)
/// ```
///
/// ## Usage
///
/// ```dart
/// final decompressor = Decompressor(compressedBytes);
/// final output = decompressor.decompress();
/// ```
class Decompressor {
  /// Creates a decompressor for the given [compressedData].
  ///
  /// The data must start with the 4-byte decompressed-size header followed
  /// by the compressed bitstream.
  Decompressor(this.compressedData);

  // ---------------------------------------------------------------------------
  // Constants
  // ---------------------------------------------------------------------------

  /// Total node slots in the Huffman tree (internal + leaf positions).
  static const int _totalNodes = 0x273; // 627

  /// Number of distinct leaf symbols: 256 literals + 58 length codes.
  static const int _numSymbols = 0x13A; // 314

  /// Index of the Huffman tree root node.
  static const int _rootNode = _totalNodes - 1; // 0x272 = 626

  /// Ring-buffer (sliding window) size.
  static const int _ringSize = 0x1000; // 4096

  /// Initial write position in the ring buffer. Positions 0.._initialRingPos
  /// are pre-filled with space (0x20) characters.
  static const int _initialRingPos = 0xFC4; // 4036

  // ---------------------------------------------------------------------------
  // Static lookup tables for LZSS distance decoding
  // ---------------------------------------------------------------------------

  /// Number of bits used to encode each distance prefix. Subtract 2 to get
  /// the number of additional low-order bits read after the 8-bit prefix.
  ///
  /// Distribution: 32×3, 48×4, 64×5, 48×6, 48×7, 16×8 = 256 entries.
  /// Standard LZSS distance slot bit-width table (as used in LZH/LHA `-lh5-`
  /// and similar schemes). Each entry gives the total number of bits in the
  /// distance encoding for that 8-bit prefix value.
  ///
  // @formatter:off
  static const _distBitCount = <int>[
    3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, //   0..15
    3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, //  16..31
    4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, //  32..47
    4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, //  48..63
    4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, //  64..79
    5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, //  80..95
    5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, //  96..111
    5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, // 112..127
    5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, // 128..143
    6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, // 144..159
    6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, // 160..175
    6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, // 176..191
    7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, // 192..207
    7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, // 208..223
    7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, // 224..239
    8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, // 240..255
  ];
  // @formatter:on

  /// High-order bits of the LZSS distance, indexed by the 8-bit prefix.
  ///
  /// The looked-up value undergoes a 16-bit rotate-right-by-2 and byte-swap
  /// to form the upper portion of the final distance. The trailing `0` at
  /// index 256 is intentional (257 entries matching the original game).
  ///
  // @formatter:off
  static const _distHighBits = <int>[
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //   0..15
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //  16..31
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, //  32..47
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, //  48..63
    3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, //  64..79
    4, 4, 4, 4, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5, 5, 5, //  80..95
    6, 6, 6, 6, 6, 6, 6, 6, 7, 7, 7, 7, 7, 7, 7, 7, //  96..111
    8, 8, 8, 8, 8, 8, 8, 8, 9, 9, 9, 9, 9, 9, 9, 9, // 112..127
    10, 10, 10, 10, 10, 10, 10, 10, 11, 11, 11, 11, 11, 11, 11, 11, // 128..143
    12, 12, 12, 12, 13, 13, 13, 13, 14, 14, 14, 14, 15, 15, 15, 15, // 144..159
    16, 16, 16, 16, 17, 17, 17, 17, 18, 18, 18, 18, 19, 19, 19, 19, // 160..175
    20, 20, 20, 20, 21, 21, 21, 21, 22, 22, 22, 22, 23, 23, 23, 23, // 176..191
    24, 24, 25, 25, 26, 26, 27, 27, 28, 28, 29, 29, 30, 30, 31, 31, // 192..207
    32, 32, 33, 33, 34, 34, 35, 35, 36, 36, 37, 37, 38, 38, 39, 39, // 208..223
    40, 40, 41, 41, 42, 42, 43, 43, 44, 44, 45, 45, 46, 46, 47, 47, // 224..239
    48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, // 240..255
    0, // 256
  ];
  // @formatter:on

  // ---------------------------------------------------------------------------
  // Instance state
  // ---------------------------------------------------------------------------

  /// The compressed input data (including the 4-byte size header).
  final Uint8List compressedData;

  /// Bitstream reader for sequential byte/word/bit access.
  late BitReader _reader;

  // -- Huffman tree arrays ----------------------------------------------------
  //
  // The tree uses four parallel arrays indexed by node index (0.._totalNodes).
  //
  // _parent and _symbolToNode share a single backing buffer, replicating the
  // original game's contiguous memory layout. The adaptive tree-update code
  // intentionally writes past the end of _parent (index >= _totalNodes) into
  // _symbolToNode. The Int16List.sublistView preserves this overflow behaviour.

  /// Parent-node pointer for each tree node.
  ///
  /// For node `n`, `_parent[n]` is the index of its parent. The root's parent
  /// is a sentinel `0` that terminates upward tree walks.
  final Int16List _parent = Int16List(_totalNodes + _numSymbols);

  /// Maps a leaf symbol (0..[_numSymbols]-1) to its current position in the
  /// Huffman tree.
  ///
  /// This is a view into the tail of [_parent] starting at offset
  /// [_totalNodes], so overflow writes from [_parent] naturally land here.
  late final Int16List _symbolToNode =
      Int16List.sublistView(_parent, _totalNodes);

  /// Root node value (>= _totalNodes) if leaf, or child pointer if internal.
  final Int16List _children = Int16List(_totalNodes);

  /// Frequency (weight) of each tree node.
  ///
  /// Nodes are maintained in non-decreasing frequency order so that the
  /// adaptive update can restore the sibling property via swaps.
  ///
  /// Uses [Int16List] (signed 16-bit) so that overflow to -32768 is detected
  /// to trigger a tree rebuild.
  final Int16List _frequency = Int16List(_totalNodes);

  // -- LZSS ring buffer -------------------------------------------------------

  /// Sliding-window ring buffer for LZSS back-references.
  late RingBuffer _ring;

  /// Remaining number of decompressed bytes to produce. Treated as a signed
  /// 32-bit counter; decompression stops when it reaches zero or goes negative.
  int _bytesRemaining = 0;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Decompresses the data and returns the uncompressed bytes.
  ///
  /// The first four bytes of the input encode the decompressed size as two
  /// little-endian uint16 words (low word, then high word).
  Uint8List decompress() {
    _reader = BitReader(compressedData);

    // Read the 4-byte decompressed-size header.
    _bytesRemaining = _reader.readUint32LE();

    if (_bytesRemaining == 0) {
      return Uint8List(0);
    }

    _initTree();

    // Pre-fill ring buffer with spaces (0x20). The fill value matters:
    // early back-references can reach into this pre-filled region.
    _ring = RingBuffer(
      size: _ringSize,
      initialPosition: _initialRingPos,
      fillByte: 0x20,
    );

    final result = <int>[];

    // Main decode loop. The counter is treated as signed 32-bit so that an
    // overshoot from a match length (which decrements past zero, wrapping to
    // a large unsigned value) is caught as negative, stopping the loop.
    // TODO(bramp): Instead of relying on overflow, we could check for
    //  matchLen > _bytesRemaining
    while (_bytesRemaining.toSigned(32) > 0) {
      final symbol = _decodeSymbol();

      if (symbol < 256) {
        // Literal byte — output and append to ring buffer.
        result.add(symbol);
        _ring.writeByte(symbol);
        _bytesRemaining--;
        continue;
      }

      // LZSS match — read distance, then copy from ring buffer.
      final distance = _readDistance();
      final matchLen = symbol - 256 + 3;

      _ring.copyFrom(distance, matchLen, result);
      _bytesRemaining -= matchLen;
    }

    return Uint8List.fromList(result);
  }

  // ---------------------------------------------------------------------------
  // LZSS distance decoding
  // ---------------------------------------------------------------------------

  /// Reads a variable-length LZSS match distance from the bitstream.
  ///
  /// The 12-bit distance is encoded in two parts:
  ///   1. An 8-bit prefix, used to look up the high 6 bits via
  ///      [_distHighBits].
  ///   2. Additional low-order bits (count from [_distBitCount] minus 2).
  ///
  /// **Important:** The two bit-reading loops have subtly different reload
  /// behaviour (`0x0F` vs `0x10`) and must remain inline — extracting a shared
  /// `_nextBit()` helper breaks decompression.
  int _readDistance() {
    var prefix = 0;

    // Read 8-bit distance prefix, one bit at a time (MSB-first).
    for (var i = 0; i < 8; i++) {
      if (_reader.bitsRemaining == 0) {
        _reader
          ..readWord()
          ..bitsRemaining = 0x0F;
      } else {
        _reader.bitsRemaining--;
      }

      prefix = (prefix << 1) & 0xFFFF;
      if ((_reader.word & 0x8000) != 0) {
        prefix |= 1;
      }
      _reader.word = (_reader.word << 1) & 0xFFFF;
    }

    // Look up the high-order 6 bits of the 12-bit distance. The original
    // assembly used a rotate-right-2 + byte-swap, which is equivalent to
    // shifting the table value left by 6 to place it in bits 6–11.
    final highBits = _distHighBits[prefix] << 6;

    // Read additional low-order bits (shifted into [prefix] which becomes
    // [lowBits] after masking). The bit count comes from the table minus 2
    // (representing the 2 bits already encoded by the high-bits table).
    final extraBitCount = _distBitCount[prefix] - 2;
    var lowBits = prefix;

    for (var i = 0; i < extraBitCount; i++) {
      if (_reader.bitsRemaining == 0) {
        _reader
          ..readWord()
          ..bitsRemaining = 0x10;
      }

      lowBits = (lowBits << 1) & 0xFFFF;
      if ((_reader.word & 0x8000) != 0) {
        lowBits |= 1;
      }
      _reader.word = (_reader.word << 1) & 0xFFFF;
      _reader.bitsRemaining--;
    }

    return highBits | (lowBits & 0x3F);
  }

  // ---------------------------------------------------------------------------
  // Huffman tree initialisation
  // ---------------------------------------------------------------------------
  // TODO(bramp): I think this can be refactored into its own class
  //  (e.g. AdaptiveHuffmanTree).

  /// Initialises the adaptive Huffman tree with uniform leaf frequencies.
  ///
  /// Creates [_numSymbols] leaf nodes (each with frequency 1) and builds
  /// internal nodes bottom-up by combining consecutive pairs.
  void _initTree() {
    // Initialise leaf nodes: each symbol gets frequency 1 and a leaf marker.
    for (var i = 0; i < _numSymbols; i++) {
      _frequency[i] = 1;
      _children[i] = i + _totalNodes; // leaf marker (>= _totalNodes)
      _symbolToNode[i] = i;
    }

    // Build internal nodes bottom-up by combining consecutive child pairs.
    var childIdx = 0;
    for (var node = _numSymbols; node <= _rootNode; node++) {
      _parent[childIdx] = node;
      _parent[childIdx + 1] = node;
      _frequency[node] = _frequency[childIdx] + _frequency[childIdx + 1];
      _children[node] = childIdx;
      childIdx += 2;
    }

    // Root's parent is sentinel 0 (terminates leaf-to-root walks).
    _parent[_rootNode] = 0;
  }

  // ---------------------------------------------------------------------------
  // Huffman symbol decoding + adaptive tree update
  // ---------------------------------------------------------------------------

  /// Decodes a single symbol from the bitstream by walking the Huffman tree
  /// from root to leaf, then updates frequencies along the leaf-to-root path.
  ///
  /// Returns the decoded symbol (0..[_numSymbols]-1).
  int _decodeSymbol() {
    var node = _children[_rootNode];

    // Walk from root to leaf, reading one bit per tree level.
    while (node < _totalNodes) {
      // Read the next bit from the bitstream. The reload behaviour here
      // (bitsRemaining = 0x0F) differs from _readDistance (0x0F / 0x10)
      // and must NOT be unified into a shared helper.
      if (_reader.bitsRemaining > 0) {
        _reader.bitsRemaining--;
      } else {
        _reader
          ..readWord()
          ..bitsRemaining = 0x0F;
      }

      if ((_reader.word & 0x8000) != 0) {
        node++; // right child
      }
      _reader.word = (_reader.word << 1) & 0xFFFF;
      node = _children[node];
    }

    // Extract the symbol from the leaf marker.
    final symbol = node - _totalNodes;

    // Rebuild tree if root frequency overflows signed 16-bit.
    final rootFreq = _frequency[_rootNode];
    if (rootFreq == -32768 || rootFreq == 0x8000) {
      _rebuildTree();
    }

    _updateFrequencies(symbol);
    return symbol;
  }

  /// Increments node frequencies from [symbol]'s leaf up to the root,
  /// swapping nodes as needed to maintain the sibling property (nodes
  /// ordered by non-decreasing frequency).
  void _updateFrequencies(int symbol) {
    var node = _symbolToNode[symbol];

    do {
      _frequency[node]++;
      // Use unsigned comparison to handle Int16List sign extension.
      final freq = _frequency[node] & 0xFFFF;

      // Check whether the incremented frequency violates the sorted order.
      // If so, find the rightmost node with a lower frequency and swap.
      var target = node + 1;
      if (target < _frequency.length && freq > (_frequency[target] & 0xFFFF)) {
        // Scan right to find the last node with frequency < freq.
        while (target + 1 < _frequency.length &&
            freq > (_frequency[target + 1] & 0xFFFF)) {
          target++;
        }

        // Swap frequencies.
        _frequency[node] = _frequency[target];
        _frequency[target] = freq;

        // Swap children and fix parent pointers.
        final nodeChild = _children[node];
        final targetChild = _children[target];

        _children[target] = nodeChild;
        _parent[nodeChild] = target;
        if (nodeChild < _totalNodes) _parent[nodeChild + 1] = target;

        _children[node] = targetChild;
        _parent[targetChild] = node;
        if (targetChild < _totalNodes) _parent[targetChild + 1] = node;

        // Continue from the swap target (where our node's data now lives).
        node = target;
      }

      // Walk up to the parent.
      node = _parent[node];
    } while (node != 0);
  }

  // ---------------------------------------------------------------------------
  // Tree rebuild (frequency overflow recovery)
  // ---------------------------------------------------------------------------

  /// Rebuilds the Huffman tree when the root frequency overflows.
  ///
  /// Halves all leaf frequencies and reconstructs internal nodes via an
  /// insertion-sort merge. Finally rebuilds parent pointers from children.
  ///
  /// **Note:** This method preserves several quirks from the original 16-bit
  /// assembly code (translated through OpenFodder's C++): the shift offset of
  /// 2 (instead of 1) and the `_frequency[combinedFreq] = combinedFreq` write
  /// are artifacts of the byte-indexed-to-word-indexed conversion. They produce
  /// output identical to the original game.
  void _rebuildTree() {
    // Phase 1 — Compact leaf nodes to the front, halving their frequencies.
    var writePos = 0;
    for (var i = 0; i < _totalNodes; i++) {
      if (_children[i] >= _totalNodes) {
        // Halve the frequency, rounding up: (freq + 1) >> 1.
        _frequency[writePos] = (_frequency[i] + 1) >> 1;
        _children[writePos] = _children[i];
        writePos++;
      }
    }

    // Phase 2 — Rebuild internal nodes by sorted insertion.
    //
    // For each consecutive child pair, compute a combined frequency and
    // insert it at the correct sorted position, shifting existing entries
    // rightward.
    //
    // **Preserved quirks from the original 16-bit assembly:**
    // - The shift source offset is `dst - 2` (not `dst - 1`), matching the
    //   original byte-indexed pointer arithmetic on word-sized arrays.
    // - `_frequency[combinedFreq] = combinedFreq` writes the VALUE as both
    //   the INDEX and the stored value — an assembly translation artifact
    //   required for binary-compatible output.
    var childIdx = 0;
    var nodeIdx = _numSymbols;

    do {
      final combinedFreq = _frequency[childIdx] + _frequency[childIdx + 1];
      _frequency[nodeIdx] = combinedFreq;

      // Scan backwards from nodeIdx to find the insertion point.
      var insertAt = nodeIdx - 1;
      while (_frequency[insertAt] > combinedFreq) {
        insertAt--;
      }
      insertAt++;

      final shiftCount = nodeIdx - insertAt;

      // Shift entries rightward to make room. The source offset of -2
      // (instead of -1) matches the original assembly.
      var dst = insertAt + shiftCount;
      var src = dst - 2;
      for (var i = 0; i < shiftCount; i++) {
        _frequency[dst] = _frequency[src];
        _children[dst] = _children[src];
        dst--;
        src--;
      }

      // Insert the new internal node at the sorted position.
      _frequency[combinedFreq] = combinedFreq; // original game quirk
      _children[insertAt] = childIdx;
      childIdx++;
      nodeIdx++;
    } while (nodeIdx < _totalNodes);

    // Phase 3 — Rebuild parent pointers from the children array.
    for (var i = 0; i < _totalNodes; i++) {
      final child = _children[i];
      if (child >= _totalNodes) {
        // Leaf node — single parent pointer.
        _parent[child] = i;
      } else {
        // Internal node pair — both children share the same parent.
        _parent[child] = i;
        _parent[child + 1] = i;
      }
    }
  }
}
