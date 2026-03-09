import 'dart:convert';
import 'dart:io';

import 'package:fodder_tools/sprite_frame.dart';
import 'package:path/path.dart' as p;

/// Generates a self-contained HTML audit page with sprite previews.
void exportHtml(List<SpriteSheetType> sheets, Directory spriteDir) {
  if (!spriteDir.existsSync()) {
    stdout.writeln('Error: sprite directory not found: ${spriteDir.path}');
    exit(1);
  }

  final builder = _HtmlBuilder(spriteDir);
  final html = builder.build();

  const outputPath = 'sprite_audit.html';
  File(outputPath).writeAsStringSync(html);
  stdout.writeln('Wrote $outputPath (${html.length} bytes)');
}

class _HtmlBuilder {
  _HtmlBuilder(this._spriteDir);
  final Directory _spriteDir;

  String build() {
    final buf = StringBuffer();
    buf.writeln('<!DOCTYPE html>');
    buf.writeln('<html><head><meta charset="utf-8">');
    buf.writeln('<title>Sprite Output Audit</title>');
    buf.writeln('<style>');
    // Minimal reset and monospace
    buf.writeln('''
body { font-family: sans-serif; background: #1e1e1e; color: #ccc; padding: 20px; }
h1 { color: #fff; }
h2 { color: #e0e0e0; border-bottom: 1px solid #555; padding-bottom: 4px; margin-top: 40px; }
p { font-size: 0.9em; color: #aaa; }
.sprite-grid { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; margin-bottom: 8px; border-bottom: 1px solid #333; padding-bottom: 8px;}
.sprite-group-title { font-size: 14px; color: #fff; font-family: monospace; width: 300px; text-align: right; padding-right: 20px; font-weight: bold; flex-shrink: 0; word-break: break-word; }
.sprite-item {
  border: 1px solid #444;
  padding: 8px;
  background: #2a2a2a;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  min-width: 60px;
}
.sprite-name { font-size: 11px; color: #aaa; font-family: monospace; word-break: break-all; text-align: center; }
.sprite-box {
  position: relative;
  background-repeat: no-repeat;
  image-rendering: pixelated;
  outline: 1px solid rgba(255, 255, 255, 0.3);
}
.coverage-map {
  position: relative;
  margin-bottom: 24px;
  display: inline-block;
  line-height: 0;
}
.coverage-map img {
  image-rendering: pixelated;
}
body.show-anchors .anchor-dot { display: block; }
body:not(.show-anchors) .anchor-dot { display: none; }
.anchor-dot {
  position: absolute;
  width: 4px;
  height: 4px;
  background-color: red;
  border-radius: 50%;
  transform: translate(-50%, -50%);
  z-index: 10;
}
''');
    buf.writeln('</style></head><body>');
    buf.writeln('''
<script>
function toggleAnchors() {
  document.body.classList.toggle('show-anchors');
}
</script>
<button onclick="toggleAnchors()" style="position:fixed; top:10px; right:10px; z-index:100; padding:10px; background:#444; color:#fff; border:1px solid #666; cursor:pointer; border-radius:4px;">Toggle Anchors</button>
''');
    buf.writeln('<h1>Sprite Output Audit</h1>');
    buf.writeln(
      '<p>This is a direct visual render of the exported JSON texture atlases and PNGs.</p>',
    );

    final jsonFiles =
        _spriteDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'))
            .toList()
          ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

    for (final jsonFile in jsonFiles) {
      final baseName = p.basenameWithoutExtension(jsonFile.path);
      final pngPath = p.join(_spriteDir.path, '$baseName.png');
      if (!File(pngPath).existsSync()) continue;

      final pngBytes = File(pngPath).readAsBytesSync();
      final dataUri = 'data:image/png;base64,${base64Encode(pngBytes)}';
      final cssClass = 'bg-$baseName';
      buf.writeln(
        '<style>.$cssClass { background-image: url($dataUri); }</style>',
      );

      final jsonData =
          json.decode(jsonFile.readAsStringSync()) as Map<String, dynamic>;
      final frames = jsonData['frames'] as Map<String, dynamic>;
      final meta = jsonData['meta'] as Map<String, dynamic>;
      final metaSize = meta['size'] as Map<String, dynamic>;

      final imgW = (metaSize['w'] as num).toInt();
      // Using imgW directly from JSON for scaling.

      buf.writeln('<h2>$baseName.png</h2>');

      _writeCoverage(buf, dataUri, frames, imgW);
      _writeSprites(buf, cssClass, frames, imgW);
    }

    buf.writeln('</body></html>');
    return buf.toString();
  }

