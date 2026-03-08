/// Maps sprite group indices to human-readable names and frame metadata.
///
/// Each map entry contains the group name, palette index, frame dimensions,
/// and byte offsets. This is the single source of truth for sprite metadata,
/// used directly by `sprites.dart` for atlas generation and copt palette
/// fix-up.
///
/// ## Organisation
///
/// Name tables are organised by the **.dat file** that holds the pixel data.
/// Variable names follow the pattern `{datFile}Dat{NiceName}`, e.g.
/// `pstuffDatBriefing` is the briefing-font table whose frames live in
/// `pstuff.dat`.
///
/// ## Naming convention
///
/// **Directional sprites** (8 consecutive groups, one per compass direction):
/// ```
/// {role}_{action}_{direction}
/// ```
/// Where:
/// - **role**: `player` or `enemy`
/// - **action**: `walk`, `throw`, `prone`, `swim`, `death`, `death2`,
///   `still`, `firing`
/// - **direction**: `s`, `sw`, `w`, `nw`, `n`, `ne`, `e`, `se`
///
/// **Non-directional sprites** use a bare descriptive name (e.g. `bullet`,
/// `salute`).
///
/// **Font groups** are prefixed `font_` internally so the export tool can
/// detect them and use character-name suffixes (`A`, `space`, …) instead of
/// numeric indices. The `font_` prefix is stripped from the generated frame
/// name, so `font_dark_green` becomes `briefing/dark_green_A`.
///
/// Groups without a hand-curated name retain a fallback (`unknown_7f`, …).
///
/// ## .dat file → nice-name prefix routing
///
/// | .dat file(s)              | Nice name   | Variable              | GfxType              |
/// |---------------------------|-------------|-----------------------|----------------------|
/// | font.dat                  | `font`      | `fontDatFont`         | `font`               |
/// | pstuff.dat                | `briefing`  | `pstuffDatBriefing`   | `briefing`           |
/// | hillbits.dat              | `hill`      | `hillbitsDatHill`     | `hill`               |
/// | hillbits.dat              | `recruit`   | `hillbitsDatRecruit`  | `recruit`            |
/// | \*army.dat               | `ingame`    | `armyDatIngame`       | `inGame`             |
/// | \*copt.dat               | `ingame`    | `coptDatIngame`       | `inGame2`            |
/// | rankfont.dat              | `service`   | `rankfontDatService`  | `rankFont`           |
/// | morphbig.dat              | `service`   | `morphbigDatService`  | `service`            |
///
/// ## Frame data
///
/// For uniform-size groups (the majority), [SpriteGroup] stores the shared
/// `w`×`h` and a flat `List<int>` of byte offsets — one per frame. For the
/// few groups with mixed frame sizes or rendering offsets, [SpriteGroup.v]
/// stores a `List<Frame>` with per-frame dimensions.
///
/// The pixel position on the 320-wide sprite sheet can be derived from
/// any byte offset:
///
/// ```
/// x = (byteOffset % 160) * 2
/// y = byteOffset ~/ 160
/// ```
library;

import 'package:fodder_tools/sprite_frame.dart';

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

/// Metadata for a single sprite frame (used only by variable-size groups).
///
/// The [byteOffset] is the raw offset into the .dat file. The pixel
/// coordinates on the 320-pixel-wide sprite sheet are:
/// - `x = (byteOffset % 160) * 2`
/// - `y = byteOffset ~/ 160`
class Frame {
  const Frame(this.byteOffset, this.w, this.h, [this.modX = 0, this.modY = 0]);

  final int byteOffset;
  final int w;
  final int h;
  final int modX;
  final int modY;

  int get pixelX => (byteOffset % 160) * 2;
  int get pixelY => byteOffset ~/ 160;

  @override
  String toString() =>
      'Frame($byteOffset, ${w}x$h'
      '${modX != 0 || modY != 0 ? ', mod=$modX,$modY' : ''})';
}

/// A named sprite group with palette index and frame data.
///
/// **Uniform groups** (primary constructor): every frame shares the same
/// [w]×[h] dimensions with no rendering offsets → stored as a flat list of
/// byte [offsets].
///
/// **Variable groups** ([SpriteGroup.v]): frames differ in size or have
/// modX/modY → stored as a `List<Frame>`.
class SpriteGroup {
  const SpriteGroup(this.name, this.palette, this.w, this.h, this.offsets)
    : frames = const [],
      chars = null;

  const SpriteGroup.v(this.name, this.palette, this.frames)
    : w = 0,
      h = 0,
      offsets = const [],
      chars = null;

  /// Font group: uniform frames with a [chars] string mapping each frame
  /// to a character. `chars.length` must equal `offsets.length`.
  const SpriteGroup.font(
    this.name,
    this.palette,
    this.w,
    this.h,
    this.chars,
    this.offsets,
  ) : frames = const [];

  final String name;
  final int palette;
  final int w;
  final int h;
  final List<int> offsets;
  final List<Frame> frames;

  /// For font groups, maps each frame index to a character.
  final String? chars;

  bool get isVariable => frames.isNotEmpty;
  bool get isFont => chars != null;
  int get frameCount => isVariable ? frames.length : offsets.length;

  @override
  String toString() =>
      'SpriteGroup($name, 0x${palette.toRadixString(16)}, '
      '$frameCount frames)';
}

/// Compact alias for [SpriteGroup], used in the data declarations below.
typedef S = SpriteGroup;

/// Compact alias for [SpriteGroup.font], used in the data declarations below.
// ignore: non_constant_identifier_names
S Sf(String name, int pal, int w, int h, String chars, List<int> offsets) {
  if (chars.length != offsets.length) {
    throw ArgumentError(
      'SpriteGroup.font "$name": chars.length (${chars.length}) != offsets.length (${offsets.length})',
    );
  }
  return SpriteGroup.font(name, pal, w, h, chars, offsets);
}

/// Compact alias for [Frame], used in the data declarations below.
typedef F = Frame;

// ---------------------------------------------------------------------------
// Spread helpers
// ---------------------------------------------------------------------------

/// Expands N directional entries that share a single frame list.
Map<int, S> _dn(
  int base,
  String prefix,
  int pal,
  List<String> dirs,
  List<F> sharedFrames,
) => {
  for (var i = 0; i < dirs.length; i++)
    base + i: S.v('${prefix}_${dirs[i]}', pal, sharedFrames),
};

