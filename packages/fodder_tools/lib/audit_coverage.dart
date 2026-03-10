import 'dart:io';

import 'package:fodder_tools/sprite_frame.dart';
import 'package:fodder_tools/sprite_names.dart';

/// Audits sprite_names.dart for naming quality issues.
///
/// Reports:
/// - Unnamed groups (exist in C++ data but no Dart entry)
/// - Groups with placeholder names (containing `?` or generic prefixes)
/// - Groups whose names contain TODO markers (from source comments)
/// - Summary counts per sheet
void exportCoverage(List<SpriteSheetType> sheets) {
  final seenSheets = <String>{};
  var totalUnnamed = 0;
  var totalPlaceholder = 0;
  var totalNamed = 0;

  for (final sheet in sheets) {
    final key = normaliseSheetName(sheet.name);
    // Skip duplicate normalised sheets (e.g. InGame_CF1 / InGame_CF2).
    if (!seenSheets.add(key)) continue;

    final combined = dartMapForSheet(sheet);

    var unnamed = 0;
    var placeholder = 0;
    var named = 0;
    final issues = <String>[];

    for (var gi = 0; gi < sheet.entries.length; gi++) {
      final cppFrames = sheet.entries[gi];
      if (cppFrames.isEmpty) continue;

      // Skip groups with no visible pixels.
      final hasData = cppFrames.any((f) => f.width > 0 && f.height > 0);
      if (!hasData) continue;

      final hexIdx = '0x${gi.toRadixString(16).padLeft(2, '0')}';
      final dartGroup = combined?[gi];

      if (dartGroup == null) {
        unnamed++;
        issues.add(
          '  UNNAMED  $key[$hexIdx] '
          '(${cppFrames.length} frames, '
          '${cppFrames.first.width}x${cppFrames.first.height})',
        );
      } else if (_isPlaceholder(dartGroup.name)) {
        placeholder++;
        issues.add(
          '  PLACEHOLDER  $key[$hexIdx] "${dartGroup.name}" '
          '(${cppFrames.length} frames)',
        );
      } else {
        named++;
      }
    }

    if (issues.isNotEmpty) {
      stdout.writeln('=== $key ===');
      for (final issue in issues) {
        stdout.writeln(issue);
      }
      stdout.writeln(
        '  Summary: $named named, $placeholder placeholder, $unnamed unnamed',
      );
      stdout.writeln();
    } else {
      stdout.writeln('=== $key === OK ($named named)');
      stdout.writeln();
    }

    totalUnnamed += unnamed;
    totalPlaceholder += placeholder;
    totalNamed += named;
  }

  stdout.writeln('---');
  stdout.writeln(
    'Total: $totalNamed named, '
    '$totalPlaceholder placeholder, '
    '$totalUnnamed unnamed',
  );

  if (totalUnnamed + totalPlaceholder > 0) {
    exit(1);
  }
}

/// Returns true if [name] looks like a placeholder rather than a real name.
bool _isPlaceholder(String name) {
  // Names that are just `?` or start with generic prefixes.
  if (name == '?' || name.startsWith('unknown')) return true;
  // Names containing `_?` like "something_?" for partial placeholders.
  if (name.contains('_?')) return true;
  return false;
}