  void _writeCoverage(
    StringBuffer buf,
    String dataUri,
    Map<String, dynamic> frames,
    int imgW,
  ) {
    buf.writeln('<h3>Coverage Map</h3>');
    buf.writeln(
      '<p>Mapped frames are darkened, leaving untouched pixels bright. Hover mapped areas to see borders.</p>',
    );

    const scale = 2;
    final dw = imgW * scale;

    buf.writeln('<div class="coverage-map">');
    buf.writeln('  <img src="$dataUri" style="width: ${dw}px;" />');

    for (final entry in frames.entries) {
      final f = entry.value['frame'] as Map<String, dynamic>;
      final fx = (f['x'] as num).toInt() * scale;
      final fy = (f['y'] as num).toInt() * scale;
      final fw = (f['w'] as num).toInt() * scale;
      final fh = (f['h'] as num).toInt() * scale;

      buf.writeln(
        '  <div style="position: absolute; left: ${fx}px; top: ${fy}px; width: ${fw}px; height: ${fh}px; '
        'background-color: rgba(30,30,30,0.85);" '
        'title="${entry.key}" '
        'onmouseover="this.style.border=\'1px solid red\'; this.style.backgroundColor=\'transparent\';" '
        'onmouseout="this.style.border=\'none\'; this.style.backgroundColor=\'rgba(30,30,30,0.85)\';"'
        '></div>',
      );
    }
    buf.writeln('</div>');
  }

