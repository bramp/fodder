#!/usr/bin/env python3
"""Generate compact sprite_names.dart from JSON sprite sheet data + names.

Reads the JSON files in tool/sprites/data/ and produces the complete
sprite_names.dart using spread helpers (_d8, _dn) for directional groups
and compact S() constructors for uniform-frame groups.

Usage:
    cd packages/fodder_tools
    python3 tool/sprites/generate_sprite_names.py > lib/sprite_names.dart
"""

import json
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(SCRIPT_DIR, 'data')

# ---------------------------------------------------------------------------
# Name dictionaries
# ---------------------------------------------------------------------------

_DIRS8 = ['s', 'sw', 'w', 'nw', 'n', 'ne', 'e', 'se']

def _directional(base, prefix):
    return {base + i: f'{prefix}_{d}' for i, d in enumerate(_DIRS8)}

def _font(group, prefix):
    return {group: f'font_{prefix}'}


fontDatFont = {**_font(0, 'main')}

pstuffDatBriefing = {
    **_font(0, 'dark_green'),
    **_font(1, 'light_green'),
    **_font(2, 'blue'),
    **_font(3, 'light_blue'),
}

rankfontDatService = {
    0: 'ui_bg_panel_tile_dark',
    1: 'ui_bg_panel_tile_light',
    2: 'rank_icon',
    **_font(3, 'gameplay_caps'),
    **_font(4, 'gameplay_full'),
    5: 'ui_bg_panel_strip_dark',
    6: 'ui_bg_panel_strip_light',
    9: 'ui_text_lost_heroes_right',
}

morphbigDatService = {
    7: 'ui_soldier_large_portrait_left',
    8: 'ui_soldier_large_portrait_right',
}

# Directional sets as (base_index, prefix).
ARMY_DIRECTIONAL = [
    (0x00, 'player_walk'),
    (0x08, 'player_throw'),
    (0x10, 'player_prone'),
    (0x18, 'player_swim'),
    (0x20, 'player_death'),
    (0x28, 'player_death2'),
    (0x42, 'enemy_walk'),
    (0x4A, 'enemy_throw'),
    (0x52, 'enemy_prone'),
    (0x5A, 'enemy_swim'),
    (0x62, 'enemy_death'),
    (0x6A, 'enemy_death2'),
    (0x72, 'enemy_still'),
    (0xa8, 'player_walk_grenade'),
    (0xb0, 'player_firing_alt'),
    (0xb8, 'enemy_firing'),
]

ARMY_STANDALONE = {
    0x30: 'player_firing_s',
    0x31: 'player_firing_w',
    0x32: 'player_firing_e',
    0x33: 'explosion',
    0x34: 'bones',
    0x35: 'shadow',
    0x36: 'enemy_rocket',
    0x37: 'grenade_box',
    0x38: 'rocket_box',
    0x39: 'soldier_fired_rocket',
    0x3a: 'soldier_rocket_walk_nw',
    0x3b: 'soldier_rocket_walk_n',
    0x3c: 'soldier_rocket_walk_ne',
    0x3d: 'soldier_rocket_walk_e',
    0x3e: 'soldier_rocket_walk_se',
    0x3f: 'soldier_rocket_walk_s',
    0x40: 'soldier_rocket_walk_sw',
    0x41: 'shrub',
    0x7A: 'salute',
    0x9f: 'unknown_9f',
    0xa4: 'player_death_face_first',
    0xa6: 'player_death_backwards',
    0xa7: 'player_death_lying_down',
    0xcc: 'effect_dust',
    0xcd: 'effect_fire_loop',
    0xce: 'effect_smoke_column',
    0xcf: 'effect_explosion_large',
    0xd0: 'effect_explosion_large_alt',
    0xd3: 'bird_fly_right',
    0xd4: 'bird_fly_left',
    0xd5: 'effect_blood_shrapnel',
    0xd6: 'civilian_death',
    0xd7: 'civilian_spear',
    0xd8: 'death_burning',
    0xd9: 'death_burning_ash',
    0xda: 'death_ash_pile',
    0xdb: 'death_gibbing',
    0xdc: 'death_gibbing_pre',
    0xdf: 'effect_explosion_dirt',
    0xe1: 'effect_water_ripple',
    0xe2: 'effect_water_splash',
    0xe3: 'gib_debris',
    0xe4: 'gib_arm',
    0xe5: 'gib_torso',
    0xe6: 'gib_leg',
    0xe7: 'effect_blood_pool',
}

