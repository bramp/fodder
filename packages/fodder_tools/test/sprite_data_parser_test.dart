import 'package:test/test.dart';

import 'package:fodder_tools/sprite_data_parser.dart';
import 'package:fodder_tools/sprite_frame.dart';

void main() {
  group('SpriteDataParser', () {
    test('parses a single sSpriteSheet array', () {
      const source = '''
const sSpriteSheet mSpriteSheet_Font_PC[2] = {
  { 0, eGFX_FONT, 0, 0, 16, 17, 208, 0, 0 },
  { 8, eGFX_FONT, 0, 0, 16, 17, 208, 0, 0 }
};

const sSpriteSheet* mSpriteSheetTypes_Font_PC[] = {
  mSpriteSheet_Font_PC
};
''';
      final results = SpriteDataParser.parse(source: source);

      expect(results, hasLength(1));
      expect(results[0].name, 'Font');
      expect(results[0].entries, hasLength(1));

      final group = results[0].entries[0];
      expect(group, hasLength(2));

      expect(group[0].byteOffset, 0);
      expect(group[0].gfxType, GfxType.font);
      expect(group[0].width, 16);
      expect(group[0].height, 17);
      expect(group[0].paletteIndex, 208);
      expect(group[0].modX, 0);
      expect(group[0].modY, 0);

      expect(group[1].byteOffset, 8);
    });

    test('parses multiple sprite groups in a pointer array', () {
      const source = '''
const sSpriteSheet stru_A[3] = {
  { 0, eGFX_IN_GAME, 0, 0, 16, 16, 160, -7, -12 },
  { 8, eGFX_IN_GAME, 0, 0, 16, 16, 160, -7, -12 },
  { 16, eGFX_IN_GAME, 0, 0, 16, 16, 160, -7, -12 }
};

const sSpriteSheet stru_B[1] = {
  { 100, eGFX_IN_GAME, 0, 0, 32, 24, 160, 0, -5 }
};

const sSpriteSheet* mSpriteSheetTypes_InGame_PC[] = {
  /* 0x00 */ stru_A,  // Walk forward
  /* 0x01 */ stru_B   // Something else
};
''';
      final results = SpriteDataParser.parse(source: source);

      expect(results, hasLength(1));
      expect(results[0].name, 'InGame');
      expect(results[0].entries, hasLength(2));

      // Group 0 = stru_A (3 frames).
      expect(results[0].entries[0], hasLength(3));
      expect(results[0].entries[0][0].modX, -7);
      expect(results[0].entries[0][0].modY, -12);

      // Group 1 = stru_B (1 frame).
      expect(results[0].entries[1], hasLength(1));
      expect(results[0].entries[1][0].byteOffset, 100);
      expect(results[0].entries[1][0].width, 32);
      expect(results[0].entries[1][0].height, 24);
    });

    test('handles CF2 pointer array naming', () {
      const source = '''
const sSpriteSheet stru_X[1] = {
  { 0, eGFX_IN_GAME, 0, 0, 16, 16, 160, 0, 0 }
};

const sSpriteSheet* mSpriteSheetTypes_InGame_PC2[] = {
  stru_X
};
''';
      final results = SpriteDataParser.parse(source: source);

      expect(results, hasLength(1));
      expect(results[0].name, 'InGame_CF2');
    });

    test('parses all eGFX_* enum values', () {
      const source = '''
sSpriteSheet a[1] = { { 0, eGFX_IN_GAME, 0, 0, 1, 1, 0, 0, 0 } };
sSpriteSheet b[1] = { { 0, eGFX_IN_GAME2, 0, 0, 1, 1, 0, 0, 0 } };
sSpriteSheet c[1] = { { 0, eGFX_FONT, 0, 0, 1, 1, 0, 0, 0 } };
sSpriteSheet d[1] = { { 0, eGFX_HILL, 0, 0, 1, 1, 0, 0, 0 } };
sSpriteSheet e[1] = { { 0, eGFX_RECRUIT, 0, 0, 1, 1, 0, 0, 0 } };
sSpriteSheet f[1] = { { 0, eGFX_BRIEFING, 0, 0, 1, 1, 0, 0, 0 } };
sSpriteSheet g[1] = { { 0, eGFX_SERVICE, 0, 0, 1, 1, 0, 0, 0 } };
sSpriteSheet h[1] = { { 0, eGFX_RANKFONT, 0, 0, 1, 1, 0, 0, 0 } };
sSpriteSheet i[1] = { { 0, eGFX_PSTUFF, 0, 0, 1, 1, 0, 0, 0 } };

const sSpriteSheet* mSpriteSheetTypes_Test_PC[] = {
  a, b, c, d, e, f, g, h, i
};
''';
      final results = SpriteDataParser.parse(source: source);
      final groups = results[0].entries;

      expect(groups[0][0].gfxType, GfxType.inGame);
      expect(groups[1][0].gfxType, GfxType.inGame2);
      expect(groups[2][0].gfxType, GfxType.font);
      expect(groups[3][0].gfxType, GfxType.hill);
      expect(groups[4][0].gfxType, GfxType.recruit);
      expect(groups[5][0].gfxType, GfxType.briefing);
      expect(groups[6][0].gfxType, GfxType.service);
      expect(groups[7][0].gfxType, GfxType.rankFont);
      expect(groups[8][0].gfxType, GfxType.pstuff);
    });

    test('skips unresolved variable references', () {
      const source = '''
const sSpriteSheet stru_A[1] = {
  { 0, eGFX_FONT, 0, 0, 16, 17, 208, 0, 0 }
};

const sSpriteSheet* mSpriteSheetTypes_Font_PC[] = {
  stru_A,
  stru_MISSING,
  stru_A
};
''';
      final results = SpriteDataParser.parse(source: source);

      // stru_MISSING is skipped, so only 2 entries resolve.
      expect(results[0].entries, hasLength(2));
    });

    test('returns empty list for content with no pointer arrays', () {
      const source = '''
const sSpriteSheet stru_A[1] = {
  { 0, eGFX_FONT, 0, 0, 16, 17, 208, 0, 0 }
};
''';
      final results = SpriteDataParser.parse(source: source);
      expect(results, isEmpty);
    });
  });

  group('SpriteFrame', () {
    test('pixelX and pixelY compute from byteOffset', () {
      // offset=162 → row=162/160=1, col_byte=162%160=2 → pixelX=4
      const frame = SpriteFrame(
        byteOffset: 162,
        gfxType: GfxType.inGame,
        width: 16,
        height: 16,
        paletteIndex: 0,
        modX: 0,
        modY: 0,
      );

      expect(frame.pixelX(), 4);
      expect(frame.pixelY(), 1);
    });

    test('pixelX and pixelY at row boundary', () {
      // offset=320 → row=320/160=2, col_byte=0 → pixelX=0
      const frame = SpriteFrame(
        byteOffset: 320,
        gfxType: GfxType.inGame,
        width: 16,
        height: 16,
        paletteIndex: 0,
        modX: 0,
        modY: 0,
      );

      expect(frame.pixelX(), 0);
      expect(frame.pixelY(), 2);
    });
  });
}
