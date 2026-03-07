import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

const Map<String, String> fileMapping = {
  'all02.voc': 'tank_engine.wav',
  'all04.voc': 'helicopter_idle.wav',
  'all05.voc': 'explosion_1.wav',
  'all06.voc': 'explosion_2.wav',
  'all07.voc': 'explosion_3.wav',
  'all08.voc': 'explosion_4.wav',
  'all11.voc': 'death_1.wav',
  'all12.voc': 'death_2.wav',
  'all13.voc': 'death_3.wav',
  'all15.voc': 'grenade_explosion.wav',
  'all16.voc': 'gunshot_low.wav',
  'all17.voc': 'gunshot_impact.wav',
  'all20.voc': 'death_4.wav',
  'all21.voc': 'death_5.wav',
  'all22.voc': 'death_6.wav',
  'all46.voc': 'missile_launch.wav',
  'all51.voc': 'helicopter_rotor_1.wav',
  'all52.voc': 'helicopter_rotor_2.wav',
  'all53.voc': 'helicopter_rotor_3.wav',
  'all54.voc': 'helicopter_rotor_4.wav',
  'all56.voc': 'jeep_engine_1.wav',
  'all57.voc': 'jeep_engine_2.wav',
  'all58.voc': 'jeep_engine_3.wav',
  'all59.voc': 'jeep_engine_4.wav',
  'jun26.voc': 'jungle_bird.wav',
  'ice26.voc': 'ice_bird.wav',
  'ice30.voc': 'seal_footstep.wav',
  'ice31.voc': 'ice_ambience.wav',
  'mor26.voc': 'moor_bird.wav',
  'int26.voc': 'interior_bird.wav',
};

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'input',
      abbr: 'i',
      help: 'Input directory containing .VOC files',
      mandatory: true,
    )
    ..addOption(
      'output',
      abbr: 'o',
      help: 'Output directory for converted audio files',
      defaultsTo: '../fodder_assets/assets/cf1/audio',
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
      print('Converts Cannon Fodder .VOC audio files to .WAV format.\n');
      print('Usage: dart run bin/audio.dart [options]\n');
      print(parser.usage);
      exit(0);
    }

    final inputDir = Directory(results['input'] as String);
    final outputDir = Directory(results['output'] as String);

    if (!inputDir.existsSync()) {
      print('Error: Input directory does not exist.');
      exit(1);
    }

    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    print('Converting ${fileMapping.length} voice files...');
    for (final entry in fileMapping.entries) {
      final inputFile = File(p.join(inputDir.path, entry.key));
      final outputFile = File(p.join(outputDir.path, entry.value));

      if (!inputFile.existsSync()) {
        print(
          'Warning: Expected file ${entry.key} not found in input directory.',
        );
        continue;
      }

      print('Converting ${entry.key} -> ${entry.value} ...');

      final result = await Process.run('ffmpeg', [
        '-y', // Overwrite output files without asking
        '-i', inputFile.path,
        outputFile.path,
      ]);

      if (result.exitCode != 0) {
        print('Error converting \${entry.key}:');
        print(result.stderr);
      }
    }

    print('Audio conversion complete.');
  } on FormatException catch (e) {
    print('Error: $e\n');
    print(parser.usage);
    exit(1);
  }
}
