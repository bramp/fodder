import 'dart:typed_data';

import 'package:fodder_tools/bht_reader.dart';
import 'package:fodder_tools/terrain_data.dart';
import 'package:test/test.dart';

void main() {
  /// Helper: build a list of all-zero 8-byte masks.
  List<Uint8List> zeroMasks(int count) =>
      List.generate(count, (_) => Uint8List(bhtBytesPerTile));

  group('TileTerrainData', () {
    test('simple tile has no secondary or mask', () {
      const td = TileTerrainData.simple(3);
      expect(td.primary, 3);
      expect(td.secondary, isNull);
      expect(td.mask, isNull);
      expect(td.isMixed, isFalse);
    });

    test('mixed tile has secondary and mask', () {
      final mask = Uint8List.fromList([0x80, 0, 0, 0, 0, 0, 0, 0]);
      final td = TileTerrainData.mixed(primary: 0, secondary: 7, mask: mask);
      expect(td.primary, 0);
      expect(td.secondary, 7);
      expect(td.mask, mask);
      expect(td.isMixed, isTrue);
    });
  });

  group('buildTileTerrainData', () {
    test('simple positive values become simple tiles', () {
      final result = buildTileTerrainData(
        rawHitValues: [0, 3, 6],
        bhtMasks: zeroMasks(3),
      );
      expect(result.length, 3);
      expect(result[0].primary, 0); // Land
      expect(result[0].isMixed, isFalse);
      expect(result[1].primary, 3); // Block
      expect(result[2].primary, 6); // Water
    });

    test('negative value with non-trivial mask becomes mixed', () {
      // Raw -32656 = 0x8070 signed → primary = 0 (Land),
      // secondary = (0x8070 >> 4) & 0x0F = 7 (Snow).
      final mask = Uint8List.fromList([0x80, 0, 0, 0, 0, 0, 0, 0]);
      final result = buildTileTerrainData(
        rawHitValues: [-32656],
        bhtMasks: [mask],
      );

      expect(result.length, 1);
      expect(result[0].isMixed, isTrue);
      expect(result[0].primary, 0); // Land
      expect(result[0].secondary, 7); // Snow
      expect(result[0].mask, mask);
    });

    test('negative value with all-zero mask stays mixed', () {
      final result = buildTileTerrainData(
        rawHitValues: [-32656], // 0x8070 → primary=0, secondary=7
        bhtMasks: zeroMasks(1),
      );
      expect(result[0].isMixed, isTrue);
      expect(result[0].primary, 0);
      expect(result[0].secondary, 7);
    });

    test('negative value with all-FF mask stays mixed', () {
      final mask = Uint8List.fromList(List.filled(8, 0xFF));
      final result = buildTileTerrainData(
        rawHitValues: [-32656], // 0x8070 → primary=0, secondary=7
        bhtMasks: [mask],
      );
      expect(result[0].isMixed, isTrue);
      expect(result[0].primary, 0);
      expect(result[0].secondary, 7);
    });

    test('warns when HIT and BHT lengths differ', () {
      final warnings = <String>[];
      buildTileTerrainData(
        rawHitValues: [0, 0, 0],
        bhtMasks: zeroMasks(2),
        warn: warnings.add,
      );
      expect(warnings, contains(contains('lengths do not match')));
    });

    test('warns for out-of-range primary terrain', () {
      final warnings = <String>[];
      // Raw value 0x0F → primary = 15 > maxTerrainType (14)
      buildTileTerrainData(
        rawHitValues: [0x0F],
        bhtMasks: zeroMasks(1),
        warn: warnings.add,
      );
      expect(warnings, contains(contains('terrain 15')));
    });

    test('emits summary with mixed/single counts', () {
      final warnings = <String>[];
      final mask = Uint8List.fromList([0x80, 0, 0, 0, 0, 0, 0, 0]);
      buildTileTerrainData(
        rawHitValues: [0, -32656], // 1 simple, 1 mixed (negative)
        bhtMasks: [Uint8List(8), mask],
        warn: warnings.add,
      );
      // The summary line shows total tile count.
      expect(warnings, contains(contains('2 tiles')));
    });

    test('handles zero-length input', () {
      final result = buildTileTerrainData(rawHitValues: [], bhtMasks: []);
      expect(result, isEmpty);
    });
  });
}