# Build full army name dict for fallback.
armyDatIngame = {}
for base, prefix in ARMY_DIRECTIONAL:
    armyDatIngame.update(_directional(base, prefix))
armyDatIngame.update(ARMY_STANDALONE)

# Helicopter groups: 12 directions, all share identical frame data.
HELI_DIRS = ['s', 'ssw', 'sw', 'wsw', 'w', 'wnw', 'nw', 'nnw', 'n', 'nne', 'ne', 'ene']
HELI_RANGE = (0x80, 0x8b)  # inclusive

COPT_STANDALONE = {
    0x7B: 'effect_shrapnel_white_0',
    0x7C: 'effect_shrapnel_white_1',
    0x7D: 'effect_shrapnel_white_2',
    0x7E: 'effect_shrapnel_white_3',
    0x7F: 'bullet',
    0x8c: 'helicopter_rotor',
    0x8d: 'helicopter_debris',
    0x8e: 'pilot',
    0x8F: 'env_shrub',
    0x90: 'env_tree',
    0x91: 'env_building_roof',
    0x92: 'env_snowman',
    0x93: 'env_shrub2',
    0x94: 'env_tree_large_alt',
    0x95: 'rank',
    0x96: 'effect_sparks_0',
    0x97: 'effect_sparks_1',
    0x98: 'effect_sparks_2',
    0x99: 'effect_sparks_3',
    0x9a: 'fence_wood',
    0x9b: 'env_building_window',
    0x9c: 'wall_stone',
    0x9d: 'bones_and_shadows',
    0x9e: 'env_building_piece',
    0x9f: 'soldier_rocket_aim',
    0xa0: 'text_phase_complete',
    0xa1: 'text_mission_complete',
    0xa2: 'text_mission_failed',
    0xa3: 'player_parachute_rotation',
    0xa5: 'jeep_body',
    0xc0: 'building_large',
    0xc1: 'text_game_over',
    0xc2: 'ui_pixel_block_0',
    0xc3: 'ui_pixel_block_1',
    0xc4: 'doorway',
    0xc5: 'box_wood',
    0xc6: 'effect_structure_debris',
    0xc7: 'ui_pixel_block_2',
    0xc8: 'ui_pixel_block_3',
    0xc9: 'death_gibbing_alt',
    0xca: 'ui_pixel_block_4',
    0xcb: 'ui_pixel_block_5',
    0xd1: 'tank_body',
    0xd2: 'tank_turret',
    0xdd: 'text_try_again',
    0xde: 'effect_smoke_puff_alt',
    0xe0: 'env_building_piece_alt',
}

coptDatIngame = {}
for i, d in enumerate(HELI_DIRS):
    coptDatIngame[HELI_RANGE[0] + i] = f'helicopter_{d}'
coptDatIngame.update(COPT_STANDALONE)

hillbitsDatHill = {
    0x00: 'hill_base_0', 0x01: 'hill_base_1', 0x02: 'hill_base_2',
    0x03: 'hill_base_3', 0x04: 'hill_base_4', 0x05: 'hill_base_5',
    0x06: 'hill_base_6', 0x07: 'hill_base_7', 0x08: 'hill_base_8',
    0x09: 'hill_piece',
    0x0a: 'hill_variant_0', 0x0b: 'hill_variant_1', 0x0c: 'hill_variant_2',
    0x0d: 'hill_variant_3', 0x0e: 'hill_variant_4', 0x0f: 'hill_variant_5',
    0x10: 'hill_variant_6', 0x11: 'hill_variant_7', 0x12: 'hill_variant_8',
    0x13: 'hill_variant_9', 0x14: 'hill_variant_10', 0x15: 'hill_variant_11',
    0x16: 'hill_variant_12', 0x17: 'hill_variant_13', 0x18: 'hill_variant_14',
    0x19: 'hill_variant_15', 0x1a: 'hill_variant_16', 0x1b: 'hill_variant_17',
    0x1c: 'hill_variant_18', 0x1d: 'hill_variant_19', 0x1e: 'hill_variant_20',
    0x1f: 'hill_variant_21', 0x20: 'hill_variant_22', 0x21: 'hill_variant_23',
    0x22: 'truck',
}