/// Sprite groups stored in **font.dat** (`GfxType.font`).
///
/// Contains the main game font.
final fontDatFont = <int, S>{
  0x00: Sf(
    'font_main',
    0x00,
    16,
    17,
    'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789\',.!()-?/:;"+=*&%\$#@ abcdefghijklmnopqrstuvwxyz',
    [
      0, 8, 16, 24, 32, 40, 48, 56, // A-H
      64, 72, 80, 88, 96, 104, 112, 120, // I-P
      128, 136, 144, 152, 2720, 2728, 2736, 2744, // Q-X
      2752, 2760, 5536, 5544, 5552, 5560, 5568, 5576, // Y-Z, 0-5
      5584, 5592, 8160, 8168, 10896, 8192, 8200, 8208, // 6-9, ', ., ,, !
      0, 8, 16, 24, 32, 40, 48, 56, // ( ) - ? / : ; " (maps to A-H)
      64, 72, 80, 88, 96, 104, 112, 120, // + = * & % $ # @ (maps to I-P)
      128, 2768, 2776, 2784, 2792, 2800, 2808, 2816, // space (maps to Q), a-g
      2824, 2832, 2840, 2848, 2856, 2864, 2872, 5440, // h-o
      5448, 5456, 5464, 5472, 5480, 5488, 5496, 5504, // p-w
      5512, 5520, 5528, // x-z
    ],
  ),
  0x01: Sf('font_numbers', 0x01, 16, 17, '0123456789.,!()\'?', [
    5536, 5544, 5552, 5560, 5568, 5576, 5584, 5592, // 0-7
    8160, 8168, 8192, 8200, 8208, 10880, 10888, 10896, // 8-'
    10904, // ?
  ]),
  0x02: Sf(
    'font_alt',
    0x02,
    16,
    17,
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789:;.,!"£\$%^&*( ) +/[]\'?ÜÖÄÅÈ',
    [
      19040, 19048, 19056, 19064, 19072, 19080, 19088, 19096, // A-H
      19104, 19112, 19120, 19128, 19136, 19144, 19152, 19160, // I-P
      19168, 19176, 19184, 19192, 21760, 21768, 21776, 21784, // Q-X
      21792, 21800, 21808, 21816, 21824, 21832, 21840, 21848, // Y-f
      21856, 21864, 21872, 21880, 21888, 21896, 21904, 21912, // g-n
      24480, 24488, 24496, 24504, 24512, 24520, 24528, 24536, // o-v
      24544, 24552, 24560, 24568, 24576, 24584, 24592, 24600, // w-3
      24608, 24616, 24624, 24632, 27200, 27208, 27216, 27224, // 4-;
      27232, 27240, 27248, 27256, 27264, 27272, 27280, 27288, // .-^
      27296, 27304, 27312, 27320, 27328, 27336, 27344, 27352, // &-/
      29920, 29928, 29936, 29944, 29960, 29968, 29976, 29984, // [-Å
      29992, // È
    ],
  ),
};

/// Sprite groups stored in **pstuff.dat** (`GfxType.briefing`).
///
/// Contains the briefing screen fonts.
final pstuffDatBriefing = <int, S>{
  0x00: S('font_dark_green', 0xf0, 16, 6, [
    25672,
    25680,
    25688,
    25696,
    25704,
    25712,
    25720,
    25728,
    25736,
    25744,
    25752,
    26632,
    26640,
    26648,
    26656,
    26664,
    26672,
    26680,
    26688,
    26696,
    26704,
    26712,
    27592,
    27600,
    27608,
    27616,
    27624,
    27632,
    27640,
    27648,
    27656,
    27664,
    27672,
    28552,
    28560,
    28568,
    28576,
  ]),
  0x01: S('font_light_green', 0xf0, 16, 20, [
    32000,
    32008,
    32016,
    32024,
    32032,
    32040,
    32048,
    32056,
    32064,
    32072,
    32080,
    32088,
    32096,
    32104,
    32112,
    32120,
    32128,
    32136,
    32144,
    32152,
    35200,
    35208,
    35216,
    35224,
    35232,
    35240,
    35256,
    35264,
    35272,
    35280,
    35288,
    35296,
    35304,
    35312,
    35320,
    35328,
    35344,
    35248,
  ]),
  0x02: S('font_blue', 0xf0, 16, 1, [32160]),
  0x03: S.v('font_light_blue', 0xf0, [
    F(32320, 16, 16),
    F(32328, 16, 16),
    F(32336, 16, 16),
    F(32344, 16, 16),
    F(32352, 16, 16),
    F(32360, 16, 16),
    F(32368, 16, 16),
    F(32376, 16, 16),
    F(32384, 16, 16),
    F(32392, 16, 16),
    F(32400, 16, 16),
    F(32408, 16, 16),
    F(32416, 16, 16),
    F(32424, 16, 16),
    F(32432, 16, 16),
    F(32440, 16, 16),
    F(32448, 16, 16),
    F(32456, 16, 16),
    F(32464, 16, 16),
    F(32472, 16, 16),
    F(35520, 16, 16),
    F(35528, 16, 16),
    F(35536, 16, 16),
    F(35544, 16, 16),
    F(35552, 16, 16),
    F(35560, 16, 16),
    F(35576, 16, 16),
    F(35584, 16, 16),
    F(35592, 16, 16),
    F(35600, 16, 16),
    F(35608, 16, 16),
    F(35616, 16, 16),
    F(35624, 16, 16),
    F(35632, 16, 16),
    F(35640, 16, 16),
    F(35648, 16, 16),
    F(35344, 15, 20),
    F(35568, 16, 16),
  ]),
};

/// Sprite groups stored in **rankfont.dat** (`GfxType.rankFont`).
///
/// Contains rank screen fonts and UI elements.
final rankfontDatService = <int, S>{
  0x00: S('ui_bg_panel_tile_dark', 0x80, 24, 22, [3000]),
  0x01: S('ui_bg_panel_tile_light', 0x40, 24, 22, [3016]),
  0x02: S('rank_icon', 0x40, 16, 18, [
    0,
    8,
    16,
    24,
    32,
    40,
    48,
    56,
    64,
    72,
    80,
    88,
    96,
    104,
    112,
    120,
    128,
    136,
    144,
    152,
    2880,
    2888,
    2896,
    2904,
    2912,
    2920,
  ]),
  0x03: S('font_gameplay_caps', 0x40, 16, 11, [
    6400,
    6408,
    6416,
    6424,
    6432,
    6440,
    6448,
    6456,
    6464,
    6472,
    6480,
    6488,
    6496,
    6504,
    6512,
    6520,
    6528,
    6536,
    6544,
    6552,
    8160,
    8168,
    8176,
    8184,
    8192,
    8200,
  ]),
  0x04: S('font_gameplay_full', 0x40, 16, 15, [
    9920,
    9928,
    9936,
    9944,
    9952,
    9960,
    9968,
    9976,
    9984,
    9992,
    10000,
    10008,
    10016,
    10024,
    10032,
    10040,
    10048,
    10056,
    10064,
    10072,
    12320,
    12328,
    12336,
    12344,
    12352,
    12360,
    14816,
    14824,
    14832,
    14840,
    14848,
    14856,
    14864,
    14872,
    27096,
    27104,
    9920,
    9928,
    9936,
    9944,
    0,
    8,
    16,
    24,
    32,
    40,
    48,
    56,
    64,
    72,
    12368,
    12376,
    12384,
    12392,
    12400,
    12408,
    12416,
    12424,
    12432,
    12440,
    12448,
    12456,
    12464,
    12472,
    14720,
    14728,
    14736,
    14744,
    14752,
    14760,
    14768,
    14776,
    14784,
    14792,
    14800,
    14808,
  ]),
  0x05: S('ui_bg_panel_strip_dark', 0x40, 216, 28, [34240]),
  0x06: S('ui_bg_panel_strip_light', 0x40, 216, 28, [29760]),
  0x09: S('ui_text_lost_heroes_right', 0x40, 128, 22, [2936]),
};

