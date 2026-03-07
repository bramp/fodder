// ignore_for_file: avoid_print, CLI tool uses print for user output.

import 'dart:convert';
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
///
/// Pass `--csv` to emit a CSV comparing our names with the C++ descriptions.
/// Pass `--html <dir>` to generate a visual HTML audit page with sprite
/// previews clipped from the atlas PNGs.
void main(List<String> args) {
  final csvMode = args.contains('--csv');
  final htmlIdx = args.indexOf('--html');
  final htmlMode = htmlIdx != -1;
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

  if (csvMode) {
    _exportCsv(sheets);
    return;
  }

  if (htmlMode) {
    final spriteDir = htmlIdx + 1 < args.length ? args[htmlIdx + 1] : null;
    if (spriteDir == null) {
      print('Usage: --html <sprites-dir>');
      print('  e.g. --html ../../packages/fodder_assets/assets/cf1/sprites');
      exit(1);
    }
    _exportHtml(sheets, Directory(spriteDir));
    return;
  }

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

/// Emits a CSV to stdout comparing our Dart names with the C++ descriptions.
void _exportCsv(List<SpriteSheetType> sheets) {
  print('sheet,index,dart_name,cpp_description,frames,match');

  for (final sheet in sheets) {
    final maps = _dartMapsForSheet(sheet);
    if (maps.isEmpty) continue;

    final combined = <int, SpriteGroup>{};
    for (final (_, dartMap) in maps) {
      combined.addAll(dartMap);
    }

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

      print(
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
// HTML export
// ---------------------------------------------------------------------------

/// Maps a normalised sheet name to the representative atlas files to use.
/// The first file found will be used for the sprite preview.
const _sheetAtlasFiles = <String, List<(String json, String png)>>{
  'ingame': [('junarmy.json', 'junarmy.png'), ('juncopt.json', 'juncopt.png')],
  'font': [('font.json', 'font.png')],
  'briefing': [('pstuff.json', 'pstuff.png')],
  'hill': [('hillbits.json', 'hillbits.png')],
  'recruit': [('hillbits.json', 'hillbits.png')],
  'service': [
    ('rankfont.json', 'rankfont.png'),
    ('morphbig.json', 'morphbig.png'),
  ],
};

/// Generates a self-contained HTML page comparing Dart names with the C++
/// descriptions and showing sprite previews clipped from the atlas PNGs.
void _exportHtml(List<SpriteSheetType> sheets, Directory spriteDir) {
  if (!spriteDir.existsSync()) {
    print('Error: sprite directory not found: ${spriteDir.path}');
    exit(1);
  }

  // Load and base64-encode referenced PNGs, and parse atlas JSONs.
  final pngDataUris = <String, String>{};
  final atlasFrames = <String, Map<String, dynamic>>{};
  final atlasImageWidths = <String, int>{};

  for (final files in _sheetAtlasFiles.values) {
    for (final (jsonFile, pngFile) in files) {
      if (pngDataUris.containsKey(pngFile)) continue;

      final pngPath = p.join(spriteDir.path, pngFile);
      final jsonPath = p.join(spriteDir.path, jsonFile);

      if (!File(pngPath).existsSync() || !File(jsonPath).existsSync()) {
        continue;
      }

      final pngBytes = File(pngPath).readAsBytesSync();
      pngDataUris[pngFile] = 'data:image/png;base64,${base64Encode(pngBytes)}';

      final jsonData =
          json.decode(File(jsonPath).readAsStringSync())
              as Map<String, dynamic>;
      atlasFrames[pngFile] = jsonData['frames'] as Map<String, dynamic>;

      final meta = jsonData['meta'] as Map<String, dynamic>?;
      final metaSize = meta?['size'] as Map<String, dynamic>?;
      atlasImageWidths[pngFile] = (metaSize?['w'] as num?)?.toInt() ?? 320;
    }
  }

  final buf = StringBuffer();
  buf.writeln('<!DOCTYPE html>');
  buf.writeln('<html><head><meta charset="utf-8">');
  buf.writeln('<title>Sprite Names Audit</title>');
  buf.writeln('<style>');
  buf.writeln('''
body { font-family: monospace; background: #1e1e1e; color: #ccc; }
h2 { color: #e0e0e0; border-bottom: 1px solid #555; padding-bottom: 4px; }
table { border-collapse: collapse; margin-bottom: 2em; }
th, td { border: 1px solid #444; padding: 4px 8px; vertical-align: middle; }
th { background: #333; color: #fff; position: sticky; top: 0; }
tr:hover { background: #2a2a2a; }
.sprite-box {
  display: inline-block;
  overflow: hidden;
  background-repeat: no-repeat;
  image-rendering: pixelated;
}
.missing { color: #f44; font-weight: bold; }
.mismatch { background: #442; }
td.name { white-space: nowrap; }
td.sprites { display: flex; flex-wrap: wrap; gap: 2px; align-items: end; }
''');

  // Emit one CSS class per atlas PNG so the data URI is referenced once.
  for (final entry in pngDataUris.entries) {
    final cssClass = _pngCssClass(entry.key);
    buf.writeln('.${cssClass} { background-image: url(${entry.value}); }');
  }

  // Placeholder – keyframes are collected during row generation and
  // injected here via string replacement before writing the file.
  buf.writeln('/* KEYFRAMES_PLACEHOLDER */');

  final keyframesBuf = StringBuffer();

  buf.writeln('</style></head><body>');
  buf.writeln('<h1>Sprite Names Audit</h1>');

  for (final sheet in sheets) {
    final key = normaliseSheetName(sheet.name);
    final maps = _dartMapsForSheet(sheet);
    if (maps.isEmpty) continue;

    final combined = <int, SpriteGroup>{};
    for (final (_, dartMap) in maps) {
      combined.addAll(dartMap);
    }

    // Find the atlas files for this sheet.
    final atlasCandidates = _sheetAtlasFiles[key] ?? [];

    buf.writeln('<h2>${_htmlEscape(sheet.name)}</h2>');
    buf.writeln('<table>');
    buf.writeln(
      '<tr><th>Index</th><th>Dart Name</th>'
      '<th>C++ Description</th><th>Size</th><th>Frames</th>'
      '<th>Sprites</th></tr>',
    );

    for (var groupIdx = 0; groupIdx < sheet.entries.length; groupIdx++) {
      final cppFrames = sheet.entries[groupIdx];
      if (cppFrames.isEmpty) continue;

      final hasData = cppFrames.any((f) => f.width > 0 && f.height > 0);
      if (!hasData) continue;

      final dartGroup = combined[groupIdx];
      final hexIdx = '0x${groupIdx.toRadixString(16).padLeft(2, '0')}';
      final cppDesc = cppFrames.first.description ?? '';
      final dartName = dartGroup?.name ?? '';
      final frameCount = cppFrames.length;
      final isMissing = dartName.isEmpty;

      // Get sprite dimensions from the first C++ frame.
      final firstCpp = cppFrames.first;
      final sizeStr = '${firstCpp.width}×${firstCpp.height}';

      // Look up all frames in atlas.
      final spriteHtml = _spritePreviewHtml(
        sheet.name,
        groupIdx,
        frameCount,
        atlasCandidates,
        atlasFrames,
        pngDataUris,
        atlasImageWidths,
        keyframesBuf,
      );

      final rowClass = isMissing ? ' class="mismatch"' : '';
      final nameClass = isMissing ? ' class="missing"' : ' class="name"';

      buf.writeln('<tr$rowClass>');
      buf.writeln('  <td>$hexIdx</td>');
      buf.writeln(
        '  <td$nameClass>${_htmlEscape(isMissing ? 'MISSING' : dartName)}</td>',
      );
      buf.writeln('  <td>${_htmlEscape(cppDesc)}</td>');
      buf.writeln('  <td>$sizeStr</td>');
      buf.writeln('  <td>$frameCount</td>');
      buf.writeln('  <td class="sprites">$spriteHtml</td>');
      buf.writeln('</tr>');
    }

    buf.writeln('</table>');
  }

  buf.writeln('</body></html>');

  // Inject collected @keyframes rules into the style block.
  var html = buf.toString();
  html = html.replaceFirst(
    '/* KEYFRAMES_PLACEHOLDER */',
    keyframesBuf.toString(),
  );

  final outputPath = 'sprite_audit.html';
  File(outputPath).writeAsStringSync(html);
  print('Wrote $outputPath (${html.length} bytes)');
}

/// Builds inline HTML elements showing all frames of a sprite group,
/// clipped from the atlas PNG using CSS background-position.
///
/// For multi-frame groups an animated preview is prepended before the
/// individual static frame thumbnails.
String _spritePreviewHtml(
  String sheetName,
  int groupIdx,
  int frameCount,
  List<(String json, String png)> atlasCandidates,
  Map<String, Map<String, dynamic>> atlasFrames,
  Map<String, String> pngDataUris,
  Map<String, int> atlasImageWidths,
  StringBuffer keyframesBuf,
) {
  // Collect resolved frame data so we can build both the animated preview
  // and the individual static thumbnails in one pass.
  final resolved =
      <
        ({
          int x,
          int y,
          int w,
          int h,
          int scale,
          int bgW,
          String pngFile,
          String name,
        })
      >[];

  for (var fi = 0; fi < frameCount; fi++) {
    final frameName = spriteFrameName(
      sheetTypeName: sheetName,
      groupIndex: groupIdx,
      frameIndex: fi,
    );

    var found = false;
    for (final (_, pngFile) in atlasCandidates) {
      final frames = atlasFrames[pngFile];
      if (frames == null || !pngDataUris.containsKey(pngFile)) continue;

      final frameData = frames[frameName] as Map<String, dynamic>?;
      if (frameData == null) continue;

      final f = frameData['frame'] as Map<String, dynamic>;
      final x = (f['x'] as num).toInt();
      final y = (f['y'] as num).toInt();
      final w = (f['w'] as num).toInt();
      final h = (f['h'] as num).toInt();

      if (w <= 0 || h <= 0) continue;

      final scale = (w < 24 && h < 24) ? 3 : 2;
      final imgW = atlasImageWidths[pngFile] ?? 320;
      final bgW = imgW * scale;

      resolved.add((
        x: x,
        y: y,
        w: w,
        h: h,
        scale: scale,
        bgW: bgW,
        pngFile: pngFile,
        name: frameName,
      ));
      found = true;
      break;
    }

    if (!found) {
      // Placeholder for missing frame – use sentinel values.
      resolved.add((
        x: 0,
        y: 0,
        w: 0,
        h: 0,
        scale: 0,
        bgW: 0,
        pngFile: '',
        name: frameName,
      ));
    }
  }

  if (resolved.isEmpty) {
    return '<span style="color:#666">—</span>';
  }

  final parts = <String>[];

  // --- Animated preview for multi-frame groups ---
  if (resolved.length > 1) {
    // Find the maximum frame dimensions for the animation container.
    var maxW = 0;
    var maxH = 0;
    String? animPng;
    var animBgW = 320;
    for (final r in resolved) {
      if (r.w <= 0) continue;
      final dw = r.w * r.scale;
      final dh = r.h * r.scale;
      if (dw > maxW) maxW = dw;
      if (dh > maxH) maxH = dh;
      animPng ??= r.pngFile;
      animBgW = r.bgW;
    }

    if (maxW > 0 && animPng != null) {
      final sheetKey = normaliseSheetName(sheetName);
      final animName = 'anim-$sheetKey-$groupIdx';
      final durationMs = resolved.length * 200; // 200 ms per frame

      // Build @keyframes rule with steps(1) for crisp switching.
      keyframesBuf.writeln('@keyframes $animName {');
      for (var i = 0; i < resolved.length; i++) {
        final r = resolved[i];
        final pct = (i * 100.0 / resolved.length).toStringAsFixed(2);
        if (r.w > 0) {
          keyframesBuf.writeln(
            '  $pct% { background-position: -${r.x * r.scale}px -${r.y * r.scale}px; }',
          );
        }
      }
      keyframesBuf.writeln('}');

      // First resolved frame as initial position.
      final first = resolved.firstWhere(
        (r) => r.w > 0,
        orElse: () => resolved.first,
      );

      parts.add(
        '<div class="sprite-box ${_pngCssClass(animPng)}" style="'
        'width:${maxW}px;height:${maxH}px;'
        'background-position:-${first.x * first.scale}px -${first.y * first.scale}px;'
        'background-size:${animBgW}px auto;'
        'animation: $animName ${durationMs}ms steps(1) infinite;'
        '" title="animated (${resolved.length} frames)"></div>',
      );

      // Visual separator between animated preview and static frames.
      parts.add('<span style="color:#555;margin:0 4px">│</span>');
    }
  }

  // --- Static thumbnails for every frame ---
  for (final r in resolved) {
    if (r.w <= 0) {
      parts.add('<span style="color:#666" title="${r.name}">?</span>');
      continue;
    }
    final displayW = r.w * r.scale;
    final displayH = r.h * r.scale;
    parts.add(
      '<div class="sprite-box ${_pngCssClass(r.pngFile)}" style="'
      'width:${displayW}px;height:${displayH}px;'
      'background-position:-${r.x * r.scale}px -${r.y * r.scale}px;'
      'background-size:${r.bgW}px auto;'
      '" title="${r.name} ${r.w}x${r.h}"></div>',
    );
  }

  return parts.join(' ');
}

/// Escapes text for safe HTML insertion.
String _htmlEscape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// Converts a PNG filename to a CSS class name (e.g. `junarmy.png` → `atlas-junarmy`).
String _pngCssClass(String pngFile) =>
    'atlas-${p.basenameWithoutExtension(pngFile)}';

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
