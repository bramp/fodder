// ignore_for_file: avoid_print, CLI tool uses print for user output.

import 'package:fodder_tools/sprite_frame.dart';
import 'package:fodder_tools/sprite_names.dart';

/// A pixel rectangle with metadata about which frame produced it.
typedef FrameRect = ({
  int x,
  int y,
  int w,
  int h,
  String sheetName,
  int groupIdx,
  int frameIdx,
  String label,
});

/// Reports frame overlaps and uncovered pixel regions per .dat file.
void exportCoverage(List<SpriteSheetType> sheets) {
  // Collect all frames grouped by .dat filename.
  // Multiple GfxTypes can share the same .dat file (e.g. hill & recruit both
  // use hillbits.dat), so we group by filename to detect cross-sheet overlaps.
  final byDatFile = <String, List<FrameRect>>{};
  final gfxForDat = <String, GfxType>{};
  final seenSheets = <String>{};

  for (final sheet in sheets) {
    final key = normaliseSheetName(sheet.name);
    // Skip duplicate normalised sheets (e.g. InGame_CF1 / InGame_CF2).
    if (!seenSheets.add(key)) continue;
    final combined = dartMapForSheet(sheet);
    if (combined == null) continue;

    for (var gi = 0; gi < sheet.entries.length; gi++) {
      final cppFrames = sheet.entries[gi];
      for (var fi = 0; fi < cppFrames.length; fi++) {
        final f = cppFrames[fi];
        if (f.width <= 0 || f.height <= 0) continue;

        final dartGroup = combined[gi];
        final dartName = dartGroup?.name ?? '?';
        final label = '$key[$gi:$fi] $dartName';
        final datFile = f.gfxType.datFileName;

        gfxForDat.putIfAbsent(datFile, () => f.gfxType);
        byDatFile.putIfAbsent(datFile, () => []).add((
          x: f.pixelX(),
          y: f.pixelY(),
          w: f.width,
          h: f.height,
          sheetName: key,
          groupIdx: gi,
          frameIdx: fi,
          label: label,
        ));
      }
    }
  }

  for (final datFile in byDatFile.keys.toList()..sort()) {
    final rects = byDatFile[datFile]!;
    print('=== $datFile (${rects.length} frames) ===\n');

    _reportOverlaps(rects);
    _reportGaps(rects);
    print('');
  }
}

/// Reports groups of frames that share the exact same pixel rectangle.
void _reportOverlaps(List<FrameRect> rects) {
  // Group by (x, y, w, h) to find exact duplicates.
  final byRect = <(int, int, int, int), List<FrameRect>>{};
  for (final r in rects) {
    byRect.putIfAbsent((r.x, r.y, r.w, r.h), () => []).add(r);
  }

  final exactDups = <(int, int, int, int), List<FrameRect>>{};
  for (final entry in byRect.entries) {
    if (entry.value.length > 1) {
      exactDups[entry.key] = entry.value;
    }
  }

  if (exactDups.isEmpty) {
    print('  No duplicate frames.\n');
  } else {
    print('  Duplicate frames (identical pixel rectangle):');
    for (final entry in exactDups.entries) {
      final (x, y, w, h) = entry.key;
      print('    rect ($x,$y ${w}x$h):');
      for (final r in entry.value) {
        print('      ${r.label}');
      }
    }
    print('');
  }

  // Find partial overlaps (different rect but intersecting pixels).
  final uniqueRects = byRect.entries.toList();
  final partialOverlaps = <String>[];
  for (var i = 0; i < uniqueRects.length; i++) {
    final (ax, ay, aw, ah) = uniqueRects[i].key;
    for (var j = i + 1; j < uniqueRects.length; j++) {
      final (bx, by, bw, bh) = uniqueRects[j].key;
      // Check AABB intersection.
      if (ax < bx + bw && ax + aw > bx && ay < by + bh && ay + ah > by) {
        final aLabel = uniqueRects[i].value.first.label;
        final bLabel = uniqueRects[j].value.first.label;
        partialOverlaps.add(
          '    ($ax,$ay ${aw}x$ah) ${aLabel} ∩ '
          '($bx,$by ${bw}x$bh) $bLabel',
        );
      }
    }
  }

  if (partialOverlaps.isNotEmpty) {
    print('  Partial overlaps (intersecting but different rects):');
    for (final line in partialOverlaps) {
      print(line);
    }
    print('');
  }
}

/// Reports pixel regions not covered by any frame.
void _reportGaps(List<FrameRect> rects) {
  if (rects.isEmpty) return;

  var maxY = 0;
  for (final r in rects) {
    final bottom = r.y + r.h;
    if (bottom > maxY) maxY = bottom;
  }

  const sheetW = 320;
  final sheetH = maxY;
  final totalPixels = sheetW * sheetH;

  if (totalPixels <= 0) return;

  // Build a coverage bitmap.
  final covered = List.filled(totalPixels, false);
  for (final r in rects) {
    for (var row = r.y; row < r.y + r.h && row < sheetH; row++) {
      for (var col = r.x; col < r.x + r.w && col < sheetW; col++) {
        covered[row * sheetW + col] = true;
      }
    }
  }

  final coveredCount = covered.where((b) => b).length;
  final pct = (coveredCount * 100.0 / totalPixels).toStringAsFixed(1);
  print(
    '  Coverage: $coveredCount / $totalPixels pixels '
    '($pct%) in ${sheetW}x$sheetH sheet',
  );

  // Find uncovered horizontal runs (gaps) for a compact summary.
  final gapRuns = <({int y, int x, int w})>[];
  for (var row = 0; row < sheetH; row++) {
    var col = 0;
    while (col < sheetW) {
      if (!covered[row * sheetW + col]) {
        final startCol = col;
        while (col < sheetW && !covered[row * sheetW + col]) {
          col++;
        }
        gapRuns.add((y: row, x: startCol, w: col - startCol));
      } else {
        col++;
      }
    }
  }

  if (gapRuns.isEmpty) {
    print('  No uncovered pixels.\n');
    return;
  }

  // Merge consecutive full-width gap rows into ranges.
  final fullWidthGaps = <({int startY, int endY})>[];
  int? gapStart;
  for (var row = 0; row < sheetH; row++) {
    final isFullGap = !covered
        .sublist(row * sheetW, (row + 1) * sheetW)
        .any((b) => b);
    if (isFullGap) {
      gapStart ??= row;
    } else {
      if (gapStart != null) {
        fullWidthGaps.add((startY: gapStart, endY: row - 1));
        gapStart = null;
      }
    }
  }
  if (gapStart != null) {
    fullWidthGaps.add((startY: gapStart, endY: sheetH - 1));
  }

  if (fullWidthGaps.isNotEmpty) {
    print('  Uncovered full rows:');
    for (final gap in fullWidthGaps) {
      if (gap.startY == gap.endY) {
        print('    row ${gap.startY}');
      } else {
        print('    rows ${gap.startY}–${gap.endY}');
      }
    }
  }

  // Count partial-row gaps (rows with some but not all pixels uncovered).
  final partialGapRows = <int>{};
  for (final g in gapRuns) {
    if (g.w < sheetW) {
      partialGapRows.add(g.y);
    }
  }
  if (partialGapRows.isNotEmpty) {
    print('  ${partialGapRows.length} rows with partial gaps');
  }
}
