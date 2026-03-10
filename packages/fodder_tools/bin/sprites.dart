import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:fodder_tools/atlas_writer.dart';
import 'package:fodder_tools/dat_reader.dart';
import 'package:fodder_tools/image_decoder.dart';
import 'package:fodder_tools/palette.dart';
import 'package:fodder_tools/png_writer.dart';
import 'package:fodder_tools/sprite_names.dart';
import 'package:path/path.dart' as p;

// ---------------------------------------------------------------------------
// Palette metadata tables
// ---------------------------------------------------------------------------

/// Known 4-bit sprite-sheet files and their palette metadata.
///
/// Format: filename → list of (paletteOffset, colorCount, basePaletteIndex).
/// All use a 160-byte pitch (320 pixel width).
const _spriteSheets4Bit = <String, List<_PaletteSpec>>{
  'pstuff.dat': [_PaletteSpec(0xA000, 0x10, 0xF0)],
  'font.dat': [_PaletteSpec(0xA000, 0x10, 0xD0)],
  'hillbits.dat': [_PaletteSpec(0x6900, 0x10, 0xB0)],
  'rankfont.dat': [_PaletteSpec(0xA000, 0x80, 0x40)],
};

/// Known 4-bit in-game sprite-sheet files (terrain-specific).
///
/// army.dat files use palette index 0xA0.
const _armySheets = <String, _PaletteSpec>{
  'junarmy.dat': _PaletteSpec(0xD200, 0x10, 0xA0),
  'desarmy.dat': _PaletteSpec(0xD200, 0x10, 0xA0),
  'icearmy.dat': _PaletteSpec(0xD200, 0x10, 0xA0),
  'morarmy.dat': _PaletteSpec(0xD200, 0x10, 0xA0),
  'intarmy.dat': _PaletteSpec(0xD200, 0x10, 0xA0),
};

/// Copt (helicopter) sheets have two palette regions.
const _coptSheets = <String, List<_PaletteSpec>>{
  'juncopt.dat': [
    _PaletteSpec(0xD360, 0x10, 0x90),
    _PaletteSpec(0xD2A0, 0x40, 0xB0),
  ],
  'descopt.dat': [
    _PaletteSpec(0xD360, 0x10, 0x90),
    _PaletteSpec(0xD2A0, 0x40, 0xB0),
  ],
  'icecopt.dat': [
    _PaletteSpec(0xD360, 0x10, 0x90),
    _PaletteSpec(0xD2A0, 0x40, 0xB0),
  ],
  'morcopt.dat': [
    _PaletteSpec(0xD360, 0x10, 0x90),
    _PaletteSpec(0xD2A0, 0x40, 0xB0),
  ],
  'intcopt.dat': [
    _PaletteSpec(0xD360, 0x10, 0x90),
    _PaletteSpec(0xD2A0, 0x40, 0xB0),
  ],
};

/// Known 8-bit linear images with embedded palettes.
const _linear8Bit = <String, _PaletteSpec>{
  'hill.dat': _PaletteSpec(0xFA00, 0x100, 0x00),
  'morphbig.dat': _PaletteSpec(0xFA00, 0x100, 0x00),
};

/// Known planar VGA Mode X images.
const _planarModeX = <String, _PaletteSpec>{
  'cftitle.dat': _PaletteSpec(0xFA00, 0x100, 0x00),
  'sensprod.dat': _PaletteSpec(0xFA00, 0x100, 0x00),
  'virgpres.dat': _PaletteSpec(0xFA00, 0x100, 0x00),
  'won.dat': _PaletteSpec(0xFA00, 0x100, 0x00),
  '1.dat': _PaletteSpec(0xFA00, 0xD0, 0x00),
  '2.dat': _PaletteSpec(0xFA00, 0xD0, 0x00),
  '3.dat': _PaletteSpec(0xFA00, 0xD0, 0x00),
  '4.dat': _PaletteSpec(0xFA00, 0xD0, 0x00),
  '5.dat': _PaletteSpec(0xFA00, 0xD0, 0x00),
  '6.dat': _PaletteSpec(0xFA00, 0xD0, 0x00),
  '7.dat': _PaletteSpec(0xFA00, 0xD0, 0x00),
  '8.dat': _PaletteSpec(0xFA00, 0xD0, 0x00),
  '9.dat': _PaletteSpec(0xFA00, 0xD0, 0x00),
  'a.dat': _PaletteSpec(0xFA00, 0xD0, 0x00),
  'b.dat': _PaletteSpec(0xFA00, 0xD0, 0x00),
  'c.dat': _PaletteSpec(0xFA00, 0xD0, 0x00),
  'd.dat': _PaletteSpec(0xFA00, 0xD0, 0x00),
  'e.dat': _PaletteSpec(0xFA00, 0xD0, 0x00),
};

