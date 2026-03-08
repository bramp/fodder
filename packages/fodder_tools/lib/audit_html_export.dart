// ignore_for_file: avoid_print, CLI tool uses print for user output.

import 'dart:convert';
import 'dart:io';

import 'package:fodder_tools/sprite_frame.dart';
import 'package:fodder_tools/sprite_names.dart';
import 'package:path/path.dart' as p;

/// Maps a normalised sheet name to the representative atlas files to use.
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

/// Generates a self-contained HTML audit page with sprite previews.
void exportHtml(List<SpriteSheetType> sheets, Directory spriteDir) {
  if (!spriteDir.existsSync()) {
    print('Error: sprite directory not found: ${spriteDir.path}');
    exit(1);
  }

  final builder = _HtmlBuilder(spriteDir);
  final html = builder.build(sheets);

  final outputPath = 'sprite_audit.html';
  File(outputPath).writeAsStringSync(html);
  print('Wrote $outputPath (${html.length} bytes)');
}

/// Encapsulates atlas loading and HTML generation state.
class _HtmlBuilder {
  _HtmlBuilder(this._spriteDir);

  final Directory _spriteDir;

  final _pngDataUris = <String, String>{};
  final _atlasFrames = <String, Map<String, dynamic>>{};
  final _atlasImageWidths = <String, int>{};
  final _keyframesBuf = StringBuffer();

  String build(List<SpriteSheetType> sheets) {
    _loadAtlases();

    final buf = StringBuffer();
    _writeHead(buf);

    for (final sheet in sheets) {
      _writeSheet(buf, sheet);
    }

    buf.writeln('</body></html>');

    // Inject collected @keyframes rules into the style block.
    return buf.toString().replaceFirst(
      '/* KEYFRAMES_PLACEHOLDER */',
      _keyframesBuf.toString(),
    );
  }

  void _loadAtlases() {
    for (final files in _sheetAtlasFiles.values) {
      for (final (jsonFile, pngFile) in files) {
        if (_pngDataUris.containsKey(pngFile)) continue;

        final pngPath = p.join(_spriteDir.path, pngFile);
        final jsonPath = p.join(_spriteDir.path, jsonFile);

        if (!File(pngPath).existsSync() || !File(jsonPath).existsSync()) {
          continue;
        }

        final pngBytes = File(pngPath).readAsBytesSync();
        _pngDataUris[pngFile] =
            'data:image/png;base64,${base64Encode(pngBytes)}';

        final jsonData =
            json.decode(File(jsonPath).readAsStringSync())
                as Map<String, dynamic>;
        _atlasFrames[pngFile] = jsonData['frames'] as Map<String, dynamic>;

        final meta = jsonData['meta'] as Map<String, dynamic>?;
        final metaSize = meta?['size'] as Map<String, dynamic>?;
        _atlasImageWidths[pngFile] = (metaSize?['w'] as num?)?.toInt() ?? 320;
      }
    }
  }

  void _writeHead(StringBuffer buf) {
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

    for (final entry in _pngDataUris.entries) {
      final cssClass = _pngCssClass(entry.key);
      buf.writeln('.${cssClass} { background-image: url(${entry.value}); }');
    }

    buf.writeln('/* KEYFRAMES_PLACEHOLDER */');
    buf.writeln('</style></head><body>');
    buf.writeln('<h1>Sprite Names Audit</h1>');
  }

