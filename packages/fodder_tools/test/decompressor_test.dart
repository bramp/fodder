import 'dart:io';

import 'package:fodder_tools/dat_reader.dart';
import 'package:test/test.dart';

void main() {
  /// Verifies every entry in [datPath] decompresses to match [extractedDir].
  void testArchive(String datPath, String extractedDir) {
    final datFile = File(datPath);
    final refDir = Directory(extractedDir);

    if (!datFile.existsSync() || !refDir.existsSync()) {
      markTestSkipped('Missing $datPath or $extractedDir.');
      return;
    }

    final reader = DatReader(datFile)..read();

    for (final entry in reader.entries) {
      final refFile = File('${refDir.path}/${entry.filename}');
      if (!refFile.existsSync()) continue;

      final expected = refFile.readAsBytesSync();
      final actual = reader.getFileBytes(entry);

      expect(actual, expected, reason: 'Data mismatch for ${entry.filename}');
    }
  }

  test('Decompressor matches Dos_CD_Extracted', () {
    testArchive(
      '../../original_game/Dos_CD/CF_ENG.DAT',
      '../../original_game/Dos_CD_Extracted',
    );
  });

  test('Decompressor matches Dos2_CD_Extracted', () {
    testArchive(
      '../../original_game/Dos2_CD/CF_ENG.DAT',
      '../../original_game/Dos2_CD_Extracted',
    );
  });
}