hillbitsDatRecruit = {
    0x00: 'grave',
    0x01: 'face_front_color1', 0x02: 'face_front_left_color1',
    0x03: 'face_left_color1',
    0x04: 'face_front_color2', 0x05: 'face_front_left_color2',
    0x06: 'face_left_color2',
    0x07: 'face_front_color3', 0x08: 'face_front_left_color3',
    0x09: 'face_left_color3',
    0x0a: 'face_front_color4', 0x0b: 'face_front_left_color4',
    0x0c: 'face_left_color4',
    **_font(0x0d, 'recruit_alpha'),
    0x0e: 'ui_colon', 0x0f: 'ui_cursor',
    0x10: 'ui_blank', 0x11: 'ui_extended_chars',
    0x12: 'ui_caret', 0x13: 'ui_underscore',
    0x14: 'hill_overlay', 0x15: 'truck',
    0x16: 'ui_disk_icon', 0x17: 'ui_disk_part',
    0x18: 'ui_disk_load', 0x19: 'ui_disk_save',
}


# ---------------------------------------------------------------------------
# JSON config per map variable
# ---------------------------------------------------------------------------

JSON_TO_VARS = [
    ('sprite_sheet_font.json', 'fontDatFont', fontDatFont, None,
     '/// Sprite groups stored in **font.dat** (`GfxType.font`).\n'
     '///\n/// Contains the main game font.'),
    ('sprite_sheet_briefing.json', 'pstuffDatBriefing', pstuffDatBriefing, None,
     '/// Sprite groups stored in **pstuff.dat** (`GfxType.briefing`).\n'
     '///\n/// Contains the briefing screen fonts.'),
    ('sprite_sheet_service.json', 'rankfontDatService', rankfontDatService, 'rankFont',
     '/// Sprite groups stored in **rankfont.dat** (`GfxType.rankFont`).\n'
     '///\n/// Contains rank screen fonts and UI elements.'),
    ('sprite_sheet_service.json', 'morphbigDatService', morphbigDatService, 'service',
     '/// Sprite groups stored in **morphbig.dat** (`GfxType.service`).\n'
     '///\n/// Contains large service screen portraits.'),
    ('sprite_sheet_ingame_cf1.json', 'armyDatIngame', armyDatIngame, 'inGame',
     '/// Sprite groups stored in **\\*army.dat** (`GfxType.inGame`).\n'
     '///\n/// Per-terrain sprite sheets (junarmy.dat, desarmy.dat, etc.) containing\n'
     '/// all soldier animations, effects, and ground-level visuals.'),
    ('sprite_sheet_ingame_cf1.json', 'coptDatIngame', coptDatIngame, 'inGame2',
     '/// Sprite groups stored in **\\*copt.dat** (`GfxType.inGame2`).\n'
     '///\n/// Per-terrain sprite sheets (juncopt.dat, descopt.dat, etc.) containing\n'
     '/// helicopters, environment objects, vehicles, text overlays, and UI.'),
    ('sprite_sheet_hill.json', 'hillbitsDatHill', hillbitsDatHill, None,
     '/// Sprite groups stored in **hillbits.dat** (`GfxType.hill`).\n'
     '///\n/// Contains hill terrain pieces.'),
    ('sprite_sheet_recruit.json', 'hillbitsDatRecruit', hillbitsDatRecruit, None,
     '/// Sprite groups stored in **hillbits.dat** (`GfxType.recruit`).\n'
     '///\n/// Contains recruit screen sprites.'),
]


