import 'dart:io';

import 'package:fodder_tools/sprite_frame.dart';

/// Parses OpenFodder's `SpriteData_PC.hpp` C++ header file and extracts
/// all sprite sheet metadata as structured Dart objects.
///
/// The C++ file contains:
/// 1. Named `sSpriteSheet` arrays (e.g. `stru_32FAC[3] = { ... }`)
/// 2. Pointer arrays (e.g. `mSpriteSheetTypes_InGame_PC[]`) that index into
///    the named arrays to form an ordered sprite lookup table.
///
/// This parser extracts both and produces [SpriteSheetType] objects that
/// combine the named arrays into the ordered lookup tables.
class SpriteDataParser {
  /// Parses the given C++ header file content and returns all sprite sheet
  /// type definitions.
  ///
  /// If [file] is provided, reads from it. Otherwise [source] must contain
  /// the file content.
  static List<SpriteSheetType> parse({File? file, String? source}) {
    assert(
      file != null || source != null,
      'Either file or source must be provided.',
    );
    final content = source ?? file!.readAsStringSync();

    // Step 1: Parse all named sSpriteSheet arrays.
    final arrays = _parseArrays(content);

    // Step 2: Parse pointer arrays and resolve references.
    return _parsePointerArrays(content, arrays);
  }

  /// Finds the matching closing brace for an opening `{` at [start].
  ///
  /// Returns the index of the `}` that balances the brace at [start],
  /// or -1 if not found.
  static int _findClosingBrace(String content, int start) {
    var depth = 0;
    for (var i = start; i < content.length; i++) {
      if (content[i] == '{') {
        depth++;
      } else if (content[i] == '}') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }

  /// Parses all `sSpriteSheet varName[N] = { ... }` blocks.
  ///
  /// Returns a map from variable name → list of sprite frames.
  static Map<String, List<SpriteFrame>> _parseArrays(String content) {
    final result = <String, List<SpriteFrame>>{};

    // Match the declaration up to the opening brace.
    // Body may contain nested braces, so we find the matching close brace
    // manually.
    final declPattern = RegExp(
      r'(?:const\s+)?sSpriteSheet\s+(\w+)\s*\[\s*\d*\s*\]\s*=\s*\{',
      multiLine: true,
    );

    for (final match in declPattern.allMatches(content)) {
      final name = match.group(1)!;
      final openBrace = match.end - 1; // index of '{'
      final closeBrace = _findClosingBrace(content, openBrace);
      if (closeBrace < 0) continue;

      final body = content.substring(openBrace + 1, closeBrace);
      result[name] = _parseEntries(body);
    }

    return result;
  }

  /// Parses the comma-separated `{ offset, gfx, f4, f6, w, h, pal, mx, my }`
  /// entries within an array body.
  static List<SpriteFrame> _parseEntries(String body) {
    final frames = <SpriteFrame>[];

    // Match each { val, val, val, val, val, val, val, val, val }
    final entryPattern = RegExp(
      r'\{\s*'
      r'(-?\d+)\s*,\s*' // mLoadOffset
      r'(\w+)\s*,\s*' // mLoadSegment (eGFX_*)
      r'(-?\d+)\s*,\s*' // field_4
      r'(-?\d+)\s*,\s*' // field_6
      r'(-?\d+)\s*,\s*' // mColCount (width)
      r'(-?\d+)\s*,\s*' // mRowCount (height)
      r'(-?\d+)\s*,\s*' // mPalleteIndex
      r'(-?\d+)\s*,\s*' // mModX
      r'(-?\d+)\s*' // mModY
      r'\}',
    );

    for (final match in entryPattern.allMatches(body)) {
      frames.add(
        SpriteFrame(
          byteOffset: int.parse(match.group(1)!),
          gfxType: _parseGfxType(match.group(2)!),
          width: int.parse(match.group(5)!),
          height: int.parse(match.group(6)!),
          paletteIndex: int.parse(match.group(7)!),
          modX: int.parse(match.group(8)!),
          modY: int.parse(match.group(9)!),
        ),
      );
    }

    return frames;
  }

  /// Converts an `eGFX_*` enum name to its [GfxType] enum value.
  static GfxType _parseGfxType(String name) {
    const mapping = <String, GfxType>{
      'eGFX_IN_GAME': GfxType.inGame,
      'eGFX_IN_GAME2': GfxType.inGame2,
      'eGFX_FONT': GfxType.font,
      'eGFX_HILL': GfxType.hill,
      'eGFX_RECRUIT': GfxType.recruit,
      'eGFX_BRIEFING': GfxType.briefing,
      'eGFX_SERVICE': GfxType.service,
      'eGFX_RANKFONT': GfxType.rankFont,
      'eGFX_PSTUFF': GfxType.pstuff,
    };
    return mapping[name] ?? GfxType.unknown;
  }

  /// Parses `mSpriteSheetTypes_*_PC[]` pointer arrays.
  ///
  /// Each such array is a list of variable names that index into the
  /// named arrays parsed by [_parseArrays].
  static List<SpriteSheetType> _parsePointerArrays(
    String content,
    Map<String, List<SpriteFrame>> arrays,
  ) {
    final results = <SpriteSheetType>[];

    // Match declaration up to opening brace. Pointer arrays only contain
    // variable names (no nested braces), so [^}]+ is safe here.
    final ptrPattern = RegExp(
      r'const\s+sSpriteSheet\s*\*\s*'
      r'(mSpriteSheetTypes_(\w+?)_PC2?)\s*\[\s*\]\s*=\s*\{([^}]+)\}',
      multiLine: true,
    );

    for (final match in ptrPattern.allMatches(content)) {
      final fullName = match.group(1)!;
      final shortName = match.group(2)!;
      final body = match.group(3)!;

      // extract variable names from the pointer array body.
      // Lines look like:  /* 0x00 */ stru_32FAC,  // comment
      // or just:          stru_32FAC,
      // The last entry may not have a trailing comma.
      final refPattern = RegExp(
        r'(?:\/\*\s*(?:0x)?[0-9A-F]+\s*\*\/)?\s*(\w+)\s*(?:,\s*)?(?:\/\/.*)?',
        multiLine: true,
      );

      final entries = <List<SpriteFrame>>[];

      for (final refMatch in refPattern.allMatches(body)) {
        final varName = refMatch.group(1)!;
        final frames = arrays[varName];
        if (frames != null) {
          // Look for a comment on this line to use as description
          final line = refMatch.group(0)!;
          final commentMatch = RegExp(r'\/\/\s*(.*)').firstMatch(line);
          final description = commentMatch?.group(1)?.trim();

          if (description != null && description.isNotEmpty) {
            // Apply the description to all frames in this group
            final annotatedFrames = frames
                .map(
                  (f) => SpriteFrame(
                    byteOffset: f.byteOffset,
                    gfxType: f.gfxType,
                    width: f.width,
                    height: f.height,
                    paletteIndex: f.paletteIndex,
                    modX: f.modX,
                    modY: f.modY,
                    description: description,
                  ),
                )
                .toList();
            entries.add(annotatedFrames);
          } else {
            entries.add(frames);
          }
        }
      }

      // Derive a friendly name from the pointer array name.
      var name = shortName;
      if (fullName.contains('PC2')) {
        name = '${shortName}_CF2';
      } else if (shortName.toLowerCase() == 'ingame') {
        name = '${shortName}_CF1';
      }

      results.add(SpriteSheetType(name: name, entries: entries));
    }

    return results;
  }
}
