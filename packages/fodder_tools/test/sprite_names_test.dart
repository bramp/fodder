import 'package:fodder_tools/sprite_names.dart';
import 'package:test/test.dart';

void main() {
  group('inGameGroupNames', () {
    test('maps player walk groups to directional names', () {
      expect(inGameGroupNames[0x00], 'player_walk_s');
      expect(inGameGroupNames[0x01], 'player_walk_sw');
      expect(inGameGroupNames[0x02], 'player_walk_w');
      expect(inGameGroupNames[0x03], 'player_walk_nw');
      expect(inGameGroupNames[0x04], 'player_walk_n');
      expect(inGameGroupNames[0x05], 'player_walk_ne');
      expect(inGameGroupNames[0x06], 'player_walk_e');
      expect(inGameGroupNames[0x07], 'player_walk_se');
    });

    test('maps enemy walk groups to directional names', () {
      expect(inGameGroupNames[0x42], 'enemy_walk_s');
      expect(inGameGroupNames[0x49], 'enemy_walk_se');
    });

    test('maps player throw groups', () {
      expect(inGameGroupNames[0x08], 'player_throw_s');
      expect(inGameGroupNames[0x0F], 'player_throw_se');
    });

    test('maps enemy throw groups', () {
      expect(inGameGroupNames[0x4A], 'enemy_throw_s');
      expect(inGameGroupNames[0x51], 'enemy_throw_se');
    });

    test('maps player death groups', () {
      expect(inGameGroupNames[0x20], 'player_death_s');
      expect(inGameGroupNames[0x27], 'player_death_se');
    });

    test('maps player death2 groups', () {
      expect(inGameGroupNames[0x28], 'player_death2_s');
      expect(inGameGroupNames[0x2F], 'player_death2_se');
    });

    test('maps enemy death groups', () {
      expect(inGameGroupNames[0x62], 'enemy_death_s');
      expect(inGameGroupNames[0x69], 'enemy_death_se');
    });

    test('maps enemy death2 groups', () {
      expect(inGameGroupNames[0x6A], 'enemy_death2_s');
      expect(inGameGroupNames[0x71], 'enemy_death2_se');
    });

    test('maps player firing groups', () {
      expect(inGameGroupNames[0xB0], 'player_firing_s');
      expect(inGameGroupNames[0xB7], 'player_firing_se');
    });

    test('maps enemy firing groups', () {
      expect(inGameGroupNames[0xB8], 'enemy_firing_s');
      expect(inGameGroupNames[0xBF], 'enemy_firing_se');
    });

    test('maps player prone groups', () {
      expect(inGameGroupNames[0x10], 'player_prone_s');
      expect(inGameGroupNames[0x17], 'player_prone_se');
    });

    test('maps player swim groups', () {
      expect(inGameGroupNames[0x18], 'player_swim_s');
      expect(inGameGroupNames[0x1F], 'player_swim_se');
    });

    test('maps enemy prone groups', () {
      expect(inGameGroupNames[0x52], 'enemy_prone_s');
      expect(inGameGroupNames[0x59], 'enemy_prone_se');
    });

    test('maps enemy swim groups', () {
      expect(inGameGroupNames[0x5A], 'enemy_swim_s');
      expect(inGameGroupNames[0x61], 'enemy_swim_se');
    });

    test('maps enemy still groups', () {
      expect(inGameGroupNames[0x72], 'enemy_still_s');
      expect(inGameGroupNames[0x79], 'enemy_still_se');
    });

    test('maps bullet group', () {
      expect(inGameGroupNames[0x7F], 'bullet');
    });

    test('maps salute group', () {
      expect(inGameGroupNames[0x7A], 'salute');
    });

    test('returns null for unmapped groups', () {
      // 0x3A has no mapping
      expect(inGameGroupNames[0x3A], isNull);
      // 0x80 has no mapping
      expect(inGameGroupNames[0x80], isNull);
    });

    test('maps environment decoration groups', () {
      expect(inGameGroupNames[0x8F], 'env_shrub');
      expect(inGameGroupNames[0x90], 'env_tree');
      expect(inGameGroupNames[0x91], 'env_building_roof');
      expect(inGameGroupNames[0x92], 'env_snowman');
      expect(inGameGroupNames[0x93], 'env_shrub2');
    });
  });

  group('spriteGroupName', () {
    test('returns name for InGame groups', () {
      expect(
        spriteGroupName(sheetTypeName: 'InGame', groupIndex: 0x7F),
        'bullet',
      );
      expect(
        spriteGroupName(sheetTypeName: 'InGame', groupIndex: 0x00),
        'player_walk_s',
      );
    });

    test('returns name for lowercase ingame groups', () {
      expect(
        spriteGroupName(sheetTypeName: 'ingame', groupIndex: 0x7F),
        'bullet',
      );
    });

    test('returns name for InGame_CF2 groups (same table)', () {
      expect(
        spriteGroupName(sheetTypeName: 'InGame_CF2', groupIndex: 0x7F),
        'bullet',
      );
    });

    test('returns name for lowercase ingame_cf2 groups', () {
      expect(
        spriteGroupName(sheetTypeName: 'ingame_cf2', groupIndex: 0x7F),
        'bullet',
      );
    });

    test('returns null for unknown sheet type', () {
      expect(spriteGroupName(sheetTypeName: 'Font', groupIndex: 0), isNull);
    });

    test('returns null for unmapped group index', () {
      expect(
        spriteGroupName(sheetTypeName: 'InGame', groupIndex: 0xFF),
        isNull,
      );
    });
  });
}