# ---------------------------------------------------------------------------
# JSON helpers
# ---------------------------------------------------------------------------

def load_json(filename):
    with open(os.path.join(DATA_DIR, filename)) as f:
        return json.load(f)


def get_valid_frames(json_data, group_idx, gfx_filter=None):
    """Get valid (non-empty, matching gfxType) frames for a group."""
    if group_idx >= len(json_data):
        return []
    return [f for f in json_data[group_idx]
            if f.get('width', 0) > 0 and f.get('height', 0) > 0
            and (gfx_filter is None or f.get('gfxType', '') == gfx_filter)]


def is_uniform(frames):
    """True if all frames share w/h and have zero modX/modY."""
    if not frames:
        return True
    w, h = frames[0]['width'], frames[0]['height']
    return all(f['width'] == w and f['height'] == h
               and f.get('modX', 0) == 0 and f.get('modY', 0) == 0
               for f in frames)


# ---------------------------------------------------------------------------
# Dart emission
# ---------------------------------------------------------------------------

MAX_LINE = 80


def fmt_dart_F(frame):
    o, w, h = frame['byteOffset'], frame['width'], frame['height']
    mx, my = frame.get('modX', 0), frame.get('modY', 0)
    if mx != 0 or my != 0:
        return f'F({o}, {w}, {h}, {mx}, {my})'
    return f'F({o}, {w}, {h})'


def wrap_list(items, indent, opener='[', closer=']'):
    """Join items with commas, wrapping at MAX_LINE."""
    prefix = ' ' * indent
    # Try one-line.
    one = f'{opener}{", ".join(items)}{closer}'
    if len(prefix) + len(one) + 10 <= MAX_LINE:
        return one
    # Multi-line.
    lines = [opener]
    line = prefix + '  '
    for i, item in enumerate(items):
        token = item + ','
        if len(line) + len(token) + 1 > MAX_LINE and line.strip():
            lines.append(line)
            line = prefix + '  ' + token
        else:
            line = (line + ' ' + token) if line.strip() else (line + token)
    if line.strip():
        lines.append(line)
    lines.append(prefix + closer)
    return '\n'.join(lines)


def emit_entry(gi, name, pal, frames, indent=2):
    """Emit one map entry: '0xNN: S(...),' or '0xNN: S.v(...),'. """
    pre = ' ' * indent
    key = f'0x{gi:02x}'
    pal_hex = f'0x{pal:02x}'

    if is_uniform(frames):
        w, h = frames[0]['width'], frames[0]['height']
        offsets = [str(f['byteOffset']) for f in frames]
        off_str = wrap_list(offsets, indent + 2)
        body = f"S('{name}', {pal_hex}, {w}, {h}, {off_str})"
        if '\n' not in body:
            return f'{pre}{key}: {body},'
        body_lines = body.split('\n')
        out = f'{pre}{key}: {body_lines[0]}'
        for bl in body_lines[1:]:
            out += '\n' + pre + '  ' + bl
        return out + ','
    else:
        f_strs = [fmt_dart_F(f) for f in frames]
        f_str = wrap_list(f_strs, indent + 2)
        body = f"S.v('{name}', {pal_hex}, {f_str})"
        if '\n' not in body:
            return f'{pre}{key}: {body},'
        body_lines = body.split('\n')
        out = f'{pre}{key}: {body_lines[0]}'
        for bl in body_lines[1:]:
            out += '\n' + pre + '  ' + bl
        return out + ','


