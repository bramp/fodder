// ignore_for_file: avoid_print, CLI tool uses print for user output.

import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:fodder_tools/dat_reader.dart';
import 'package:fodder_tools/hit_reader.dart';
import 'package:fodder_tools/map_reader.dart';
import 'package:fodder_tools/tiled_writer.dart';
import 'package:fodder_tools/tileset_builder.dart';
import 'package:path/path.dart' as p;

/// Prints a warning prefixed with the current context (file being processed).
void _warn(String context, String message) {
  stderr.writeln('  [$context] $message');
}

// ---------------------------------------------------------------------------
// Terrain metadata
// ---------------------------------------------------------------------------

/// Maps terrain prefixes to a human-readable tileset name.
const _terrainNames = <String, String>{
  'jun': 'jungle',
  'des': 'desert',
  'ice': 'ice',
  'mor': 'moors',
  'int': 'interior',
};

// ---------------------------------------------------------------------------
// CLI entry-point
// ---------------------------------------------------------------------------

void main(List<String> arguments) {
  final parser = ArgParser()
    ..addOption('dat', abbr: 'd', help: 'Path to CF_ENG.DAT archive.')
    ..addOption(
      'input',
      abbr: 'i',
      help:
          'Path to pre-extracted directory '
          '(use instead of --dat).',
    )
    ..addOption(
      'output',
      abbr: 'o',
      help: 'Output directory for Tiled files.',
      defaultsTo: 'output/maps',
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage.');

  final args = parser.parse(arguments);
  if (args['help'] as bool) {
    print('Exports Cannon Fodder maps to Tiled (.tmx/.tsx) format.\n');
    print('Usage: dart run fodder_tools:maps [options]\n');
    print(parser.usage);
    return;
  }

  final outputDir = Directory(args['output'] as String);
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  // Resolve file access — archive or pre-extracted directory.
  final Uint8List Function(String) getFile;
  final bool Function(String) hasFile;
  final List<String> Function() listFiles;

  final extractedPath = args['input'] as String?;
  if (extractedPath != null) {
    final dir = Directory(extractedPath);
    if (!dir.existsSync()) {
      print('Error: directory not found: $extractedPath');
      exit(1);
    }
    getFile = (f) => File(p.join(dir.path, f)).readAsBytesSync();
    hasFile = (f) => File(p.join(dir.path, f)).existsSync();
    listFiles = () => dir
        .listSync()
        .whereType<File>()
        .map((f) => p.basename(f.path))
        .toList();
  } else {
    final datPath = args['dat'] as String?;
    if (datPath == null) {
      print('Error: Provide either --dat or --input.');
      print(parser.usage);
      exit(1);
    }
    final datFile = File(datPath);
    if (!datFile.existsSync()) {
      print('Error: DAT not found: ${datFile.path}');
      exit(1);
    }
    final reader = DatReader(datFile)..read();
    final entryMap = {for (final e in reader.entries) e.filename: e};
    getFile = (f) => reader.getFileBytes(entryMap[f]!);
    hasFile = entryMap.containsKey;
    listFiles = () => entryMap.keys.toList();
  }

  // Discover all .map files.
  final mapFiles = listFiles().where((f) => f.endsWith('.map')).toList()
    ..sort();

  if (mapFiles.isEmpty) {
    print('No .map files found.');
    exit(1);
  }

  print('Found ${mapFiles.length} map files.');

  // Cache: terrain prefix → tileset PNG already written.
  final exportedTilesets = <String, String>{};

  // Cache: base/sub block filename pair → tileset name.
  final tilesetNameByBlocks = <String, String>{};

  var mapCount = 0;

  for (final mapFilename in mapFiles) {
    final data = getFile(mapFilename);
    final map = MapData.parse(data, warn: (msg) => _warn(mapFilename, msg));

    final terrain = map.terrainPrefix;
    final baseName =
        _terrainNames[terrain] ??
        p.basenameWithoutExtension(map.baseBlockFilename);

    // Derive a suffix from the sub-block filename to distinguish variants
    // (e.g. junsub0 vs junsub1).
    final subStem = p.basenameWithoutExtension(map.subBlockFilename);
    final subSuffix = subStem.replaceFirst(RegExp('^${terrain}sub'), '');
    final tilesetName = subSuffix == '0'
        ? baseName
        : '${baseName}_sub$subSuffix';

    // Build a unique key per base+sub block combination.
    final blockKey = '${map.baseBlockFilename}|${map.subBlockFilename}';
    tilesetNameByBlocks[blockKey] ??= tilesetName;
    final resolvedName = tilesetNameByBlocks[blockKey]!;

    // Export tileset PNG + TSX once per unique block combination.
    if (!exportedTilesets.containsKey(blockKey)) {
      if (!hasFile(map.baseBlockFilename)) {
        print(
          '  Warning: base block not found: ${map.baseBlockFilename} '
          '(skipping $mapFilename)',
        );
        continue;
      }
      if (!hasFile(map.subBlockFilename)) {
        print(
          '  Warning: sub block not found: ${map.subBlockFilename} '
          '(skipping $mapFilename)',
        );
        continue;
      }

      final baseBlk = getFile(map.baseBlockFilename);
      final subBlk = getFile(map.subBlockFilename);

      final pngBytes = buildTilesetPng(
        baseBlk: baseBlk,
        subBlk: subBlk,
        warn: (msg) => _warn(resolvedName, msg),
      );
      final pngFilename = '$resolvedName.png';
      File(p.join(outputDir.path, pngFilename)).writeAsBytesSync(pngBytes);

      const imageWidth = blkColumns * tileSize; // 320
      const imageHeight = (totalTileCount ~/ blkColumns) * tileSize; // 384

      // Load .hit terrain data when available.
      final baseHitName = map.baseBlockFilename.replaceAll('.blk', '.hit');
      final subHitName = map.subBlockFilename.replaceAll('.blk', '.hit');

      List<int>? terrainTypes;
      if (hasFile(baseHitName) && hasFile(subHitName)) {
        terrainTypes = buildCombinedTerrainTypes(
          baseHitData: getFile(baseHitName),
          subHitData: getFile(subHitName),
          warn: (msg) => _warn(resolvedName, msg),
        );
      } else {
        print(
          '  Warning: .hit files not found for $resolvedName '
          '($baseHitName / $subHitName) — skipping terrain data.',
        );
      }

      final tsx = generateTsx(
        name: resolvedName,
        imageFilename: pngFilename,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        terrainTypes: terrainTypes,
        warn: (msg) => _warn(resolvedName, msg),
      );
      final tsxFilename = '$resolvedName.tsx';
      File(p.join(outputDir.path, tsxFilename)).writeAsStringSync(tsx);

      exportedTilesets[blockKey] = tsxFilename;
      print('  Tileset: $pngFilename + $tsxFilename ($resolvedName)');
    }

    // Export .tmx map.
    final tsxFilename = exportedTilesets[blockKey]!;
    final tmx = generateTmx(map: map, tilesetTsxFilename: tsxFilename);
    final tmxFilename = '${p.basenameWithoutExtension(mapFilename)}.tmx';
    File(p.join(outputDir.path, tmxFilename)).writeAsStringSync(tmx);
    mapCount++;
  }

  print('Exported $mapCount maps to ${outputDir.path}');
}
