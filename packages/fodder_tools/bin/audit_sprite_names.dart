import 'dart:io';

import 'package:fodder_tools/audit_coverage.dart' as coverage;
import 'package:fodder_tools/audit_html_export.dart' as html_export;
import 'package:fodder_tools/sprite_data_parser.dart';
import 'package:fodder_tools/sprite_frame.dart';
import 'package:fodder_tools/sprite_names.dart';
import 'package:path/path.dart' as p;

/// Audits [sprite_names.dart] against the OpenFodder C++ header file.
///
/// Parses `SpriteData_PC.hpp` (the ground truth) and compares every group's
/// frame count, byte offsets, and dimensions against the hand-maintained
/// Dart maps. Reports mismatches, missing groups, and extra groups.
///
/// Pass `--csv` to emit a CSV comparing our names with the C++ descriptions.
/// Pass `--html <dir>` to generate a visual HTML audit page with sprite
/// previews clipped from the atlas PNGs.
/// Pass `--coverage` to report frame overlaps and uncovered pixel regions.
void main(List<String> args) {
  if (args.contains('--help') || args.contains('-h')) {
    stdout.writeln('Usage: dart run bin/audit_sprite_names.dart [options]');
    stdout.writeln();
    stdout.writeln(
      'Audits sprite_names.dart against the OpenFodder C++ header.',
    );
    stdout.writeln();
    stdout.writeln('Options:');
    stdout.writeln(
      '  --csv             Emit CSV comparing Dart names with C++ descriptions',
    );
    stdout.writeln(
      '  --html <dir>      Generate visual HTML audit page with sprite previews',
    );
    stdout.writeln(
      '  --coverage        Report frame overlaps and uncovered pixel regions',
    );
    stdout.writeln('  -h, --help        Show this help message');
    return;
  }

  final csvMode = args.contains('--csv');
  final htmlIdx = args.indexOf('--html');
  final htmlMode = htmlIdx != -1;
  final coverageMode = args.contains('--coverage');
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
    stdout.writeln('Error: Could not find $spriteDataPath');
    exit(1);
  }

  stdout.writeln('Parsing sprite data from ${spriteDataFile.path}...\n');
  final sheets = SpriteDataParser.parse(file: spriteDataFile);

  if (csvMode) {
    _exportCsv(sheets);
    return;
  }

  if (coverageMode) {
    coverage.exportCoverage(sheets);
    return;
  }

  if (htmlMode) {
    final spriteDir = htmlIdx + 1 < args.length ? args[htmlIdx + 1] : null;
    if (spriteDir == null) {
      stdout.writeln('Usage: --html <sprites-dir>');
      stdout.writeln(
        '  e.g. --html ../../packages/fodder_assets/assets/cf1/sprites',
      );
      exit(1);
    }
    html_export.exportHtml(sheets, Directory(spriteDir));
    return;
  }

  var totalIssues = 0;

  for (final sheet in sheets) {
    totalIssues += _auditSheet(sheet);
  }

  stdout.writeln();
  if (totalIssues == 0) {
    stdout.writeln('All sprite_names.dart entries match the C++ source.');
  } else {
    stdout.writeln('$totalIssues issue(s) found.');
    stdout.writeln();
    stdout.writeln(
      'Note: CF2 differences are expected — sprite_names.dart uses CF1',
    );
    stdout.writeln(
      'as the baseline. CF2-only entries or dimension changes are known.',
    );
    exit(1);
  }
}

// ---------------------------------------------------------------------------
// CSV export
// ---------------------------------------------------------------------------

/// Emits a CSV to stdout comparing our Dart names with the C++ descriptions.
void _exportCsv(List<SpriteSheetType> sheets) {
  stdout.writeln('sheet,index,dart_name,cpp_description,frames,match');

  for (final sheet in sheets) {
    final combined = dartMapForSheet(sheet);
    if (combined == null) continue;

    for (var groupIdx = 0; groupIdx < sheet.entries.length; groupIdx++) {
      final cppFrames = sheet.entries[groupIdx];
      if (cppFrames.isEmpty) continue;

      // Skip groups with no visible pixels.
      final hasData = cppFrames.any((f) => f.width > 0 && f.height > 0);
      if (!hasData) continue;

      final dartGroup = combined[groupIdx];
      final hexIdx = '0x${groupIdx.toRadixString(16).padLeft(2, '0')}';

      // The C++ description is the same for all frames in a group.
      final cppDesc = cppFrames.first.description ?? '';
      final dartName = dartGroup?.name ?? '';
      final frameCount = cppFrames.length;

      // Simple heuristic: flag if names look completely different.
      final match = dartName.isEmpty
          ? 'MISSING'
          : dartName.toLowerCase() == cppDesc.toLowerCase()
          ? 'exact'
          : '';

      stdout.writeln(
        '${_csvEscape(sheet.name)},'
        '$hexIdx,'
        '${_csvEscape(dartName)},'
        '${_csvEscape(cppDesc)},'
        '$frameCount,'
        '$match',
      );
    }
  }
}

/// Escapes a value for CSV (wraps in quotes if it contains commas or quotes).
String _csvEscape(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

// ---------------------------------------------------------------------------
// Default audit mode
// ---------------------------------------------------------------------------

/// Audits one C++ sheet against the corresponding Dart maps.
/// Returns the number of issues found.
int _auditSheet(SpriteSheetType sheet) {
  final combined = dartMapForSheet(sheet);
  if (combined == null) {
    stdout.writeln('WARNING: No Dart map for sheet "${sheet.name}"');
    return 1;
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
        stdout.writeln(
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
      stdout.writeln(
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
      stdout.writeln(
        '  EXTRA: ${sheet.name}[$hexIdx] "${combined[idx]!.name}" '
        'exists in Dart but not in C++',
      );
      issues++;
    }
  }

  final status = issues == 0 ? 'OK' : '$issues issue(s)';
  stdout.writeln(
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
    stdout.writeln(
      '  MISMATCH: $sheetName[$hexIdx] "${dartGroup.name}" '
      'frame $frameIdx: ${mismatches.join(', ')}',
    );
    return 1;
  }

  return 0;
}