def emit_heli_block(base, json_data, gfx_filter, indent=2):
    """Emit ..._dn(...) for helicopter directions + shared frame constant."""
    pre = ' ' * indent
    frames = get_valid_frames(json_data, base, gfx_filter)
    if not frames:
        return '', ''
    pal = frames[0]['paletteIndex']
    pal_hex = f'0x{pal:02x}'
    hex_base = f'0x{base:02x}'

    # Shared constant.
    f_strs = [fmt_dart_F(f) for f in frames]
    const_lines = ['const _heliFrames = [']
    line = '  '
    for fs in f_strs:
        token = fs + ','
        if len(line) + len(token) + 1 > MAX_LINE and line.strip():
            const_lines.append(line)
            line = '  ' + token
        else:
            line = (line + ' ' + token) if line.strip() else (line + token)
    if line.strip():
        const_lines.append(line)
    const_lines.append('];')
    const_section = '\n'.join(const_lines)

    dirs_str = ', '.join(f"'{d}'" for d in HELI_DIRS)
    const_section = (
        f'const _heliDirs = [{dirs_str}];\n\n'
        + const_section
    )

    spread = f"{pre}..._dn({hex_base}, 'helicopter', {pal_hex}, _heliDirs, _heliFrames),"
    return const_section, spread


# ---------------------------------------------------------------------------
# Map emitters
# ---------------------------------------------------------------------------

def emit_map_generic(var_name, name_dict, json_data, gfx_filter, doc):
    lines = [doc, f'final {var_name} = <int, S>{{']
    for gi in range(len(json_data)):
        frames = get_valid_frames(json_data, gi, gfx_filter)
        if not frames:
            continue
        name = name_dict.get(gi, f'unknown_{gi:02x}')
        pal = frames[0]['paletteIndex']
        lines.append(emit_entry(gi, name, pal, frames))
    lines.append('};')
    return '\n'.join(lines)


def emit_army(var_name, name_dict, json_data, gfx_filter, doc):
    lines = [doc, f'final {var_name} = <int, S>{{']
    for gi in range(len(json_data)):
        frames = get_valid_frames(json_data, gi, gfx_filter)
        if not frames:
            continue
        name = name_dict.get(gi, f'unknown_{gi:02x}')
        pal = frames[0]['paletteIndex']
        lines.append(emit_entry(gi, name, pal, frames))
    lines.append('};')
    return '\n'.join(lines)


def emit_copt(var_name, name_dict, json_data, gfx_filter, doc):
    heli_start, heli_end = HELI_RANGE
    heli_indices = set(range(heli_start, heli_end + 1))

    heli_const, heli_spread = emit_heli_block(heli_start, json_data, gfx_filter)

    lines = [doc, f'final {var_name} = <int, S>{{']
    items = []

    if heli_spread:
        items.append((heli_start, heli_spread))

    for gi in range(len(json_data)):
        if gi in heli_indices:
            continue
        frames = get_valid_frames(json_data, gi, gfx_filter)
        if not frames:
            continue
        name = name_dict.get(gi, f'unknown_{gi:02x}')
        pal = frames[0]['paletteIndex']
        items.append((gi, emit_entry(gi, name, pal, frames)))

    items.sort(key=lambda x: x[0])
    for _, s in items:
        lines.append(s)
    lines.append('};')

    map_text = '\n'.join(lines)
    return heli_const, map_text


# ---------------------------------------------------------------------------
# File header / footer
# ---------------------------------------------------------------------------