/// Tile base-block files (palette at 0xFA00, 128 colours).
const _tileBaseBlocks = <String>{
  'junbase.blk',
  'desbase.blk',
  'icebase.blk',
  'morbase.blk',
  'intbase.blk',
};

/// Tile sub-block files (reuse the palette from their matching base).
const _tileSubBlocks = <String>{
  'junsub0.blk',
  'dessub0.blk',
  'icesub0.blk',
  'morsub0.blk',
  'intsub0.blk',
  'junsub1.blk',
};

class _PaletteSpec {
  const _PaletteSpec(this.offset, this.count, this.startIndex);
  final int offset;
  final int count;
  final int startIndex;
}

// ---------------------------------------------------------------------------
// CLI entry-point
// ---------------------------------------------------------------------------

void main(List<String> arguments) {
  final parser = ArgParser()
    ..addOption(
      'dat',
      abbr: 'd',
      help: 'Path to CF_ENG.DAT archive.',
      mandatory: true,
    )
    ..addOption(
      'output',
      abbr: 'o',
      help: 'Output directory for PNGs.',
      defaultsTo: 'output',
    )
    ..addOption(
      'input',
      abbr: 'i',
      help:
          'Path to pre-extracted directory '
          '(use instead of --dat).',
    )
    ..addFlag(
      'map-tiles',
      abbr: 'm',
      help: 'Also export raw map tile blocks (base/sub blocks).',
      negatable: false,
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage.');

  final args = parser.parse(arguments);
  if (args['help'] as bool) {
    stdout.writeln('Usage: dart run tool/sprites/main.dart [options]');
    stdout.writeln(parser.usage);
    return;
  }

  final outputDir = Directory(args['output'] as String);
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  // Resolve file access — archive or pre-extracted directory.
  // TODO(bramp): Instead of these two closures, we could define an abstract
  // ArchiveProvider class with two implementations.
  final Uint8List Function(String) getFile;
  final bool Function(String) hasFile;

  final extractedPath = args['input'] as String?;
  if (extractedPath != null) {
    final dir = Directory(extractedPath);
    if (!dir.existsSync()) {
      stdout.writeln('Error: directory not found: $extractedPath');
      return;
    }
    getFile = (f) => File(p.join(dir.path, f)).readAsBytesSync();
    hasFile = (f) => File(p.join(dir.path, f)).existsSync();
  } else {
    final datFile = File(args['dat'] as String);
    if (!datFile.existsSync()) {
      stdout.writeln('Error: DAT not found: ${datFile.path}');
      return;
    }
    final reader = DatReader(datFile)..read();
    final entryMap = {for (final e in reader.entries) e.filename: e};
    getFile = (f) => reader.getFileBytes(entryMap[f]!);
    hasFile = entryMap.containsKey;
  }

  // Build copt frame regions from sprite_names.dart so the copt
  // PNG export can apply per-sprite palette correction.
  final coptRegions = _buildSpriteRegions(coptDatIngame);

  var exported = 0;

  // --- 4-bit sprite sheets ---
  for (final entry in _spriteSheets4Bit.entries) {
    if (!hasFile(entry.key)) continue;
    exported += _export4Bit(
      entry.key,
      getFile(entry.key),
      entry.value,
      outputDir,
      label: '4-bit',
    );
  }

  // --- Army sheets (4-bit) ---
  for (final entry in _armySheets.entries) {
    if (!hasFile(entry.key)) continue;
    exported += _export4Bit(
      entry.key,
      getFile(entry.key),
      [entry.value],
      outputDir,
      label: '4-bit army',
    );
  }

  // --- Copt sheets (4-bit, dual palette) ---
  for (final entry in _coptSheets.entries) {
    if (!hasFile(entry.key)) continue;
    exported += _export4Bit(
      entry.key,
      getFile(entry.key),
      entry.value,
      outputDir,
      label: '4-bit copt',
      spriteRegions: coptRegions,
    );
  }

  // --- 8-bit linear images ---
  for (final entry in _linear8Bit.entries) {
    if (!hasFile(entry.key)) continue;
    exported += _export8BitLinear(
      entry.key,
      getFile(entry.key),
      entry.value,
      outputDir,
    );
  }

  // --- Planar Mode X images ---
  for (final entry in _planarModeX.entries) {
    if (!hasFile(entry.key)) continue;
    exported += _exportPlanarModeX(
      entry.key,
      getFile(entry.key),
      entry.value,
      outputDir,
    );
  }

  // --- Map tile blocks ---
  if (args['map-tiles'] as bool) {
    // --- Tile base blocks ---
    for (final filename in _tileBaseBlocks) {
      if (!hasFile(filename)) continue;
      exported += _exportTile(
        filename,
        getFile(filename),
        null,
        outputDir,
        label: 'tile base',
      );
    }

    // --- Tile sub blocks ---
    for (final filename in _tileSubBlocks) {
      if (!hasFile(filename)) continue;
      final prefix = filename.substring(0, 3);
      final baseFilename = '${prefix}base.blk';
      if (!hasFile(baseFilename)) continue;
      exported += _exportTile(
        filename,
        getFile(filename),
        getFile(baseFilename),
        outputDir,
        label: 'tile sub',
      );
    }
  }

  stdout.writeln('Exported $exported images to ${outputDir.path}');

  // --- Sprite atlas JSONs ---
  _exportSpriteAtlases(hasFile: hasFile, outputDir: outputDir);
}

// ---------------------------------------------------------------------------
// Export helpers
// ---------------------------------------------------------------------------

int _export4Bit(
  String filename,
  Uint8List data,
  List<_PaletteSpec> specs,
  Directory outputDir, {
  required String label,
  List<_SpriteRegion>? spriteRegions,
}) {
  final palette = Palette();
  for (final spec in specs) {
    palette.load(
      data: data,
      offset: spec.offset,
      count: spec.count,
      startIndex: spec.startIndex,
    );
  }
  final firstSpec = specs.first;
  final pixels = decode4Bit(
    data: data,
    palette: palette,
    basePaletteIndex: firstSpec.startIndex,
    paletteOffset: firstSpec.offset,
  );
  const width = 320;
  final height = pixels.length ~/ width;

  // Fix up sprites that use a different palette than the base.
  // For multi-palette sheets (e.g. copt), each sprite region stores its own
  // paletteIndex. Re-decode regions whose paletteIndex differs from the
  // base used for the initial full-sheet decode.
  assert(
    specs.length <= 1 || spriteRegions != null,
    'Multi-palette sheets require spriteRegions for correct decoding.',
  );
  if (spriteRegions != null && specs.length > 1) {
    for (final region in spriteRegions) {
      if (region.paletteIndex == firstSpec.startIndex) continue;
      if (region.width <= 0 || region.height <= 0) continue;

      final fx = region.pixelX;
      final fy = region.pixelY;
      if (fy + region.height > height) continue;

      // Re-decode this sprite's pixels with its correct palette.
      final bytesPerRow = region.width ~/ 2;
      final startRow = region.byteOffset ~/ 160;
      final startCol = region.byteOffset % 160;

      for (var y = 0; y < region.height; y++) {
        final rowOffset = (startRow + y) * 160 + startCol;
        var dst = (fy + y) * width + fx;
        for (var b = 0; b < bytesPerRow; b++) {
          final byte = data[rowOffset + b];
          pixels[dst++] = palette.resolve4Bit(
            (byte >> 4) & 0x0F,
            region.paletteIndex,
          );
          pixels[dst++] = palette.resolve4Bit(byte & 0x0F, region.paletteIndex);
        }
      }
    }
  }

  // TODO(bramp): The follow encode + save can be refactored into a function
  // since it's repeated in all export types.
  final png = encodePng(pixels: pixels, width: width, height: height);
  final outPath = p.join(
    outputDir.path,
    '${p.basenameWithoutExtension(filename)}.png',
  );
  File(outPath).writeAsBytesSync(png);
  stdout.writeln('  $outPath (${width}x$height, $label)');
  return 1;
}

int _export8BitLinear(
  String filename,
  Uint8List data,
  _PaletteSpec spec,
  Directory outputDir,
) {
  final expectedSize = spec.offset + spec.count * 3;
  if (data.length != expectedSize) {
    stdout.writeln(
      '  Warning: $filename size mismatch. Expected $expectedSize bytes, got ${data.length}.',
    );
  }

  final palette = Palette()
    ..load(
      data: data,
      offset: spec.offset,
      count: spec.count,
      startIndex: spec.startIndex,
    );
  final pixelCount = spec.offset;
  final pixels = decode8Bit(
    data: data,
    palette: palette,
    pixelCount: pixelCount,
  );
  const width = 320;
  final height = pixelCount ~/ width;
  final png = encodePng(pixels: pixels, width: width, height: height);
  final outPath = p.join(
    outputDir.path,
    '${p.basenameWithoutExtension(filename)}.png',
  );
  File(outPath).writeAsBytesSync(png);
  stdout.writeln('  $outPath (${width}x$height, 8-bit linear)');
  return 1;
}

int _exportPlanarModeX(
  String filename,
  Uint8List data,
  _PaletteSpec spec,
  Directory outputDir,
) {
  if (data.length < spec.offset + spec.count * 3) {
    stdout.writeln(
      '  Warning: $filename size too small. Expected at least ${spec.offset + spec.count * 3} bytes, got ${data.length}.',
    );
  }

  final palette = Palette()
    ..load(
      data: data,
      offset: spec.offset,
      count: spec.count,
      startIndex: spec.startIndex,
    );
  final pixels = decodePlanar(data: data, palette: palette);
  const width = 320;
  const height = 200;
  final png = encodePng(pixels: pixels, width: width, height: height);
  final outPath = p.join(
    outputDir.path,
    '${p.basenameWithoutExtension(filename)}.png',
  );
  File(outPath).writeAsBytesSync(png);
  stdout.writeln('  $outPath (${width}x$height, planar Mode X)');
  return 1;
}

int _exportTile(
  String filename,
  Uint8List data,
  Uint8List? basePaletteData,
  Directory outputDir, {
  required String label,
}) {
  const standardSize = 0xFD00; // 64000 pixels (0xFA00) + 256 colors (0x300)
  if (data.length != standardSize) {
    stdout.writeln(
      '  Warning: $filename size mismatch. Expected $standardSize bytes, got ${data.length}.',
    );
    return 0;
  }

  final palSrc = basePaletteData ?? data;
  final palette = Palette();
  palette.load(data: palSrc, offset: 0xFA00, count: 0x100);

  // Use the available data as pixels, up to the standard 0xFA00 bytes.
  final pixelCount = data.length < 0xFA00 ? data.length : 0xFA00;
  final pixels = decode8Bit(
    data: data,
    palette: palette,
    pixelCount: pixelCount,
  );
  const width = 320;
  final height = pixelCount ~/ width;
  if (height == 0) return 0;

  final png = encodePng(pixels: pixels, width: width, height: height);
  final outPath = p.join(
    outputDir.path,
    '${p.basenameWithoutExtension(filename)}.png',
  );
  File(outPath).writeAsBytesSync(png);
  stdout.writeln('  $outPath (${width}x$height, $label)');
  return 1;
}

// ---------------------------------------------------------------------------
// Sprite atlas generation (TexturePacker JSON Hash format)
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Sprite region helpers
// ---------------------------------------------------------------------------

/// A lightweight region descriptor for palette fix-up in multi-palette sheets.
class _SpriteRegion {
  const _SpriteRegion(
    this.byteOffset,
    this.width,
    this.height,
    this.paletteIndex,
  );

  final int byteOffset;
  final int width;
  final int height;
  final int paletteIndex;

  int get pixelX => (byteOffset % 160) * 2;
  int get pixelY => byteOffset ~/ 160;
}

/// Flattens a [SpriteGroup] map into a list of [_SpriteRegion] for
/// palette fix-up.
List<_SpriteRegion> _buildSpriteRegions(Map<int, SpriteGroup> map) {
  final regions = <_SpriteRegion>[];
  for (final group in map.values) {
    if (group.isVariable) {
      for (final frame in group.frames) {
        regions.add(
          _SpriteRegion(frame.byteOffset, frame.w, frame.h, group.palette),
        );
      }
    } else {
      for (final offset in group.offsets) {
        regions.add(_SpriteRegion(offset, group.w, group.h, group.palette));
      }
    }
  }
  return regions;
}

// ---------------------------------------------------------------------------
// Sprite atlas generation (TexturePacker JSON Hash format)
// ---------------------------------------------------------------------------

/// Generates TexturePacker JSON atlas files alongside the already-exported
/// sprite sheet PNGs.
///
/// For each source .dat file, a companion `.json` is written next to the
/// existing `.png`. Sprite names follow the convention
/// `{sheetName}/{groupName}_{frameIndex}`.
void _exportSpriteAtlases({
  required bool Function(String) hasFile,
  required Directory outputDir,
}) {
  // Each entry maps a sprite-names table to the .dat file(s) that contain
  // its pixel data. Terrain-specific sheets (army/copt) expand to all
  // available terrain variants.
  final sources = [
    (sheet: 'ingame', map: armyDatIngame, files: _armySheets.keys),
    (sheet: 'ingame', map: coptDatIngame, files: _coptSheets.keys),
    (sheet: 'font', map: fontDatFont, files: const ['font.dat']),
    (sheet: 'briefing', map: pstuffDatBriefing, files: const ['pstuff.dat']),
    (sheet: 'hill', map: hillbitsDatHill, files: const ['hillbits.dat']),
    (sheet: 'recruit', map: hillbitsDatRecruit, files: const ['hillbits.dat']),
    (sheet: 'service', map: rankfontDatService, files: const ['rankfont.dat']),
    (sheet: 'service', map: morphbigDatService, files: const ['morphbig.dat']),
  ];

  final atlasEntries = <String, List<AtlasEntry>>{};
  final imageHeights = <String, int>{};

  for (final (:sheet, :map, :files) in sources) {
    final availableFiles = files.where(hasFile).toList();
    if (availableFiles.isEmpty) continue;

    for (final MapEntry(key: groupIndex, value: group) in map.entries) {
      final frameCount = group.frameCount;
      for (var frameIdx = 0; frameIdx < frameCount; frameIdx++) {
        final int byteOffset;
        final int w;
        final int h;
        final int anchorX;
        final int anchorY;

        if (group.isVariable) {
          final frame = group.frames[frameIdx];
          byteOffset = frame.byteOffset;
          w = frame.w;
          h = frame.h;
          anchorX = frame.anchorX;
          anchorY = frame.anchorY;
        } else {
          byteOffset = group.offsets[frameIdx];
          w = group.w;
          h = group.h;
          anchorX = 0;
          anchorY = 0;
        }

        if (w <= 0 || h <= 0) continue;

        final x = (byteOffset % 160) * 2;
        final y = byteOffset ~/ 160;
        final name = spriteFrameName(
          sheetTypeName: sheet,
          groupIndex: groupIndex,
          frameIndex: frameIdx,
        );

        for (final filename in availableFiles) {
          atlasEntries
              .putIfAbsent(filename, () => [])
              .add(
                AtlasEntry(
                  name: name,
                  x: x,
                  y: y,
                  width: w,
                  height: h,
                  anchorX: anchorX,
                  anchorY: anchorY,
                ),
              );

          final bottomEdge = y + h;
          final prev = imageHeights[filename] ?? 0;
          if (bottomEdge > prev) imageHeights[filename] = bottomEdge;
        }
      }
    }
  }

  // Write one TexturePacker JSON per source file.
  var atlasCount = 0;
  for (final entry in atlasEntries.entries) {
    final datFilename = entry.key;
    final entries = entry.value;
    final pngFilename = '${p.basenameWithoutExtension(datFilename)}.png';
    final jsonFilename = '${p.basenameWithoutExtension(datFilename)}.json';

    const imageWidth = 320;
    final imageHeight = imageHeights[datFilename] ?? 0;

    final json = generateAtlasJson(
      imageFilename: pngFilename,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      entries: entries,
    );

    final outPath = p.join(outputDir.path, jsonFilename);
    File(outPath).writeAsStringSync(json);
    stdout.writeln('  $outPath (${entries.length} sprites)');
    atlasCount++;
  }

  stdout.writeln('Generated $atlasCount atlas JSON files in ${outputDir.path}');
}