  void _writeSheet(StringBuffer buf, SpriteSheetType sheet) {
    final key = normaliseSheetName(sheet.name);
    final combined = dartMapForSheet(sheet);
    if (combined == null) return;

    final atlasCandidates = _sheetAtlasFiles[key] ?? [];

    final datFiles =
        sheet.entries
            .expand((e) => e)
            .map((f) => f.gfxType.datFileName)
            .toSet()
            .toList()
          ..sort();
    final datSuffix = datFiles.isNotEmpty ? ' (${datFiles.join(', ')})' : '';

    buf.writeln('<h2>${_htmlEscape(sheet.name)}$datSuffix</h2>');
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

      final firstCpp = cppFrames.first;
      final sizeStr = '${firstCpp.width}×${firstCpp.height}';

      final spriteHtml = _spritePreviewHtml(
        sheet.name,
        groupIdx,
        frameCount,
        atlasCandidates,
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

  /// Builds inline HTML for all frames of a sprite group, with an animated
  /// preview for multi-frame groups.
  String _spritePreviewHtml(
    String sheetName,
    int groupIdx,
    int frameCount,
    List<(String json, String png)> atlasCandidates,
  ) {
    final resolved = <_ResolvedFrame>[];

    for (var fi = 0; fi < frameCount; fi++) {
      final frameName = spriteFrameName(
        sheetTypeName: sheetName,
        groupIndex: groupIdx,
        frameIndex: fi,
      );
      resolved.add(_resolveFrame(frameName, atlasCandidates));
    }

    if (resolved.isEmpty) {
      return '<span style="color:#666">—</span>';
    }

    final parts = <String>[];

    // Animated preview for multi-frame groups.
    if (resolved.length > 1) {
      _buildAnimatedPreview(parts, resolved, sheetName, groupIdx);
    }

    // Static thumbnails for every frame.
    for (final r in resolved) {
      if (r.w <= 0) {
        parts.add('<span style="color:#666" title="${r.name}">?</span>');
        continue;
      }
      final dw = r.w * r.scale;
      final dh = r.h * r.scale;
      parts.add(
        '<div class="sprite-box ${_pngCssClass(r.pngFile)}" style="'
        'width:${dw}px;height:${dh}px;'
        'background-position:-${r.x * r.scale}px -${r.y * r.scale}px;'
        'background-size:${r.bgW}px auto;'
        '" title="${r.name} ${r.w}x${r.h}"></div>',
      );
    }

    return parts.join(' ');
  }

  _ResolvedFrame _resolveFrame(
    String frameName,
    List<(String json, String png)> atlasCandidates,
  ) {
    for (final (_, pngFile) in atlasCandidates) {
      final frames = _atlasFrames[pngFile];
      if (frames == null || !_pngDataUris.containsKey(pngFile)) continue;

      final frameData = frames[frameName] as Map<String, dynamic>?;
      if (frameData == null) continue;

      final f = frameData['frame'] as Map<String, dynamic>;
      final w = (f['w'] as num).toInt();
      final h = (f['h'] as num).toInt();
      if (w <= 0 || h <= 0) continue;

      final scale = (w < 24 && h < 24) ? 3 : 2;
      final imgW = _atlasImageWidths[pngFile] ?? 320;

      return _ResolvedFrame(
        x: (f['x'] as num).toInt(),
        y: (f['y'] as num).toInt(),
        w: w,
        h: h,
        scale: scale,
        bgW: imgW * scale,
        pngFile: pngFile,
        name: frameName,
      );
    }

    // Placeholder for missing frame.
    return _ResolvedFrame(
      x: 0,
      y: 0,
      w: 0,
      h: 0,
      scale: 0,
      bgW: 0,
      pngFile: '',
      name: frameName,
    );
  }

  void _buildAnimatedPreview(
    List<String> parts,
    List<_ResolvedFrame> resolved,
    String sheetName,
    int groupIdx,
  ) {
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

    if (maxW <= 0 || animPng == null) return;

    final sheetKey = normaliseSheetName(sheetName);
    final animName = 'anim-$sheetKey-$groupIdx';
    final durationMs = resolved.length * 200;

    _keyframesBuf.writeln('@keyframes $animName {');
    for (var i = 0; i < resolved.length; i++) {
      final r = resolved[i];
      final pct = (i * 100.0 / resolved.length).toStringAsFixed(2);
      if (r.w > 0) {
        _keyframesBuf.writeln(
          '  $pct% { background-position: '
          '-${r.x * r.scale}px -${r.y * r.scale}px; }',
        );
      }
    }
    _keyframesBuf.writeln('}');

    final first = resolved.firstWhere(
      (r) => r.w > 0,
      orElse: () => resolved.first,
    );

    parts.add(
      '<div class="sprite-box ${_pngCssClass(animPng)}" style="'
      'width:${maxW}px;height:${maxH}px;'
      'background-position:-${first.x * first.scale}px '
      '-${first.y * first.scale}px;'
      'background-size:${animBgW}px auto;'
      'animation: $animName ${durationMs}ms steps(1) infinite;'
      '" title="animated (${resolved.length} frames)"></div>',
    );

    parts.add('<span style="color:#555;margin:0 4px">│</span>');
  }
}

/// A resolved atlas frame with display metrics.
class _ResolvedFrame {
  const _ResolvedFrame({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.scale,
    required this.bgW,
    required this.pngFile,
    required this.name,
  });

  final int x, y, w, h, scale, bgW;
  final String pngFile, name;
}

String _htmlEscape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _pngCssClass(String pngFile) =>
    'atlas-${p.basenameWithoutExtension(pngFile)}';
