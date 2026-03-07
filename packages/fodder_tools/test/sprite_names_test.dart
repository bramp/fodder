import 'package:fodder_tools/sprite_names.dart';
import 'package:test/test.dart';

void main() {
  group('armyDatIngame', () {
    test('maps player walk groups to directional names', () {
      expect(armyDatIngame[0x00]?.name, 'player_walk_s');
      expect(armyDatIngame[0x01]?.name, 'player_walk_sw');
      expect(armyDatIngame[0x02]?.name, 'player_walk_w');
      expect(armyDatIngame[0x03]?.name, 'player_walk_nw');
      expect(armyDatIngame[0x04]?.name, 'player_walk_n');
      expect(armyDatIngame[0x05]?.name, 'player_walk_ne');
      expect(armyDatIngame[0x06]?.name, 'player_walk_e');
      expect(armyDatIngame[0x07]?.name, 'player_walk_se');
    });

    test('maps enemy walk groups to directional names', () {
      expect(armyDatIngame[0x42]?.name, 'enemy_walk_s');
      expect(armyDatIngame[0x49]?.name, 'enemy_walk_se');
    });

    test('maps player throw groups', () {
      expect(armyDatIngame[0x08]?.name, 'player_throw_s');
      expect(armyDatIngame[0x0F]?.name, 'player_throw_se');
    });

    test('maps enemy throw groups', () {
      expect(armyDatIngame[0x4A]?.name, 'enemy_throw_s');
      expect(armyDatIngame[0x51]?.name, 'enemy_throw_se');
    });

    test('maps player death groups', () {
      expect(armyDatIngame[0x20]?.name, 'player_death_s');
      expect(armyDatIngame[0x27]?.name, 'player_death_se');
    });

    test('maps player death2 groups', () {
      expect(armyDatIngame[0x28]?.name, 'player_death2_s');
      expect(armyDatIngame[0x2F]?.name, 'player_death2_se');
    });

    test('maps enemy death groups', () {
      expect(armyDatIngame[0x62]?.name, 'enemy_death_s');
      expect(armyDatIngame[0x69]?.name, 'enemy_death_se');
    });

    test('maps enemy death2 groups', () {
      expect(armyDatIngame[0x6A]?.name, 'enemy_death2_s');
      expect(armyDatIngame[0x71]?.name, 'enemy_death2_se');
    });

    test('maps player firing groups', () {
      expect(armyDatIngame[0xB0]?.name, 'player_firing_alt_s');
      expect(armyDatIngame[0xB7]?.name, 'player_firing_alt_se');
    });

    test('maps enemy firing groups', () {
      expect(armyDatIngame[0xB8]?.name, 'enemy_firing_s');
      expect(armyDatIngame[0xBF]?.name, 'enemy_firing_se');
    });

    test('maps player prone groups', () {
      expect(armyDatIngame[0x10]?.name, 'player_prone_s');
      expect(armyDatIngame[0x17]?.name, 'player_prone_se');
    });

    test('maps player swim groups', () {
      expect(armyDatIngame[0x18]?.name, 'player_swim_s');
      expect(armyDatIngame[0x1F]?.name, 'player_swim_se');
    });

    test('maps enemy prone groups', () {
      expect(armyDatIngame[0x52]?.name, 'enemy_prone_s');
      expect(armyDatIngame[0x59]?.name, 'enemy_prone_se');
    });

    test('maps enemy swim groups', () {
      expect(armyDatIngame[0x5A]?.name, 'enemy_swim_s');
      expect(armyDatIngame[0x61]?.name, 'enemy_swim_se');
    });

    test('maps enemy still groups', () {
      expect(armyDatIngame[0x72]?.name, 'enemy_still_s');
      expect(armyDatIngame[0x79]?.name, 'enemy_still_se');
    });

    test('maps salute group', () {
      expect(armyDatIngame[0x7A]?.name, 'salute');
    });

    test('maps rocket walk groups', () {
      expect(armyDatIngame[0x3A]?.name, 'soldier_rocket_walk_nw');
      expect(armyDatIngame[0x40]?.name, 'soldier_rocket_walk_sw');
    });

    test('maps previously missing groups', () {
      expect(armyDatIngame[0xd5]?.name, 'effect_blood_shrapnel');
      expect(armyDatIngame[0xd6]?.name, 'civilian_death');
      expect(armyDatIngame[0xd7]?.name, 'civilian_spear');
      // 0xe8 (ufo_callpad) only exists in cf2, not cf1.
    });
  });

  group('coptDatIngame', () {
    test('maps bullet group', () {
      expect(coptDatIngame[0x7F]?.name, 'bullet');
    });

    test('maps helicopter groups', () {
      expect(coptDatIngame[0x80]?.name, 'helicopter_s');
      expect(coptDatIngame[0x8B]?.name, 'helicopter_ene');
    });

    test('maps environment decoration groups', () {
      expect(coptDatIngame[0x8F]?.name, 'env_shrub');
      expect(coptDatIngame[0x90]?.name, 'env_tree');
      expect(coptDatIngame[0x91]?.name, 'env_building_roof');
      expect(coptDatIngame[0x92]?.name, 'env_snowman');
      expect(coptDatIngame[0x93]?.name, 'env_shrub2');
    });

    test('maps tank groups', () {
      expect(coptDatIngame[0xd1]?.name, 'tank_body');
      expect(coptDatIngame[0xd2]?.name, 'tank_turret');
    });
  });

  group('hillbitsDatHill', () {
    test('maps hill base pieces', () {
      expect(hillbitsDatHill[0x00]?.name, 'hill_base_0');
      expect(hillbitsDatHill[0x08]?.name, 'hill_base_8');
    });

    test('maps hill piece', () {
      expect(hillbitsDatHill[0x09]?.name, 'hill_piece');
    });

    test('maps hill variants', () {
      expect(hillbitsDatHill[0x0a]?.name, 'hill_variant_0');
      expect(hillbitsDatHill[0x21]?.name, 'hill_variant_23');
    });

    test('maps truck', () {
      expect(hillbitsDatHill[0x22]?.name, 'truck');
    });
  });

  group('hillbitsDatRecruit', () {
    test('maps graves', () {
      expect(hillbitsDatRecruit[0x00]?.name, 'grave');
    });

    test('maps face sprites by color', () {
      expect(hillbitsDatRecruit[0x01]?.name, 'face_front_color1');
      expect(hillbitsDatRecruit[0x04]?.name, 'face_front_color2');
      expect(hillbitsDatRecruit[0x07]?.name, 'face_front_color3');
      expect(hillbitsDatRecruit[0x0a]?.name, 'face_front_color4');
    });

    test('maps recruit font as font group', () {
      expect(hillbitsDatRecruit[0x0d]?.name, 'font_recruit_alpha');
    });

    test('maps UI elements', () {
      expect(hillbitsDatRecruit[0x0e]?.name, 'ui_colon');
      expect(hillbitsDatRecruit[0x0f]?.name, 'ui_cursor');
      expect(hillbitsDatRecruit[0x16]?.name, 'ui_disk_icon');
      expect(hillbitsDatRecruit[0x19]?.name, 'ui_disk_save');
    });
  });

  group('spriteGroupName', () {
    test('returns name for ingame groups (mixed case)', () {
      expect(
        spriteGroupName(sheetTypeName: 'InGame', groupIndex: 0x7F),
        'bullet',
      );
      expect(
        spriteGroupName(sheetTypeName: 'ingame', groupIndex: 0x00),
        'player_walk_s',
      );
    });

    test('returns name for Font sheet type', () {
      expect(
        spriteGroupName(sheetTypeName: 'Font', groupIndex: 0),
        'font_main',
      );
    });

    test('returns name for Briefing sheet type', () {
      expect(
        spriteGroupName(sheetTypeName: 'Briefing', groupIndex: 0),
        'font_dark_green',
      );
    });

    test('returns name for Recruit sheet type', () {
      expect(
        spriteGroupName(sheetTypeName: 'Recruit', groupIndex: 0x00),
        'grave',
      );
      expect(
        spriteGroupName(sheetTypeName: 'Recruit', groupIndex: 0x0d),
        'font_recruit_alpha',
      );
    });

    test('returns name for Hill sheet type separately from recruit', () {
      expect(
        spriteGroupName(sheetTypeName: 'Hill', groupIndex: 0x00),
        'hill_base_0',
      );
      expect(
        spriteGroupName(sheetTypeName: 'Hill', groupIndex: 0x09),
        'hill_piece',
      );
    });

    test('returns null for unmapped group index', () {
      expect(
        spriteGroupName(sheetTypeName: 'InGame', groupIndex: 0xFFFF),
        isNull,
      );
    });
  });

  group('spriteFrameName', () {
    test('produces correct name for non-font frame', () {
      expect(
        spriteFrameName(
          sheetTypeName: 'InGame',
          groupIndex: 0x7F,
          frameIndex: 0,
        ),
        'ingame/bullet_0',
      );
    });

    test('strips font_ prefix from font group names', () {
      expect(
        spriteFrameName(sheetTypeName: 'Font', groupIndex: 0, frameIndex: 0),
        'font/main_A',
      );
    });

    test('uses briefing/ prefix and strips font_ for briefing groups', () {
      expect(
        spriteFrameName(
          sheetTypeName: 'Briefing',
          groupIndex: 0,
          frameIndex: 1,
        ),
        'briefing/dark_green_B',
      );
    });

    test('strips font_ prefix for recruit alpha group', () {
      expect(
        spriteFrameName(
          sheetTypeName: 'Recruit',
          groupIndex: 0x0d,
          frameIndex: 0,
        ),
        'recruit/recruit_alpha_A',
      );
    });

    test('uses numeric suffix for non-font recruit groups', () {
      expect(
        spriteFrameName(
          sheetTypeName: 'Recruit',
          groupIndex: 0x00,
          frameIndex: 3,
        ),
        'recruit/grave_3',
      );
    });

    test('strips font_ prefix for service font groups', () {
      expect(
        spriteFrameName(sheetTypeName: 'Service', groupIndex: 3, frameIndex: 0),
        'service/gameplay_caps_A',
      );
    });

    test('falls back to unknown_XX for unmapped groups', () {
      expect(
        spriteFrameName(
          sheetTypeName: 'InGame',
          groupIndex: 0xFFFF,
          frameIndex: 0,
        ),
        'ingame/unknown_ffff_0',
      );
    });
  });

  group('fontCharacterName', () {
    test('returns character for valid indices', () {
      expect(fontCharacterName(0), 'A');
      expect(fontCharacterName(26), '0');
      expect(fontCharacterName(39), '!');
    });

    test('returns space as "space"', () {
      expect(fontCharacterName(56), 'space');
    });

    test('returns slash as "slash"', () {
      expect(fontCharacterName(44), 'slash');
    });

    test('returns char_\$frameIndex for out of range', () {
      expect(fontCharacterName(1000), 'char_1000');
    });
  });

  group('F (SpriteFrameData)', () {
    test('stores byteOffset, w, h', () {
      const f = F(0, 16, 14);
      expect(f.byteOffset, 0);
      expect(f.w, 16);
      expect(f.h, 14);
    });

    test('defaults modX and modY to zero', () {
      const f = F(0, 16, 14);
      expect(f.modX, 0);
      expect(f.modY, 0);
    });

    test('stores explicit modX and modY', () {
      const f = F(44864, 16, 14, 0, 1);
      expect(f.modX, 0);
      expect(f.modY, 1);
    });

    test('computes pixelX and pixelY from byteOffset', () {
      // byteOffset 0 → (0, 0)
      expect(const F(0, 16, 14).pixelX, 0);
      expect(const F(0, 16, 14).pixelY, 0);
      // byteOffset 8 → (16, 0):  8 % 160 = 8, 8 * 2 = 16
      expect(const F(8, 16, 14).pixelX, 16);
      expect(const F(8, 16, 14).pixelY, 0);
      // byteOffset 160 → (0, 1):  160 % 160 = 0, 160 / 160 = 1
      expect(const F(160, 16, 14).pixelX, 0);
      expect(const F(160, 16, 14).pixelY, 1);
    });
  });

  group('S (SpriteGroupData)', () {
    test('stores name, palette, and offsets for uniform group', () {
      final g = armyDatIngame[0x00]!;
      expect(g.name, 'player_walk_s');
      expect(g.palette, 0xa0);
      expect(g.isVariable, isFalse);
      expect(g.frameCount, 3);
      expect(g.offsets, hasLength(3));
    });

    test('uniform frame data matches expected values for player_walk_s', () {
      final g = armyDatIngame[0x00]!;
      expect(g.offsets[0], 0);
      expect(g.offsets[1], 8);
      expect(g.offsets[2], 16);
      expect(g.w, 16);
      expect(g.h, 14);
    });

    test('non-zero modY in bird_fly_right (variable group)', () {
      final g = armyDatIngame[0xd3]!;
      expect(g.isVariable, isTrue);
      expect(g.frames[4].modY, 1);
      expect(g.frames[5].modY, 3);
    });

    test('font group has expected frame count', () {
      final g = fontDatFont[0x00]!;
      expect(g.name, 'font_main');
      expect(g.frameCount, greaterThan(0));
    });
  });
}
