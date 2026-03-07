// ignore_for_file: avoid_print, CLI tool uses print for user output.

import 'dart:io';

import 'package:fodder_tools/sprite_data_parser.dart';
import 'package:fodder_tools/sprite_frame.dart';
import 'package:fodder_tools/sprite_names.dart';
import 'package:path/path.dart' as p;

/// Audits [sprite_names.dart] against the OpenFodder C++ header file.
///
/// Parses `SpriteData_PC.hpp` (the ground truth) and compares every group's
/// frame count, byte offsets, and dimensions against the hand-maintained
/// Dart maps. Reports mismatches, missing groups, and extra groups.
void main() {
  final scriptDir = File(Platform.script.toFilePath()).parent.path;
  // Go up from bin/ → fodder_tools/ → packages/ → monorepo root.
  final projectRoot = p.dirname(p.dirname(p.dirname(scriptDir)));

  final spriteDataPath = p.join(
    projectRoot,
    'vendor',
    'openfodder',
    'Source',
    'PC',
    'SpriteData_PC.hpp',
  );

  final spriteDataFile = File(spriteDataPath);
  if (!spriteDataFile.existsSync()) {
    print('Error: Could not find $spriteDataPath');
    exit(1);
  }

  print('Parsing sprite data from ${spriteDataFile.path}...\n');
  final sheets = SpriteDataParser.parse(file: spriteDataFile);

  var totalIssues = 0;

  for (final sheet in sheets) {
    totalIssues += _auditSheet(sheet);
  }

  print('');
  if (totalIssues == 0) {
    print('All sprite_names.dart entries match the C++ source.');
  } else {
    print('$totalIssues issue(s) found.');
    print('');
    print('Note: CF2 differences are expected — sprite_names.dart uses CF1');
    print('as the baseline. CF2-only entries or dimension changes are known.');
    exit(1);
  }
}

/// Maps a parsed [SpriteSheetType] to the Dart name-table maps it should
/// match. A single C++ sheet may span multiple Dart maps (split by GfxType).
///
/// Returns a list of `(mapName, dartMap)` pairs.
List<(String, Map<int, SpriteGroup>)> _dartMapsForSheet(SpriteSheetType sheet) {
  final key = normaliseSheetName(sheet.name);
  switch (key) {
    case 'ingame':
      return [
        ('armyDatIngame', armyDatIngame),
        ('coptDatIngame', coptDatIngame),
      ];
    case 'service':
      return [
        ('rankfontDatService', rankfontDatService),
        ('morphbigDatService', morphbigDatService),
      ];
    case 'briefing':
      return [('pstuffDatBriefing', pstuffDatBriefing)];
    case 'font':
      return [('fontDatFont', fontDatFont)];
    case 'hill':
      return [('hillbitsDatHill', hillbitsDatHill)];
    case 'recruit':
      return [('hillbitsDatRecruit', hillbitsDatRecruit)];
    default:
      return [];
  }
}

/// Audits one C++ sheet against the corresponding Dart maps.
/// Returns the number of issues found.
int _auditSheet(SpriteSheetType sheet) {
  final maps = _dartMapsForSheet(sheet);
  if (maps.isEmpty) {
    print('WARNING: No Dart map for sheet "${sheet.name}"');
    return 1;
  }

  // Merge all Dart maps for this sheet into one combined map.
  final combined = <int, SpriteGroup>{};
  for (final (_, dartMap) in maps) {
    combined.addAll(dartMap);
  }

  var issues = 0;

  // Check each C++ group against the Dart map.
  for (var groupIdx = 0; groupIdx < sheet.entries.length; groupIdx++) {
    final cppFrames = sheet.entries[groupIdx];
    if (cppFrames.isEmpty) continue;

    final dartGroup = combined[groupIdx];
    final hexIdx = '0x${groupIdx.toRadixString(16).padLeft(2, '0')}';

    if (dartGroup == null) {
      // Not necessarily an issue — some groups are intentionally omitted
      // (padding, unused entries). Only warn if the C++ group has real data.
      final hasData = cppFrames.any((f) => f.width > 0 && f.height > 0);
      if (hasData) {
        print(
          '  MISSING: ${sheet.name}[$hexIdx] '
          '(${cppFrames.length} frames, '
          '${cppFrames.first.width}x${cppFrames.first.height})',
        );
        issues++;
      }
      continue;
    }

    // Check frame count.
    if (dartGroup.frameCount != cppFrames.length) {
      print(
        '  MISMATCH: ${sheet.name}[$hexIdx] "${dartGroup.name}" '
        'frame count: dart=${dartGroup.frameCount} '
        'vs cpp=${cppFrames.length}',
      );
      issues++;
      continue;
    }

    // Check per-frame data.
    for (var fi = 0; fi < cppFrames.length; fi++) {
      final cpp = cppFrames[fi];
      issues += _auditFrame(sheet.name, hexIdx, dartGroup, fi, cpp);
    }
  }

  // Check for extra Dart entries not present in C++.
  for (final idx in combined.keys) {
    if (idx >= sheet.entries.length || sheet.entries[idx].isEmpty) {
      final hexIdx = '0x${idx.toRadixString(16).padLeft(2, '0')}';
      print(
        '  EXTRA: ${sheet.name}[$hexIdx] "${combined[idx]!.name}" '
        'exists in Dart but not in C++',
      );
      issues++;
    }
  }

  final status = issues == 0 ? 'OK' : '$issues issue(s)';
  print(
    '${sheet.name}: $status '
    '(${sheet.entries.length} cpp groups, '
    '${combined.length} dart entries)',
  );

  return issues;
}

/// Audits a single frame within a group.
/// Returns 1 if there's an issue, 0 otherwise.
int _auditFrame(
  String sheetName,
  String hexIdx,
  SpriteGroup dartGroup,
  int frameIdx,
  SpriteFrame cpp,
) {
  final int dartOffset;
  final int dartW;
  final int dartH;
  final int dartModX;
  final int dartModY;

  if (dartGroup.isVariable) {
    final f = dartGroup.frames[frameIdx];
    dartOffset = f.byteOffset;
    dartW = f.w;
    dartH = f.h;
    dartModX = f.modX;
    dartModY = f.modY;
  } else {
    dartOffset = dartGroup.offsets[frameIdx];
    dartW = dartGroup.w;
    dartH = dartGroup.h;
    dartModX = 0;
    dartModY = 0;
  }

  final mismatches = <String>[];

  if (dartOffset != cpp.byteOffset) {
    mismatches.add('offset: dart=$dartOffset vs cpp=${cpp.byteOffset}');
  }
  if (dartW != cpp.width) {
    mismatches.add('width: dart=$dartW vs cpp=${cpp.width}');
  }
  if (dartH != cpp.height) {
    mismatches.add('height: dart=$dartH vs cpp=${cpp.height}');
  }
  if (dartModX != cpp.modX) {
    mismatches.add('modX: dart=$dartModX vs cpp=${cpp.modX}');
  }
  if (dartModY != cpp.modY) {
    mismatches.add('modY: dart=$dartModY vs cpp=${cpp.modY}');
  }

  if (mismatches.isNotEmpty) {
    print(
      '  MISMATCH: $sheetName[$hexIdx] "${dartGroup.name}" '
      'frame $frameIdx: ${mismatches.join(', ')}',
    );
    return 1;
  }

  return 0;
}