/// Sprite groups stored in **morphbig.dat** (`GfxType.service`).
///
/// Contains large service screen portraits.
final morphbigDatService = <int, S>{
  0x07: S('ui_soldier_large_portrait_left', 0x00, 80, 142, [0]),
  0x08: S('ui_soldier_large_portrait_right', 0x00, 80, 142, [80]),
};

/// Sprite groups stored in **\*army.dat** (`GfxType.inGame`).
///
/// Per-terrain sprite sheets (junarmy.dat, desarmy.dat, etc.) containing
/// all soldier animations, effects, and ground-level visuals.
final armyDatIngame = <int, S>{
  0x00: S('player_walk_s', 0xa0, 16, 14, [0, 8, 16]),
  0x01: S('player_walk_sw', 0xa0, 16, 14, [24, 32, 40]),
  0x02: S('player_walk_w', 0xa0, 16, 14, [48, 56, 64]),
  0x03: S('player_walk_nw', 0xa0, 16, 14, [72, 80, 88]),
  0x04: S('player_walk_n', 0xa0, 16, 14, [96, 104, 112]),
  0x05: S('player_walk_ne', 0xa0, 16, 14, [120, 128, 136]),
  0x06: S('player_walk_e', 0xa0, 16, 14, [144, 152, 2240]),
  0x07: S('player_walk_se', 0xa0, 16, 14, [2248, 2256, 2264]),
  0x08: S('player_throw_s', 0xa0, 16, 14, [2272, 2280, 2288]),
  0x09: S('player_throw_sw', 0xa0, 16, 14, [2296, 2304, 2312]),
  0x0a: S('player_throw_w', 0xa0, 16, 14, [2320, 2328, 2336]),
  0x0b: S('player_throw_nw', 0xa0, 16, 14, [2344, 2352, 2360]),
  0x0c: S('player_throw_n', 0xa0, 16, 14, [2368, 2376, 2384]),
  0x0d: S('player_throw_ne', 0xa0, 16, 14, [2392, 4480, 4488]),
  0x0e: S('player_throw_e', 0xa0, 16, 14, [4496, 4504, 4512]),
  0x0f: S('player_throw_se', 0xa0, 16, 14, [4520, 4528, 4536]),
  0x10: S('player_prone_s', 0xa0, 16, 14, [4544]),
  0x11: S('player_prone_sw', 0xa0, 16, 14, [4552]),
  0x12: S('player_prone_w', 0xa0, 16, 14, [4560]),
  0x13: S('player_prone_nw', 0xa0, 16, 14, [4568]),
  0x14: S('player_prone_n', 0xa0, 16, 14, [4576]),
  0x15: S('player_prone_ne', 0xa0, 16, 14, [4584]),
  0x16: S('player_prone_e', 0xa0, 16, 14, [4592]),
  0x17: S('player_prone_se', 0xa0, 16, 14, [4600]),
  0x18: S('player_swim_s', 0xa0, 16, 14, [4608, 4616]),
  0x19: S('player_swim_sw', 0xa0, 16, 14, [4624, 4632]),
  0x1a: S('player_swim_w', 0xa0, 16, 14, [6720, 6728]),
  0x1b: S('player_swim_nw', 0xa0, 16, 14, [6736, 6744]),
  0x1c: S('player_swim_n', 0xa0, 16, 14, [6752, 6760]),
  0x1d: S('player_swim_ne', 0xa0, 16, 14, [6768, 6776]),
  0x1e: S('player_swim_e', 0xa0, 16, 14, [6784, 6792]),
  0x1f: S('player_swim_se', 0xa0, 16, 14, [6800, 6808]),
  0x20: S('player_death_s', 0xa0, 16, 14, [6816]),
  0x21: S('player_death_sw', 0xa0, 16, 14, [6832, 6840]),
  0x22: S('player_death_w', 0xa0, 16, 14, [6848, 6856]),
  0x23: S('player_death_nw', 0xa0, 16, 14, [6864, 6872]),
  0x24: S('player_death_n', 0xa0, 16, 14, [8960, 8968]),
  0x25: S('player_death_ne', 0xa0, 16, 14, [8976, 8984]),
  0x26: S('player_death_e', 0xa0, 16, 14, [8992, 9000]),
  0x27: S('player_death_se', 0xa0, 16, 14, [9008, 9016]),
  0x28: S('player_death2_s', 0xa0, 16, 14, [9024, 9032]),
  0x29: S('player_death2_sw', 0xa0, 16, 14, [9040, 9048]),
  0x2a: S('player_death2_w', 0xa0, 16, 14, [9056, 9064]),
  0x2b: S('player_death2_nw', 0xa0, 16, 14, [9072, 9080]),
  0x2c: S('player_death2_n', 0xa0, 16, 14, [9088, 9096]),
  0x2d: S('player_death2_ne', 0xa0, 16, 14, [9104, 9112]),
  0x2e: S('player_death2_e', 0xa0, 16, 14, [11200, 11208]),
  0x2f: S('player_death2_se', 0xa0, 16, 14, [11216, 11224]),
  0x30: S('player_firing_s', 0xa0, 16, 14, [11232, 11240, 11248]),
  0x31: S('player_firing_w', 0xa0, 16, 14, [11256, 11264, 11272]),
  0x32: S('player_firing_e', 0xa0, 16, 14, [11280, 11288, 11296]),
  0x33: S('explosion', 0xa0, 16, 14, [11304, 11312, 11320]),
  0x34: S('bones', 0xa0, 16, 14, [11328, 11336, 11344]),
  0x35: S('shadow', 0xa0, 16, 14, [11352, 13440, 13448]),
  0x36: S('enemy_rocket', 0xa0, 16, 14, [13456, 13464, 13472]),
  0x37: S('grenade_box', 0xa0, 16, 14, [13480, 13488, 13496]),
  0x38: S('rocket_box', 0xa0, 16, 14, [
    13504,
    13512,
    13520,
    13528,
    13536,
    13544,
  ]),
  0x39: S('soldier_fired_rocket', 0xa0, 16, 14, [15712, 15720, 15728]),
  0x3a: S('soldier_rocket_walk_nw', 0xa0, 16, 14, [15736, 15744, 15752]),
  0x3b: S('soldier_rocket_walk_n', 0xa0, 16, 14, [15760, 15768, 15776]),
  0x3c: S('soldier_rocket_walk_ne', 0xa0, 16, 14, [15784, 15792, 15800]),
  0x3d: S('soldier_rocket_walk_e', 0xa0, 16, 14, [15808, 15816, 15824]),
  0x3e: S('soldier_rocket_walk_se', 0xa0, 16, 14, [15832, 17920, 17928, 17936]),
  0x3f: S('soldier_rocket_walk_s', 0xa0, 16, 14, [17936, 17944, 17952]),
  0x40: S('soldier_rocket_walk_sw', 0xa0, 16, 14, [17960, 17968, 17976]),
  0x41: S('shrub', 0xa0, 16, 14, [13552, 13560, 13568, 13576, 13584, 13592]),
  0x42: S('enemy_walk_s', 0xa0, 16, 14, [22400, 22408, 22416]),
  0x43: S('enemy_walk_sw', 0xa0, 16, 14, [22424, 22432, 22440]),
  0x44: S('enemy_walk_w', 0xa0, 16, 14, [22448, 22456, 22464]),
  0x45: S('enemy_walk_nw', 0xa0, 16, 14, [22472, 22480, 22488]),
  0x46: S('enemy_walk_n', 0xa0, 16, 14, [22496, 22504, 22512]),
  0x47: S('enemy_walk_ne', 0xa0, 16, 14, [22520, 22528, 22536]),
  0x48: S('enemy_walk_e', 0xa0, 16, 14, [22544, 22552, 24640]),
  0x49: S('enemy_walk_se', 0xa0, 16, 14, [24648, 24656, 24664]),
  0x4a: S('enemy_throw_s', 0xa0, 16, 14, [24672, 24680, 24688]),
  0x4b: S('enemy_throw_sw', 0xa0, 16, 14, [24696, 24704, 24712]),
  0x4c: S('enemy_throw_w', 0xa0, 16, 14, [24720, 24728, 24736]),
  0x4d: S('enemy_throw_nw', 0xa0, 16, 14, [24744, 24752, 24760]),
  0x4e: S('enemy_throw_n', 0xa0, 16, 14, [24768, 24776, 24784]),
  0x4f: S('enemy_throw_ne', 0xa0, 16, 14, [24792, 26880, 26888]),
  0x50: S('enemy_throw_e', 0xa0, 16, 14, [26896, 26904, 26912]),
  0x51: S('enemy_throw_se', 0xa0, 16, 14, [26920, 26928, 26936]),
  0x52: S('enemy_prone_s', 0xa0, 16, 14, [26944]),
  0x53: S('enemy_prone_sw', 0xa0, 16, 14, [26952]),
  0x54: S('enemy_prone_w', 0xa0, 16, 14, [26960]),
  0x55: S('enemy_prone_nw', 0xa0, 16, 14, [26968]),
  0x56: S('enemy_prone_n', 0xa0, 16, 14, [26976]),
  0x57: S('enemy_prone_ne', 0xa0, 16, 14, [26984]),
  0x58: S('enemy_prone_e', 0xa0, 16, 14, [26992]),
  0x59: S('enemy_prone_se', 0xa0, 16, 14, [27000]),
  0x5a: S('enemy_swim_s', 0xa0, 16, 14, [27008, 27016]),
  0x5b: S('enemy_swim_sw', 0xa0, 16, 14, [27024, 27032]),
  0x5c: S('enemy_swim_w', 0xa0, 16, 14, [29120, 29128]),
  0x5d: S('enemy_swim_nw', 0xa0, 16, 14, [29136, 29144]),
  0x5e: S('enemy_swim_n', 0xa0, 16, 14, [29152, 29160]),
  0x5f: S('enemy_swim_ne', 0xa0, 16, 14, [29168, 29176]),
  0x60: S('enemy_swim_e', 0xa0, 16, 14, [29184, 29192]),
  0x61: S('enemy_swim_se', 0xa0, 16, 14, [29200, 29208]),
  0x62: S('enemy_death_s', 0xa0, 16, 14, [29216, 29224]),
  0x63: S('enemy_death_sw', 0xa0, 16, 14, [29232, 29240]),
  0x64: S('enemy_death_w', 0xa0, 16, 14, [29248, 29256]),
  0x65: S('enemy_death_nw', 0xa0, 16, 14, [29264, 29272]),
  0x66: S('enemy_death_n', 0xa0, 16, 14, [31360, 31368]),
  0x67: S('enemy_death_ne', 0xa0, 16, 14, [31376, 31384]),
  0x68: S('enemy_death_e', 0xa0, 16, 14, [31392, 31400]),
  0x69: S('enemy_death_se', 0xa0, 16, 14, [31408, 31416, 31424]),
  0x6a: S('enemy_death2_s', 0xa0, 16, 14, [31424, 31432]),
  0x6b: S('enemy_death2_sw', 0xa0, 16, 14, [31440, 31448]),
  0x6c: S('enemy_death2_w', 0xa0, 16, 14, [31456, 31464]),
  0x6d: S('enemy_death2_nw', 0xa0, 16, 14, [31472, 31480]),
  0x6e: S('enemy_death2_n', 0xa0, 16, 14, [31488, 31496]),
  0x6f: S('enemy_death2_ne', 0xa0, 16, 14, [31504, 31512]),
  0x70: S('enemy_death2_e', 0xa0, 16, 14, [33600, 33608]),
  0x71: S('enemy_death2_se', 0xa0, 16, 14, [33616, 33624]),
  0x72: S('enemy_still_s', 0xa0, 16, 14, [33632, 33640, 33648]),
  0x73: S('enemy_still_sw', 0xa0, 16, 14, [33656, 33664, 33672]),
  0x74: S('enemy_still_w', 0xa0, 16, 14, [33680, 33688, 33696]),
  0x75: S('enemy_still_nw', 0xa0, 16, 14, [33704, 33712, 33720]),
  0x76: S('enemy_still_n', 0xa0, 16, 14, [33728, 33736, 33744]),
  0x77: S('enemy_still_ne', 0xa0, 16, 14, [33752, 35840, 35848]),
  0x78: S('enemy_still_e', 0xa0, 16, 14, [35856, 35864, 35872]),
  0x79: S('enemy_still_se', 0xa0, 16, 14, [35880, 35888, 35896]),
  0x7a: S('salute', 0xa0, 16, 14, [35904, 35912, 35920, 35928, 35936, 35944]),
  0x9f: S('unknown_9f', 0xa0, 16, 14, [15680, 15688, 15696, 15704]),
  0xa4: S('player_death_face_first', 0xa0, 16, 14, [
    17984,
    17992,
    18000,
    18008,
    18016,
    18024,
    18032,
    18040,
  ]),
  0xa6: S('player_death_backwards', 0xa0, 16, 14, [
    40384,
    40392,
    40400,
    40408,
    40416,
    40424,
    40432,
    40440,
  ]),
  0xa7: S('player_death_lying_down', 0xa0, 16, 14, [
    40384,
    40392,
    40400,
    40408,
    40416,
    40424,
    40432,
    40440,
  ]),
  0xa8: S('player_walk_grenade_s', 0xa0, 16, 14, [38112, 38120, 38128]),
  0xa9: S('player_walk_grenade_sw', 0xa0, 16, 14, [38136, 38144, 38152]),
  0xaa: S('player_walk_grenade_w', 0xa0, 16, 14, [38160, 38168, 38176]),
  0xab: S('player_walk_grenade_nw', 0xa0, 16, 14, [38184, 38192, 38200]),
  0xac: S('player_walk_grenade_n', 0xa0, 16, 14, [38208, 38216, 38224]),
  0xad: S('player_walk_grenade_ne', 0xa0, 16, 14, [38232, 40320, 40328, 40336]),
  0xae: S('player_walk_grenade_e', 0xa0, 16, 14, [40336, 40344, 40352]),
  0xaf: S('player_walk_grenade_se', 0xa0, 16, 14, [40360, 40368, 40376]),
  0xb0: S('player_firing_alt_s', 0xa0, 16, 14, [11232]),
  0xb1: S('player_firing_alt_sw', 0xa0, 16, 14, [11240]),
  0xb2: S('player_firing_alt_w', 0xa0, 16, 14, [11248]),
  0xb3: S('player_firing_alt_nw', 0xa0, 16, 14, [11256]),
  0xb4: S('player_firing_alt_n', 0xa0, 16, 14, [11264]),
  0xb5: S('player_firing_alt_ne', 0xa0, 16, 14, [11272]),
  0xb6: S('player_firing_alt_e', 0xa0, 16, 14, [11280]),
  0xb7: S('player_firing_alt_se', 0xa0, 16, 14, [11288]),
  0xb8: S('enemy_firing_s', 0xa0, 16, 14, [33632]),
  0xb9: S('enemy_firing_sw', 0xa0, 16, 14, [33640]),
  0xba: S('enemy_firing_w', 0xa0, 16, 14, [33648]),
  0xbb: S('enemy_firing_nw', 0xa0, 16, 14, [33656]),
  0xbc: S('enemy_firing_n', 0xa0, 16, 14, [33664]),
  0xbd: S('enemy_firing_ne', 0xa0, 16, 14, [33672]),
  0xbe: S('enemy_firing_e', 0xa0, 16, 14, [33680]),
  0xbf: S('enemy_firing_se', 0xa0, 16, 14, [33688]),
  0xcc: S('effect_dust', 0xa0, 16, 14, [20184, 20192, 20200, 20208, 20216]),
  0xcd: S('effect_fire_loop', 0xa0, 16, 14, [18072, 20160, 20168, 20176]),
  0xce: S('effect_smoke_column', 0xa0, 16, 14, [
    20256,
    20264,
    20272,
    20280,
    20288,
    20296,
    20304,
  ]),
  0xcf: S('effect_explosion_large', 0xa0, 16, 14, [
    33696,
    33704,
    33712,
    33720,
    33728,
    33736,
    33744,
    33752,
    35840,
    35848,
    35856,
    35864,
    35872,
    35880,
    35888,
    35896,
  ]),
  0xd0: S('effect_explosion_large_alt', 0xa0, 16, 14, [
    33696,
    33704,
    33712,
    33720,
    33728,
    33736,
    33744,
    33752,
    35840,
    35848,
    35856,
    35864,
    35872,
    35880,
    35888,
    35896,
  ]),
  0xd3: S.v('bird_fly_right', 0xa0, [
    F(44832, 16, 14),
    F(44840, 16, 14),
    F(44848, 16, 14),
    F(44856, 16, 14),
    F(44864, 16, 14, 0, 1),
    F(44872, 16, 14, 0, 3),
  ]),
  0xd4: S.v('bird_fly_left', 0xa0, [
    F(44880, 16, 14),
    F(44888, 16, 14),
    F(44896, 16, 14),
    F(44904, 16, 14),
    F(44912, 16, 14, 0, 1),
    F(44920, 16, 14, 0, 3),
  ]),
  0xd5: S('effect_blood_shrapnel', 0xa0, 16, 14, [40448, 40456, 40464]),
  0xd6: S('civilian_death', 0xa0, 16, 14, [
    11296,
    11304,
    11312,
    11320,
    11328,
    11336,
    11344,
    11352,
    13440,
    13448,
  ]),
  0xd7: S('civilian_spear', 0xa0, 16, 14, [
    13448,
    13456,
    13464,
    13472,
    20224,
    20232,
    20240,
    20248,
  ]),
  0xd8: S('death_burning', 0xa0, 16, 14, [
    44928,
    44936,
    44944,
    44952,
    47040,
    47048,
    47056,
    47064,
    47072,
    47080,
    47088,
    47096,
    47104,
    47112,
    47120,
    47128,
    47136,
    47144,
    47152,
    47160,
    47168,
    47176,
    47184,
    47192,
  ]),
  0xd9: S('death_burning_ash', 0xa0, 16, 14, [
    49280,
    49288,
    49296,
    49304,
    49312,
    49320,
    49328,
    49336,
    49344,
    49352,
    49360,
    49368,
    49376,
    49384,
    49392,
    49400,
    49408,
    49416,
    49424,
    49432,
    51520,
    51528,
    51536,
    51544,
  ]),
  0xda: S('death_ash_pile', 0xa0, 16, 14, [51552, 49288, 51560]),
  0xdb: S('death_gibbing', 0xa0, 16, 14, [
    38080,
    38088,
    38096,
    38104,
    51632,
    51640,
    51648,
    51656,
    51664,
    51672,
  ]),
  0xdc: S('death_gibbing_pre', 0xa0, 16, 14, [35960]),
  0xdf: S('effect_explosion_dirt', 0xa0, 16, 14, [
    51584,
    51592,
    51600,
    51608,
    51616,
    51624,
  ]),
  0xe1: S('effect_water_ripple', 0xa0, 16, 14, [51568, 51576, 40472, 35992]),
  0xe2: S('effect_water_splash', 0xa0, 16, 14, [35968, 35976, 35984]),
  0xe3: S('gib_debris', 0xa0, 16, 14, [42624]),
  0xe4: S('gib_arm', 0xa0, 16, 14, [42640]),
  0xe5: S('gib_torso', 0xa0, 16, 14, [42648]),
  0xe6: S('gib_leg', 0xa0, 16, 14, [42656]),
  0xe7: S('effect_blood_pool', 0xa0, 16, 14, [44800, 44808, 44816, 44824]),
};

