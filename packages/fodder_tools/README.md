# Fodder Tools

A collection of Dart-based tools for extracting and processing original Cannon Fodder assets.

## Tools Overview

### 1. Archive Tool (`tool/archive/main.dart`)

Extracts and decompresses files from original `.DAT` archives (e.g., `CF_ENG.DAT`).

**Usage:**

```bash
dart tool/archive/main.dart -i <path_to_dat> -o assets/extracted --extract-all
```

**Options:**

- `-i, --input`: Path to the `.DAT` file.
- `-o, --output`: Output directory for extracted files.
- `-e, --extract-all`: Decompress and save all files.

---

### 2. Sprite Tool (`bin/sprites.dart`)

Processes graphics data from extracted assets into standard PNG and TexturePacker JSON files.

**Usage:**

```bash
dart run bin/sprites.dart -d <path_to_dat> -o assets/original/sprites --sprites
```

**Options:**

- `-d, --dat`: Path to `.DAT` archive (e.g., `CF_ENG.DAT`).
- `-i, --input`: Path to pre-extracted directory (alternative to `-d`).
- `-o, --output`: Output directory for images and JSONs.
Atlas JSON files are always generated alongside the PNGs.

---

### 3. Sprite Audit Tool (`bin/audit_sprite_names.dart`)

Validates `lib/sprite_names.dart` against OpenFodder's C++ sprite definitions
(`SpriteData_PC.hpp`). Checks frame counts, byte offsets, dimensions, and
rendering offsets for every sprite group. Run after editing sprite_names.dart to
catch typos or drift.

**Usage:**

```bash
dart run bin/audit_sprite_names.dart
```

---

## Standardization Policy

- **Input**: Use `-i, --input` for primary source paths.
- **Output**: Use `-o, --output` for destination paths.
- **Help**: Always provide `-h, --help`.
- **Naming**: Prefer descriptive, lowercase flag names.

---

## Sprite Naming & File Routing

Each sprite's atlas name has the form `{sheetType}/{groupLabel}_{frameSuffix}`.
The **sheet type** (from the JSON metadata) determines the path prefix, but the
**actual .dat/.png file** the sprite lives in depends on the frame's `GfxType`:

| Sheet type JSON       | Atlas prefix | .dat file(s)               | GfxType              |
|-----------------------|--------------|----------------------------|----------------------|
| `font`                | `font/`      | font.dat                   | `font`               |
| `briefing`            | `pstuff/`    | pstuff.dat                 | `briefing`           |
| `hill`                | `hill/`      | hillbits.dat               | `hill`               |
| `recruit`             | `recruit/`   | hillbits.dat               | `recruit`            |
| `ingame_cf1/cf2`      | `ingame/`    | \*army.dat, \*copt.dat     | `inGame`, `inGame2`  |
| `service`             | `service/`   | rankfont.dat, morphbig.dat | `rankFont`, `service` |

So for example, `service/font_gameplay_caps_A` is in **rankfont.json** (not
morphbig.json), because those frames have `GfxType.rankFont`.

Group-to-name mappings are defined in
[`lib/sprite_names.dart`](lib/sprite_names.dart). Font groups use character
names as frame suffixes (e.g. `A`, `space`); all others use numeric indices.

---

## Sprite Pipeline

The sprite system has two stages:

```
lib/sprite_names.dart                  (S/F classes — single source of truth)
        │
        │  + original_game/*.dat       (raw pixel data)
        ▼  dart run bin/sprites.dart
packages/fodder_assets/assets/         (atlas PNGs + JSONs for the game)
```

### Stage 1 — Hand-maintained sprite metadata

[`lib/sprite_names.dart`](lib/sprite_names.dart) is the single source of truth
for all sprite metadata. It maps group indices to `S`/`F` objects containing
name, palette, dimensions, and byte offsets. Edit this file directly when adding
or changing sprite entries.

To validate against the OpenFodder C++ source:

```bash
dart run bin/audit_sprite_names.dart
```

The audit tool parses [`SpriteData_PC.hpp`](../../vendor/openfodder/Source/PC/SpriteData_PC.hpp)
and compares every group's frame count, offsets, and dimensions. Currently the
Dart maps use CF1 as the baseline, so two CF2-only differences are expected.

**Supporting code:**
- [`lib/sprite_data_parser.dart`](lib/sprite_data_parser.dart) — parses C++
  `sSpriteSheet` arrays and pointer tables into `SpriteSheetType` / `SpriteFrame`
  objects (used by the audit tool).

### Stage 2 — Export atlas images (per terrain)

**Input:** Original `.dat` pixel files + `sprite_names.dart` for frame naming.

**Tool:** [`bin/sprites.dart`](bin/sprites.dart)

**Output:** Atlas PNGs + TexturePacker-format JSONs in
[`packages/fodder_assets/`](../../packages/fodder_assets/). These are what the
game loads at runtime.