FILE_HEADER = r"""/// Maps sprite group indices to human-readable names and frame metadata.
///
/// Each map entry contains the group name, palette index, frame dimensions,
/// and byte offsets. This is the single source of truth for sprite metadata —
/// the JSON files in tool/sprites/data/ are now redundant.
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
/// For uniform-size groups (the majority), [S] stores the shared `w`×`h`
/// and a flat `List<int>` of byte offsets — one per frame. For the few
/// groups with mixed frame sizes or rendering offsets, [S.v] stores a
/// `List<F>` with per-frame dimensions.
///
/// The pixel position on the 320-wide sprite sheet can be derived from
/// any byte offset:
///
/// ```
/// x = (byteOffset % 160) * 2
/// y = byteOffset ~/ 160
/// ```
library;

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

/// Metadata for a single sprite frame (used only by variable-size groups).
///
/// The [byteOffset] is the raw offset into the .dat file. The pixel
/// coordinates on the 320-pixel-wide sprite sheet are:
/// - `x = (byteOffset % 160) * 2`
/// - `y = byteOffset ~/ 160`
class F {
  const F(this.byteOffset, this.w, this.h, [this.modX = 0, this.modY = 0]);

  final int byteOffset;
  final int w;
  final int h;
  final int modX;
  final int modY;

  int get pixelX => (byteOffset % 160) * 2;
  int get pixelY => byteOffset ~/ 160;

  @override
  String toString() => 'F($byteOffset, ${w}x$h'
      '${modX != 0 || modY != 0 ? ', mod=$modX,$modY' : ''})';
}

/// A named sprite group with palette index and frame data.
///
/// **Uniform groups** (primary constructor): every frame shares the same
/// [w]×[h] dimensions with no rendering offsets → stored as a flat list of
/// byte [offsets].
///
/// **Variable groups** ([S.v]): frames differ in size or have modX/modY →
/// stored as a `List<F>`.
class S {
  const S(this.name, this.palette, this.w, this.h, this.offsets)
      : frames = const [];

  const S.v(this.name, this.palette, this.frames)
      : w = 0, h = 0, offsets = const [];

  final String name;
  final int palette;
  final int w;
  final int h;
  final List<int> offsets;
  final List<F> frames;

  bool get isVariable => frames.isNotEmpty;
  int get frameCount => isVariable ? frames.length : offsets.length;

  @override
  String toString() => 'S($name, 0x${palette.toRadixString(16)}, '
      '$frameCount frames)';
}

// ---------------------------------------------------------------------------
// Spread helpers
// ---------------------------------------------------------------------------

/// Expands N directional entries that share a single frame list.
Map<int, S> _dn(
  int base, String prefix, int pal, List<String> dirs, List<F> sharedFrames,
) => {
  for (var i = 0; i < dirs.length; i++)
    base + i: S.v('${prefix}_${dirs[i]}', pal, sharedFrames),
};"""


FILE_FOOTER = r"""// ---------------------------------------------------------------------------
// Lookup helpers
// ---------------------------------------------------------------------------

/// Returns `true` if [groupName] represents a font group.
bool isFontGroup(String groupName) => groupName.startsWith('font_');

/// Normalises a sheet type name to a canonical lookup key.
String normaliseSheetName(String sheetTypeName) =>
    sheetTypeName.toLowerCase().replaceAll('_cf2', '').replaceAll('_cf1', '');

/// Returns the [S] for a given sheet type and group index.
S? spriteGroup({
  required String sheetTypeName,
  required int groupIndex,
}) {
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
  final groupLabel =
      spriteGroupName(sheetTypeName: sheetTypeName, groupIndex: groupIndex) ??
      'unknown_${groupIndex.toRadixString(16).padLeft(2, '0')}';

  final isFont = isFontGroup(groupLabel);
  final frameSuffix =
      isFont ? fontCharacterName(frameIndex) : frameIndex.toString();
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
  'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
  'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
  "'", '.', ',', '!', '(', ')', '-', '?', '/', ':', ';', '"',
  '+', '=', '*', '&', '%', r'$', '#', '@',
  ' ',
  'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm',
  'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
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
}"""


def main():
    json_cache = {}
    outputs = []  # (var_name, text, pre_text)

    heli_const_text = ''

    for json_file, var_name, name_dict, gfx_filter, doc in JSON_TO_VARS:
        if json_file not in json_cache:
            json_cache[json_file] = load_json(json_file)
        data = json_cache[json_file]

        if var_name == 'armyDatIngame':
            text = emit_army(var_name, name_dict, data, gfx_filter, doc)
            outputs.append((var_name, text, ''))
        elif var_name == 'coptDatIngame':
            heli_const, map_text = emit_copt(var_name, name_dict, data, gfx_filter, doc)
            outputs.append((var_name, map_text, heli_const))
        else:
            text = emit_map_generic(var_name, name_dict, data, gfx_filter, doc)
            outputs.append((var_name, text, ''))

    print(FILE_HEADER)
    for i, (vn, text, pre) in enumerate(outputs):
        print()
        if pre:
            print(pre)
            print()
        print(text)
    print()
    print(FILE_FOOTER)


if __name__ == '__main__':
    main()