const _heliDirs = [
  's',
  'ssw',
  'sw',
  'wsw',
  'w',
  'wnw',
  'nw',
  'nnw',
  'n',
  'nne',
  'ne',
  'ene',
];

const _heliFrames = [
  F(13440, 32, 32),
  F(13456, 32, 32),
  F(13472, 32, 32),
  F(13488, 32, 32),
  F(13504, 32, 32),
  F(13520, 32, 32),
  F(13536, 32, 32),
  F(13872, 32, 30, 0, 2),
  F(13568, 32, 32),
  F(13584, 32, 32),
  F(18560, 32, 32),
  F(18576, 32, 32),
  F(18592, 32, 32),
  F(18608, 32, 32),
  F(18624, 32, 32),
  F(18640, 32, 32),
];

/// Sprite groups stored in **\*copt.dat** (`GfxType.inGame2`).
///
/// Per-terrain sprite sheets (juncopt.dat, descopt.dat, etc.) containing
/// helicopters, environment objects, vehicles, text overlays, and UI.
final coptDatIngame = <int, S>{
  0x7b: S('effect_shrapnel_white_0', 0xb0, 16, 1, [
    2240,
    2240,
    2240,
    2240,
    2240,
    2240,
    2240,
    2240,
  ]),
  0x7c: S('effect_shrapnel_white_1', 0xb0, 16, 1, [
    2240,
    2240,
    2240,
    2240,
    2240,
    2240,
    2240,
    2240,
  ]),
  0x7d: S('effect_shrapnel_white_2', 0xb0, 16, 6, [7936, 7944, 7952, 7960]),
  0x7e: S('effect_shrapnel_white_3', 0xb0, 16, 6, [7968, 7976, 7984, 7992]),
  0x7f: S('bullet', 0xb0, 16, 6, [
    8896,
    8904,
    8912,
    8920,
    9856,
    9864,
    9872,
    9880,
  ]),
  ..._dn(0x80, 'helicopter', 0xd0, _heliDirs, _heliFrames),
  0x8c: S('helicopter_rotor', 0xb0, 32, 16, [18656, 18672, 18688, 18704]),
  0x8d: S.v('helicopter_debris', 0xb0, [
    F(21216, 32, 11),
    F(21232, 16, 7),
    F(22352, 16, 5),
  ]),
  0x8e: S.v('pilot', 0xc0, [
    F(0, 16, 15),
    F(8, 32, 25),
    F(120, 32, 28),
    F(136, 48, 38),
    F(4000, 48, 43),
    F(5464, 48, 44),
    F(6768, 48, 42),
  ]),
  0x8f: S('env_shrub', 0xb0, 32, 16, [7752]),
  0x90: S('env_tree', 0xb0, 16, 28, [7768]),
  0x91: S('env_building_roof', 0x90, 32, 12, [10976]),
  0x92: S('env_snowman', 0xb0, 16, 16, [10880]),
  0x93: S('env_shrub2', 0xb0, 32, 15, [10888]),
  0x94: S('env_tree_large_alt', 0xb0, 16, 30, [23840, 23848, 23856]),
  0x95: S('rank', 0xb0, 16, 10, [
    36160,
    36168,
    36176,
    36184,
    36192,
    36200,
    36208,
    36216,
    36224,
    36232,
    36240,
    36248,
    36256,
    36264,
    36272,
    36280,
  ]),
  0x96: S('effect_sparks_0', 0xb0, 16, 6, [9088, 9096, 9104, 9112]),
  0x97: S.v('effect_sparks_1', 0xb0, [F(10992, 16, 3), F(11000, 16, 4)]),
  0x98: S('effect_sparks_2', 0xb0, 16, 13, [23864, 23872]),
  0x99: S('effect_sparks_3', 0xb0, 16, 15, [23880]),
  0x9a: S('fence_wood', 0xb0, 16, 11, [25176, 25184, 25192, 25200]),
  0x9b: S('env_building_window', 0xb0, 16, 15, [23888]),
  0x9c: S('wall_stone', 0xb0, 16, 8, [23896, 23904, 23912, 23920]),
  0x9d: S('bones_and_shadows', 0xb0, 16, 7, [
    11328,
    11336,
    11344,
    11352,
    12448,
    12456,
    12464,
    12472,
  ]),
  0x9e: S('env_building_piece', 0xb0, 16, 10, [26264, 26272]),
  0xa0: S('text_phase_complete', 0xc0, 128, 20, [31840]),
  0xa1: S('text_mission_complete', 0xc0, 80, 20, [28216]),
  0xa2: S('text_mission_failed', 0xc0, 112, 20, [28640]),
  0xa3: S('player_parachute_rotation', 0xb0, 16, 5, [
    21080,
    21088,
    21096,
    21104,
    21112,
    21880,
    21888,
    21896,
    21904,
    21912,
    22680,
    22688,
    22696,
    22704,
    22712,
    23480,
  ]),
  0xa5: S.v('jeep_body', 0xe0, [
    F(26992, 32, 28),
    F(49680, 32, 27),
    F(27008, 32, 28),
    F(45840, 32, 24),
    F(27024, 32, 28),
    F(45856, 32, 23),
    F(31440, 32, 28),
    F(45872, 32, 25),
    F(31456, 32, 28),
    F(45888, 32, 25),
    F(31472, 32, 28),
    F(45904, 32, 23),
    F(31488, 32, 28),
    F(49872, 32, 25),
    F(31504, 32, 28),
    F(49536, 32, 27),
  ]),
  0xc0: S.v('building_large', 0xc0, [
    F(24, 48, 34),
    F(48, 48, 42),
    F(72, 48, 48),
    F(96, 48, 48),
  ]),
  0xc1: S('text_game_over', 0xc0, 96, 25, [24064]),
  0xc2: S('ui_pixel_block_0', 0xb0, 16, 13, [10312]),
  0xc3: S('ui_pixel_block_1', 0xb0, 16, 13, [10320]),
  0xc4: S('doorway', 0xb0, 16, 4, [23648, 23656, 23664, 23672]),
  0xc5: S('box_wood', 0xb0, 16, 6, [24280, 25240, 25248]),
  0xc6: S('effect_structure_debris', 0xb0, 16, 6, [24288, 24296, 24304, 24312]),
  0xc7: S('ui_pixel_block_2', 0xb0, 16, 4, [26272]),
  0xc8: S('ui_pixel_block_3', 0xb0, 16, 13, [26280]),
  0xc9: S('death_gibbing_alt', 0xb0, 16, 17, [
    38080,
    38088,
    38096,
    38104,
    38112,
  ]),
  0xca: S('ui_pixel_block_4', 0xc0, 64, 17, [38120]),
  0xcb: S.v('ui_pixel_block_5', 0xc0, [F(38152, 96, 17, 10, 0)]),
  0xd1: S.v('tank_body', 0xd0, [
    F(41072, 32, 30),
    F(45824, 32, 31),
    F(40960, 32, 30),
    F(49584, 32, 23, 0, -2),
    F(41776, 32, 23, 0, -2),
    F(45760, 32, 23, 0, -2),
    F(40992, 32, 29),
    F(45776, 32, 31),
    F(41008, 32, 30),
    F(45792, 32, 31),
    F(41024, 32, 29),
    F(49440, 32, 23, 0, -2),
    F(41840, 32, 23, 0, -2),
    F(49888, 32, 23, 0, -2),
    F(41056, 32, 30),
    F(45808, 32, 31),
  ]),
  0xd2: S.v('tank_turret', 0xd0, [
    F(28256, 16, 19),
    F(28264, 16, 17, -2, -2),
    F(39344, 32, 15, -13, -4),
    F(41888, 32, 12, -13, -7),
    F(43968, 32, 12, -13, -7),
    F(41904, 32, 12, -13, -7),
    F(36128, 32, 15, -10, -7),
    F(31904, 16, 18, -1, -7),
    F(31912, 16, 19, -1, -7),
    F(39008, 16, 18, -1, -7),
    F(5400, 32, 15, -5, -7),
    F(38744, 32, 13, -2, -7),
    F(43984, 32, 12, -6, -7),
    F(11952, 32, 12, -10, -7),
    F(36144, 32, 14, -6, -5),
    F(39016, 16, 17, -1, -2),
  ]),
  0xdd: S('text_try_again', 0xd0, 32, 20, [50736]),
  0xde: S('effect_smoke_puff_alt', 0xb0, 16, 16, [
    50752,
    50760,
    50768,
    50776,
    50784,
  ]),
  0xe0: S('env_building_piece_alt', 0xb0, 16, 13, [26288]),
};