  void _writeSprites(
    StringBuffer buf,
    String cssClass,
    Map<String, dynamic> frames,
    int imgW,
  ) {
    buf.writeln('<h3>Individual Sprites (${frames.length})</h3>');

    final sortedEntries = frames.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final grouped = <String, List<MapEntry<String, dynamic>>>{};
    for (final entry in sortedEntries) {
      final key = entry.key;
      final lastUnderscore = key.lastIndexOf('_');
      final groupName = lastUnderscore != -1
          ? key.substring(0, lastUnderscore)
          : key;
      grouped.putIfAbsent(groupName, () => []).add(entry);
    }

    for (final groupEntry in grouped.entries) {
      final groupName = groupEntry.key;
      final framesList = groupEntry.value;

      buf.writeln('<div class="sprite-grid">');
      buf.writeln('<div class="sprite-group-title">$groupName</div>');

      if (framesList.length > 1) {
        var maxLeft = 0.0;
        var maxRight = 0.0;
        var maxTop = 0.0;
        var maxBottom = 0.0;

        for (final fEntry in framesList) {
          final f = fEntry.value['frame'] as Map<String, dynamic>;
          final w = (f['w'] as num).toInt();
          final h = (f['h'] as num).toInt();
          final anchor = fEntry.value['anchor'] as Map<String, dynamic>?;
          final ax = anchor != null ? (anchor['x'] as num).toDouble() : 0.5;
          final ay = anchor != null ? (anchor['y'] as num).toDouble() : 0.5;

          final left = ax * w;
          final right = (1 - ax) * w;
          final top = ay * h;
          final bottom = (1 - ay) * h;

          if (left > maxLeft) maxLeft = left;
          if (right > maxRight) maxRight = right;
          if (top > maxTop) maxTop = top;
          if (bottom > maxBottom) maxBottom = bottom;
        }

        final maxW = (maxLeft + maxRight).ceil();
        final maxH = (maxTop + maxBottom).ceil();

        if (maxW > 0 && maxH > 0) {
          final scale = (maxW < 24 && maxH < 24) ? 3 : 2;
          final dw = maxW * scale;
          final dh = maxH * scale;
          final bgW = imgW * scale;

          final anchorPxX = maxLeft * scale;
          final anchorPxY = maxTop * scale;

          final safeGroup = groupName.replaceAll(RegExp('[^a-zA-Z0-9]'), '-');
          final animName = 'anim-$safeGroup-$cssClass';

          buf.writeln('<style>');
          buf.writeln('@keyframes $animName {');
          for (var i = 0; i < framesList.length; i++) {
            final f = framesList[i].value['frame'] as Map<String, dynamic>;
            final anchor =
                framesList[i].value['anchor'] as Map<String, dynamic>?;
            final x = (f['x'] as num).toInt() * scale;
            final y = (f['y'] as num).toInt() * scale;
            final w = (f['w'] as num).toInt() * scale;
            final h = (f['h'] as num).toInt() * scale;

            final ax = anchor != null ? (anchor['x'] as num).toDouble() : 0.5;
            final ay = anchor != null ? (anchor['y'] as num).toDouble() : 0.5;

            final frameAnchorX = ax * w;
            final frameAnchorY = ay * h;

            final offsetX = anchorPxX - frameAnchorX;
            final offsetY = anchorPxY - frameAnchorY;

            final pct = (i * 100.0 / framesList.length).toStringAsFixed(2);
            buf.writeln('  $pct% {');
            buf.writeln('    background-position: -${x}px -${y}px;');
            buf.writeln('    width: ${w}px;');
            buf.writeln('    height: ${h}px;');
            buf.writeln(
              '    transform: translate(${offsetX}px, ${offsetY}px);',
            );
            buf.writeln('  }');
          }
          buf.writeln('}');
          buf.writeln('</style>');

          final durationMs = framesList.length * 200;
          buf.writeln(
            '  <div class="sprite-item" style="border-color: #666; background: #222">',
          );
          buf.writeln(
            '    <div style="position: relative; width:${dw}px; height:${dh}px; ">'
            '      <div class="sprite-box $cssClass" style="'
            'position:absolute; left:0; top:0;'
            'background-size:${bgW}px auto;'
            'animation: $animName ${durationMs}ms steps(1) infinite;'
            '" title="Animated preview"></div>'
            '      <div class="anchor-dot" style="left:${anchorPxX}px; top:${anchorPxY}px;"></div>'
            '    </div>',
          );
          buf.writeln(
            '    <div class="sprite-name" style="color:#88c">animated</div>',
          );
          buf.writeln('  </div>');

          buf.writeln(
            '<div style="width:1px; background:#444; margin:0 8px"></div>',
          );
        }
      }

      for (final entry in framesList) {
        final key = entry.key;
        final f = entry.value['frame'] as Map<String, dynamic>;
        final x = (f['x'] as num).toInt();
        final y = (f['y'] as num).toInt();
        final w = (f['w'] as num).toInt();
        final h = (f['h'] as num).toInt();

        final anchor = entry.value['anchor'] as Map<String, dynamic>?;
        final ax = anchor != null ? (anchor['x'] as num).toDouble() : 0.5;
        final ay = anchor != null ? (anchor['y'] as num).toDouble() : 0.5;

        final scale = (w < 24 && h < 24) ? 3 : 2;
        final dw = w * scale;
        final dh = h * scale;
        final bgW = imgW * scale;

        final suffix = key.substring(groupName.length);

        buf.writeln('  <div class="sprite-item">');
        buf.writeln(
          '    <div class="sprite-box $cssClass" style="'
          'width:${dw}px;height:${dh}px;'
          'background-position:-${x * scale}px -${y * scale}px;'
          'background-size:${bgW}px auto;'
          '" title="$key ${w}x$h">'
          '      <div class="anchor-dot" style="left:${ax * 100}%; top:${ay * 100}%;"></div>'
          '    </div>',
        );
        final displayName = suffix.startsWith('_')
            ? suffix.substring(1)
            : suffix;
        buf.writeln('    <div class="sprite-name">$displayName</div>');
        buf.writeln('  </div>');
      }

      buf.writeln('</div>');
    }
  }
}
