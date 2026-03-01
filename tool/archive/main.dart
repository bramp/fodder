// ignore_for_file: avoid_print, CLI tool
import 'dart:io';

import 'package:args/args.dart';
import 'lib/dat_reader.dart';

void main(List<String> arguments) {
  final parser = ArgParser()
    ..addOption(
      'input',
      abbr: 'i',
      help: 'Path to the CF_ENG.DAT or FODDER.DAT file',
      mandatory: true,
    )
    ..addOption(
      'output',
      abbr: 'o',
      help: 'Output directory for extracted files',
      defaultsTo: 'assets/extracted',
    )
    ..addFlag(
      'extract-all',
      abbr: 'e',
      help: 'Extract all decompressed files to the output directory',
      negatable: false,
    )
    ..addFlag(
      'help',
      abbr: 'h',
      help: 'Show this help message',
      negatable: false,
    );

  try {
    final results = parser.parse(arguments);

    if (results['help'] as bool) {
      print('Extracts assets from Cannon Fodder Data Archives.\n');
      print('Usage: dart run tool/archive/main.dart [options]\n');
      print(parser.usage);
      exit(0);
    }

    final inputPath = results['input'] as String;
    final outDir = results['output'] as String;

    print('Input File: $inputPath');
    print('Output Dir: $outDir');

    final file = File(inputPath);
    if (!file.existsSync()) {
      print('Error: Input file does not exist.');
      exit(1);
    }

    final reader = DatReader(file)..read();

    print('Read ${reader.entries.length} entries from the archive.');

    if (results['extract-all'] as bool) {
      final outDirFile = Directory(outDir);
      if (!outDirFile.existsSync()) {
        outDirFile.createSync(recursive: true);
      }

      print('Extracting files...');
      for (final entry in reader.entries) {
        final bytes = reader.getFileBytes(entry);
        File('$outDir/${entry.filename}').writeAsBytesSync(bytes);
        print('  -> Extracted ${entry.filename} (${bytes.length} bytes)');
      }
      print('Extraction complete.');
    } else {
      for (final entry in reader.entries) {
        print(' - $entry');
      }
    }
  } on FormatException catch (e, st) {
    print('Error: ${parser.usage}\n$e\n$st');
    print('Usage: dart run tool/archive/main.dart [options]\n');
    print(parser.usage);
    exit(1);
  } on Exception catch (e, st) {
    print('Error: $e\n$st');
    print('Usage: dart run tool/archive/main.dart [options]\n');
    print(parser.usage);
    exit(1);
  }
}