/// Sprite groups stored in **hillbits.dat** (`GfxType.hill`).
///
/// Contains hill terrain pieces.
final hillbitsDatHill = <int, S>{
  0x00: S('hill_base_0', 0xb0, 16, 16, [5144, 5152, 5160, 5168, 5176]),
  0x01: S('hill_base_1', 0xb0, 16, 16, [7704, 7712, 7720, 7728, 7736]),
  0x02: S('hill_base_2', 0xb0, 16, 16, [10264, 10272, 10280, 10288, 10296]),
  0x03: S('hill_base_3', 0xb0, 16, 16, [12824, 12832, 12840, 12848, 12856]),
  0x04: S('hill_base_4', 0xb0, 16, 16, [15384, 15392, 15400, 15408, 15416]),
  0x05: S('hill_base_5', 0xb0, 16, 16, [17944, 17952, 17960, 17968, 17976]),
  0x06: S('hill_base_6', 0xb0, 16, 16, [20504, 20512, 20520, 20528, 20536]),
  0x07: S('hill_base_7', 0xb0, 16, 16, [23064, 23072, 23080, 23088, 23096]),
  0x08: S('hill_base_8', 0xb0, 16, 16, [25624, 25632, 25640, 25648, 25656]),
  0x09: S.v('hill_piece', 0xb0, [
    F(41234, 16, 13),
    F(46034, 32, 16),
    F(51794, 32, 32),
  ]),
  0x0a: S('hill_variant_0', 0xb0, 16, 16, [5192, 5200, 5208]),
  0x0b: S('hill_variant_1', 0xb0, 16, 16, [5216, 5224, 5232]),
  0x0c: S('hill_variant_2', 0xb0, 16, 16, [5240, 5248, 5256]),
  0x0d: S('hill_variant_3', 0xb0, 16, 16, [7752, 7760, 7768]),
  0x0e: S('hill_variant_4', 0xb0, 16, 16, [7776, 7784, 7792]),
  0x0f: S('hill_variant_5', 0xb0, 16, 16, [7800, 7808, 7816]),
  0x10: S('hill_variant_6', 0xb0, 16, 16, [10312, 10320, 10328]),
  0x11: S('hill_variant_7', 0xb0, 16, 16, [10336, 10344, 10352]),
  0x12: S('hill_variant_8', 0xb0, 16, 16, [10360, 10368, 10376]),
  0x13: S('hill_variant_9', 0xb0, 16, 16, [12872, 12880, 12888]),
  0x14: S('hill_variant_10', 0xb0, 16, 16, [12896, 12904, 12912]),
  0x15: S('hill_variant_11', 0xb0, 16, 16, [12920, 12928, 12936]),
  0x16: S('hill_variant_12', 0xb0, 16, 16, [15432, 15440, 15448]),
  0x17: S('hill_variant_13', 0xb0, 16, 16, [15456, 15464, 15472]),
  0x18: S('hill_variant_14', 0xb0, 16, 16, [15480, 15488, 15496]),
  0x19: S('hill_variant_15', 0xb0, 16, 16, [17992, 18000, 18008]),
  0x1a: S('hill_variant_16', 0xb0, 16, 16, [18016, 18024, 18032]),
  0x1b: S('hill_variant_17', 0xb0, 16, 16, [18040, 18048, 18056]),
  0x1c: S('hill_variant_18', 0xb0, 16, 16, [20552, 20560, 20568]),
  0x1d: S('hill_variant_19', 0xb0, 16, 16, [20576, 20584, 20592]),
  0x1e: S('hill_variant_20', 0xb0, 16, 16, [20600, 20608, 20616]),
  0x1f: S('hill_variant_21', 0xb0, 16, 16, [23112, 23120, 23128]),
  0x20: S('hill_variant_22', 0xb0, 16, 16, [23136, 23144, 23152]),
  0x21: S('hill_variant_23', 0xb0, 16, 16, [23160, 23168, 23176]),
  0x22: S('truck', 0xb0, 16, 18, [
    5856,
    5864,
    5872,
    5880,
    5888,
    5896,
    9696,
    9704,
    9712,
    9720,
    9728,
    9736,
  ]),
};

