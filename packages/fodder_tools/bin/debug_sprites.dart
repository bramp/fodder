import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('json', abbr: 'j', help: 'Path to the atlas JSON file')
    ..addOption('image', abbr: 'i', help: 'Path to the sprite sheet PNG')
    ..addOption('output', abbr: 'o', help: 'Output path for the debug image')
    ..addOption(
      'cols',
      abbr: 'c',
      defaultsTo: '8',
      help: 'Number of columns in the contact sheet',
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help');

  final results = parser.parse(arguments);

  if (results['help'] == true ||
      results['json'] == null ||
      results['image'] == null) {
    print(
      'Usage: dart run debug_sprites.dart -j <atlas.json> -i <sheet.png> -o <debug.png>',
    );
    print(parser.usage);
    return;
  }

  final jsonPath = results['json'] as String;
  final imagePath = results['image'] as String;
  final outputPath =
      results['output'] ?? p.setExtension(jsonPath, '.debug.png');
  final cols = int.parse(results['cols'] as String);

  print('Reading atlas: $jsonPath');
  final jsonFile = File(jsonPath);
  final atlasData =
      json.decode(await jsonFile.readAsString()) as Map<String, dynamic>;
  final frames = atlasData['frames'] as Map<String, dynamic>;

  print('Reading image: $imagePath');
  final bytes = await File(imagePath).readAsBytes();
  final sourceImg = img.decodePng(bytes);
  if (sourceImg == null) {
    print('Error: Could not decode PNG at $imagePath');
    return;
  }

  print('Creating contact sheet...');
  final sortedNames = frames.keys.toList()..sort();
  final totalSprites = sortedNames.length;
  final rows = (totalSprites / cols).ceil();

  const cellWidth = 160;
  const cellHeight = 40;
  const padding = 5;

  final debugImg = img.Image(
    width: cols * cellWidth,
    height: rows * cellHeight,
    numChannels: 4,
  );
  img.fill(debugImg, color: img.ColorRgba8(255, 255, 255, 255));

  for (var i = 0; i < totalSprites; i++) {
    final name = sortedNames[i];
    final frameData = frames[name]['frame'] as Map<String, dynamic>;

    final sx = frameData['x'] as int;
    final sy = frameData['y'] as int;
    final sw = frameData['w'] as int;
    final sh = frameData['h'] as int;

    final c = i % cols;
    final r = i ~/ cols;
    final dx = c * cellWidth + padding;
    final dy = r * cellHeight + padding;

    // Crop the sprite from source
    final sprite = img.copyCrop(sourceImg, x: sx, y: sy, width: sw, height: sh);

    // Draw sprite (scaled 2x if small)
    final drawSprite = sw < 32
        ? img.copyResize(
            sprite,
            width: sw * 2,
            height: sh * 2,
            interpolation: img.Interpolation.nearest,
          )
        : sprite;

    img.compositeImage(debugImg, drawSprite, dstX: dx, dstY: dy);

    // Draw label (simplified name)
    final label = name
        .replaceAll('ingame/', '')
        .replaceAll('font/', '')
        .replaceAll('recruit/', '')
        .replaceAll('service/', '');
    img.drawString(
      debugImg,
      label,
      font: img.arial14,
      x: dx + drawSprite.width + 5,
      y: dy + 2,
      color: img.ColorRgba8(0, 0, 0, 255),
    );
  }

  print('Saving debug image to: $outputPath');
  await File(outputPath).writeAsBytes(img.encodePng(debugImg));
  print('Done!');
}
