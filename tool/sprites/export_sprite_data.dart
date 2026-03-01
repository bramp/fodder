// ignore_for_file: avoid_print, CLI tool uses print for user output.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'lib/sprite_data_parser.dart';

/// Exports OpenFodder sprite sheet metadata to JSON files.
/// These files can be bundled with the game to avoid parsing the C++ header
/// at runtime or during standard builds.
void main() {
  final scriptDir = File(Platform.script.toFilePath()).parent.path;
  final projectRoot = p.dirname(p.dirname(scriptDir));

  // Path to the OpenFodder C++ header file.
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

  print('Parsing sprite data from ${spriteDataFile.path}...');
  final sheets = SpriteDataParser.parse(file: spriteDataFile);

  const outputDir = 'tool/sprites/data';
  final outputDirFile = Directory(p.join(projectRoot, outputDir));
  if (!outputDirFile.existsSync()) {
    outputDirFile.createSync(recursive: true);
  }

  const encoder = JsonEncoder.withIndent('  ');

  for (final sheet in sheets) {
    final fileName = 'sprite_sheet_${sheet.name.toLowerCase()}.json';
    final outputFile = File(p.join(outputDirFile.path, fileName));

    print('Writing ${outputFile.path}...');
    outputFile.writeAsStringSync(encoder.convert(sheet.toJson()));
  }

  print('Done! Exported ${sheets.length} sprite sheets.');
}