/// Sprite groups stored in **hillbits.dat** (`GfxType.recruit`).
///
/// Contains recruit screen sprites.
final hillbitsDatRecruit = <int, S>{
  0x00: S('grave', 0xb0, 16, 16, [
    10880,
    10888,
    10896,
    10904,
    10912,
    10920,
    10928,
    10936,
    10944,
  ]),
  0x01: S('face_front_color1', 0xb0, 16, 13, [5600, 5608]),
  0x02: S('face_front_left_color1', 0xb0, 16, 13, [5616, 5624]),
  0x03: S('face_left_color1', 0xb0, 16, 13, [5632, 5640]),
  0x04: S('face_front_color2', 0xb0, 16, 13, [5648, 5656]),
  0x05: S('face_front_left_color2', 0xb0, 16, 13, [5664, 5672]),
  0x06: S('face_left_color2', 0xb0, 16, 13, [5680, 5688]),
  0x07: S('face_front_color3', 0xb0, 16, 13, [8160, 8168]),
  0x08: S('face_front_left_color3', 0xb0, 16, 13, [8176, 8184]),
  0x09: S('face_left_color3', 0xb0, 16, 13, [8192, 8200]),
  0x0a: S('face_front_color4', 0xb0, 16, 13, [8208, 8216]),
  0x0b: S('face_front_left_color4', 0xb0, 16, 13, [8224, 8232]),
  0x0c: S('face_left_color4', 0xb0, 16, 13, [8240, 8248]),
  0x0d: S('font_recruit_alpha', 0xb0, 16, 13, [
    0,
    8,
    16,
    24,
    32,
    40,
    48,
    56,
    64,
    72,
    80,
    88,
    96,
    104,
    112,
    120,
    128,
    136,
    144,
    152,
    2560,
    2568,
    2576,
    2584,
    2592,
    2600,
    2608,
    2616,
    2624,
    2632,
    2640,
    2648,
    2656,
    2664,
    2672,
    2680,
  ]),
  0x0e: S('ui_colon', 0xb0, 16, 13, [2688]),
  0x0f: S('ui_cursor', 0xb0, 16, 13, [2696]),
  0x10: S('ui_blank', 0xb0, 16, 13, [2704]),
  0x11: S('ui_extended_chars', 0xb0, 16, 19, [
    13440,
    13448,
    13456,
    13464,
    13472,
    13480,
    13488,
    13496,
    13504,
    13512,
    13520,
    13528,
    13536,
    13544,
    13552,
    13560,
    13568,
    13576,
    13584,
    13592,
    16488,
    16496,
    16504,
  ]),
  0x12: S('ui_caret', 0xb0, 16, 19, [16480]),
  0x13: S('ui_underscore', 0xb0, 16, 1, [38528]),
  0x14: S.v('hill_overlay', 0xb0, [
    F(13544, 16, 13),
    F(13560, 32, 16),
    F(13580, 32, 30),
  ]),
  0x15: S('truck', 0xb0, 16, 18, [
    5856,
    5864,
    5872,
    5880,
    5888,
    5896,
    9696,
    9704,
    9712,
    9720,
    9728,
    9736,
  ]),
  0x16: S('ui_disk_icon', 0xb0, 32, 22, [5904]),
  0x17: S('ui_disk_part', 0xb0, 16, 16, [5904]),
  0x18: S('ui_disk_load', 0xb0, 16, 24, [10952]),
  0x19: S('ui_disk_save', 0xb0, 16, 24, [10960, 10968]),
};

