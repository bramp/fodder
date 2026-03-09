import 'dart:io';

import 'package:args/args.dart';
import 'package:fodder_tools/dat_reader.dart';

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
      stdout.writeln('Extracts assets from Cannon Fodder Data Archives.\n');
      stdout.writeln('Usage: dart run tool/archive/main.dart [options]\n');
      stdout.writeln(parser.usage);
      exit(0);
    }

    final inputPath = results['input'] as String;
    final outDir = results['output'] as String;

    stdout.writeln('Input File: $inputPath');
    stdout.writeln('Output Dir: $outDir');

    final file = File(inputPath);
    if (!file.existsSync()) {
      stdout.writeln('Error: Input file does not exist.');
      exit(1);
    }

    final reader = DatReader(file)..read();

    stdout.writeln('Read ${reader.entries.length} entries from the archive.');

    if (results['extract-all'] as bool) {
      final outDirFile = Directory(outDir);
      if (!outDirFile.existsSync()) {
        outDirFile.createSync(recursive: true);
      }

      stdout.writeln('Extracting files...');
      for (final entry in reader.entries) {
        final bytes = reader.getFileBytes(entry);
        File('$outDir/${entry.filename}').writeAsBytesSync(bytes);
        stdout.writeln(
          '  -> Extracted ${entry.filename} (${bytes.length} bytes)',
        );
      }
      stdout.writeln('Extraction complete.');
    } else {
      for (final entry in reader.entries) {
        stdout.writeln(' - $entry');
      }
    }
  } on FormatException catch (e, st) {
    stdout.writeln('Error: ${parser.usage}\n$e\n$st');
    stdout.writeln('Usage: dart run tool/archive/main.dart [options]\n');
    stdout.writeln(parser.usage);
    exit(1);
  } on Exception catch (e, st) {
    stdout.writeln('Error: $e\n$st');
    stdout.writeln('Usage: dart run tool/archive/main.dart [options]\n');
    stdout.writeln(parser.usage);
    exit(1);
  }
}