// ---------------------------------------------------------------------------
// Lookup helpers
// ---------------------------------------------------------------------------

/// Returns `true` if [groupName] represents a font group.
bool isFontGroup(String groupName) => groupName.startsWith('font_');

/// Normalises a sheet type name to a canonical lookup key.
String normaliseSheetName(String sheetTypeName) =>
    sheetTypeName.toLowerCase().replaceAll('_cf2', '').replaceAll('_cf1', '');

/// Returns the merged Dart [SpriteGroup] map for a parsed sheet, or `null`
/// if no Dart map exists for this sheet type.
Map<int, SpriteGroup>? dartMapForSheet(SpriteSheetType sheet) =>
    _sheetNameTables[normaliseSheetName(sheet.name)];

/// Returns the [S] for a given sheet type and group index.
S? spriteGroup({required String sheetTypeName, required int groupIndex}) {
  final table = _sheetNameTables[normaliseSheetName(sheetTypeName)];
  return table?[groupIndex];
}

/// Returns the human-readable group name for a sheet/group pair.
String? spriteGroupName({
  required String sheetTypeName,
  required int groupIndex,
}) => spriteGroup(sheetTypeName: sheetTypeName, groupIndex: groupIndex)?.name;

/// Returns the fully-qualified sprite name for a single frame.
String spriteFrameName({
  required String sheetTypeName,
  required int groupIndex,
  required int frameIndex,
}) {
  final group = spriteGroup(
    sheetTypeName: sheetTypeName,
    groupIndex: groupIndex,
  );
  final groupLabel =
      group?.name ?? 'unknown_${groupIndex.toRadixString(16).padLeft(2, '0')}';
  final isFont = isFontGroup(groupLabel);

  String frameSuffix;
  if (isFont &&
      group != null &&
      group.chars != null &&
      frameIndex < group.chars!.length) {
    var c = group.chars![frameIndex];
    frameSuffix = switch (c) {
      ' ' => 'space',
      '/' => 'slash',
      '.' => 'dot',
      ':' => 'colon',
      ';' => 'semicolon',
      ',' => 'comma',
      '!' => 'exclamation',
      '"' => 'quote',
      "'" => 'single_quote',
      '(' => 'lparen',
      ')' => 'rparen',
      '[' => 'lbracket',
      ']' => 'rbracket',
      '?' => 'question',
      '-' => 'dash',
      '+' => 'plus',
      '=' => 'equals',
      '£' => 'pound',
      '\$' => 'dollar',
      '%' => 'percent',
      '^' => 'caret',
      '&' => 'ampersand',
      '*' => 'asterisk',
      _ => c,
    };
  } else {
    frameSuffix = isFont
        ? fontCharacterName(frameIndex)
        : frameIndex.toString();
  }

  final displayLabel = isFont ? groupLabel.substring(5) : groupLabel;

  return '${normaliseSheetName(sheetTypeName)}/${displayLabel}_$frameSuffix';
}

final Map<String, Map<int, S>> _sheetNameTables = {
  'ingame': {...armyDatIngame, ...coptDatIngame},
  'service': {...rankfontDatService, ...morphbigDatService},
  'briefing': pstuffDatBriefing,
  'font': fontDatFont,
  'hill': hillbitsDatHill,
  'recruit': hillbitsDatRecruit,
};

const _fontChars = [
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
  'I',
  'J',
  'K',
  'L',
  'M',
  'N',
  'O',
  'P',
  'Q',
  'R',
  'S',
  'T',
  'U',
  'V',
  'W',
  'X',
  'Y',
  'Z',
  '0',
  '1',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  "'",
  '.',
  ',',
  '!',
  '(',
  ')',
  '-',
  '?',
  '/',
  ':',
  ';',
  '"',
  '+',
  '=',
  '*',
  '&',
  '%',
  r'$',
  '#',
  '@',
  ' ',
  'a',
  'b',
  'c',
  'd',
  'e',
  'f',
  'g',
  'h',
  'i',
  'j',
  'k',
  'l',
  'm',
  'n',
  'o',
  'p',
  'q',
  'r',
  's',
  't',
  'u',
  'v',
  'w',
  'x',
  'y',
  'z',
];

String fontCharacterName(int frameIndex) {
  if (frameIndex < 0 || frameIndex >= _fontChars.length) {
    return 'char_$frameIndex';
  }
  final char = _fontChars[frameIndex];
  return switch (char) {
    ' ' => 'space',
    '/' => 'slash',
    _ => char,
  };
}
