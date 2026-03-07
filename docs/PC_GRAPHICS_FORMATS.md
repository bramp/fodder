# OpenFodder PC Graphics & Resource Formats

This document serves as a clean-room specification of the PC data, graphics, sprites, and resource file formats used by the Cannon Fodder engine.

This specification is intended to guide a clean Dart reproduction.

---

## 1. Resource Archives

### CD Resource File (`CF_ENG.DAT`)

In the PC CD version of Cannon Fodder, individual `.dat` files are bundled and compressed into an archive usually named `CF_ENG.DAT`.

#### Archive Header

The header acts as a dictionary that maps file names to their compressed payloads:

- `[0x00] uint16`: Pointer/offset to the end of the dictionary.
- `[0x02] uint16`: Unknown or ignored alignment padding.
- **Dictionary Entries** (Looping from byte `0x04` until the `ptrEnd` offset):
  - `uint8 limit`: The length of the file name.
  - `char[limit]`: The file name string (e.g., `army.dat`). Usually converted to lowercase for lookup.
  - `uint32 mAddressStart`: The absolute byte offset in `FODDER.DAT` where the compressed file data begins.
  - `uint32 mSize`: The expected size or compressed size.

#### Decompression

Files within `CF_ENG.DAT` are compressed using **Adaptive Huffman coding** combined
with **LZSS** (Lempel-Ziv-Storer-Szymanski) sliding-window compression.

**Compressed payload layout** (per entry):

| Offset | Size | Description                                |
| ------ | ---- | ------------------------------------------ |
| 0x00   | 4    | `uint32 LE` — Decompressed output size     |
| 0x04   | 4    | `uint32 LE` — Compressed data size (bytes) |
| 0x08   | …    | Compressed bitstream                       |

**Algorithm overview:**

1. **Huffman tree**: An adaptive (dynamic) Huffman tree with 314 leaf symbols
   (indices 0–313) and 627 total nodes is maintained. The tree is rebuilt
   whenever the root frequency reaches `0x8000`. Symbols 0–255 represent
   literal bytes; symbols 256–313 signal a back-reference (copy from the
   sliding window).

2. **Symbol decoding**: Symbols are decoded by walking the Huffman tree from
   the root (node 626) towards the leaves, reading one bit at a time from
   the compressed bitstream. After each symbol is decoded the tree
   frequencies are updated and the affected path is rearranged to maintain
   the sibling property (nodes ordered by ascending frequency).

3. **Literal vs. back-reference**:
   - If the decoded symbol is in range 0–255, it is a literal byte written
     directly to the output and the ring buffer.
   - If the symbol is ≥ 256, it encodes a copy length of
     `symbol - 256 + 3` bytes (i.e. match lengths 3–60). A separate
     distance value is then read from the bitstream using a two-level
     lookup table (`distBitCount` / `distHighBits`), giving a 12-bit
     offset into the 4096-byte ring buffer.

4. **Ring buffer**: A 4096-byte circular buffer (initialised with spaces
   `0x20`, write cursor starting at `0xFC4`) stores recently output bytes.
   Back-references copy from this buffer and also write the copied bytes
   back into it, advancing the cursor modulo 4096.

When fully decompressed, the outputs are standard Cannon Fodder `.dat` files
(sprites, palettes, tiles, etc.).

---

## 2. Palettes

All graphics in the PC version rely on a standard 256-color (8-bit) VGA palette.
When palette blocks are read from `.dat` files, they appear as a flat sequence of **RGB triplets**:

- `uint8 Red`
- `uint8 Green`
- `uint8 Blue`

These channels are **6-bit per channel VGA colors** (values 0–63) which must be
shifted left by 2 (or multiplied by 4) to scale to standard modern 8-bit (0–255)
RGB space.

Palettes are rarely standalone files; they are generally embedded at known fixed
offsets within a `.dat` image file.

### Global Palette Layout

During in-game rendering, different palette regions are reserved for different
purposes:

| Range         | Source                         | Purpose                    |
| ------------- | ------------------------------ | -------------------------- |
| `0x00`–`0x7F` | `*base.blk` at `0xFA00`        | Tile/terrain colours (128) |
| `0x40`–`0xBF` | `rankfont.dat` at `0xA000`     | Rank font (128 colours)    |
| `0x90`–`0x9F` | `*copt.dat` at `0xD360`        | Helicopter palette (16)    |
| `0xA0`–`0xAF` | `*army.dat` at `0xD200`        | Army sprites palette (16)  |
| `0xB0`–`0xEF` | `*copt.dat` at `0xD2A0`        | Helicopter extended (64)   |
| `0xD0`–`0xDF` | `font.dat` at `0xA000`         | Font palette (16)          |
| `0xE0`–`0xEF` | `paraheli.dat` via compositing | Briefing helicopter (16)   |
| `0xF0`–`0xFF` | `pstuff.dat` at `0xA000`       | HUD/sidebar palette (16)   |

---

## 3. Image Types

### 3.1. 4-bit Packed Sprite Sheets

The game's dynamic entities, HUD/sidebar items, fonts, and cursors are stored as
4-bit packed "nibble" sprite sheets. These are large 2D canvases from which
individual sprites are sliced using offset metadata.

#### Format

- **Pitch (row width)**: Fixed at **160 bytes** = **320 pixels** per row.
- **Pixels per byte**: 2 pixels packed per byte.
  - High nibble: `(byte >> 4) & 0x0F` → left pixel
  - Low nibble: `byte & 0x0F` → right pixel
- **Transparency**: Nibble value `0` is transparent.
- **Palette mapping**: Non-zero nibble values (1–15) are OR'd with a
  `basePaletteIndex` to produce a final 8-bit palette index:
  `finalColor = nibbleValue | basePaletteIndex`.

#### Known 4-bit Files

| File           | Palette Offset | Count | Start Index | Purpose                  |
| -------------- | -------------- | ----- | ----------- | ------------------------ |
| `pstuff.dat`   | `0xA000`       | 16    | `0xF0`      | HUD, sidebar, icons      |
| `font.dat`     | `0xA000`       | 16    | `0xD0`      | In-game font             |
| `hillbits.dat` | `0x6900`       | 16    | `0xB0`      | Recruit screen overlays  |
| `rankfont.dat` | `0xA000`       | 128   | `0x40`      | Rank/service screen font |

#### Terrain-Specific Army Sheets (4-bit)

| File          | Palette Offset | Count | Start Index | Purpose           |
| ------------- | -------------- | ----- | ----------- | ----------------- |
| `junarmy.dat` | `0xD200`       | 16    | `0xA0`      | Jungle soldiers   |
| `desarmy.dat` | `0xD200`       | 16    | `0xA0`      | Desert soldiers   |
| `icearmy.dat` | `0xD200`       | 16    | `0xA0`      | Ice soldiers      |
| `morarmy.dat` | `0xD200`       | 16    | `0xA0`      | Moors soldiers    |
| `intarmy.dat` | `0xD200`       | 16    | `0xA0`      | Interior soldiers |

#### Terrain-Specific Helicopter Sheets (4-bit, dual palette)

Helicopter sprite sheets require loading **two** palette regions:

| File          | Palette 1 (offset, count, start) | Palette 2 (offset, count, start) |
| ------------- | -------------------------------- | -------------------------------- |
| `juncopt.dat` | `0xD360`, 16, `0x90`             | `0xD2A0`, 64, `0xB0`             |
| `descopt.dat` | `0xD360`, 16, `0x90`             | `0xD2A0`, 64, `0xB0`             |
| `icecopt.dat` | `0xD360`, 16, `0x90`             | `0xD2A0`, 64, `0xB0`             |
| `morcopt.dat` | `0xD360`, 16, `0x90`             | `0xD2A0`, 64, `0xB0`             |
| `intcopt.dat` | `0xD360`, 16, `0x90`             | `0xD2A0`, 64, `0xB0`             |

TODO(bramp): is sSpriteSheet a OpenFodder term, or a fileformat term?

#### Sprite Lookups (`sSpriteSheet`)

Individual sprites are located within a sheet using the `sSpriteSheet` struct:

| Field           | Type   | Description                                                                |
| --------------- | ------ | -------------------------------------------------------------------------- |
| `mLoadOffset`   | uint16 | Byte offset into the file. Row = `offset / 160`, col byte = `offset % 160` |
| `mColCount`     | uint16 | Sprite width in pixels (reads `mColCount / 2` bytes per row)               |
| `mRowCount`     | uint16 | Sprite height in pixel rows                                                |
| `mPalleteIndex` | uint8  | Base palette index to OR with nibble values                                |
| `mModX`         | int8   | X rendering offset (anchor adjustment)                                     |
| `mModY`         | int8   | Y rendering offset (anchor adjustment)                                     |

#### HUD/Sidebar Icons (`pstuff.dat`)

In addition to briefing fonts, `pstuff.dat` is used as a repository for 209 distinct icons and UI elements. These are defined by absolute pixel coordinates rather than sheet indices.

A prominent set of icons are the **Rank chevrons**:

- **Sidebar Ranks**: 16 icons at `(48, 0)` through `(288, 0)` with size `16 × 11`.
- **Mini Ranks**: Multiple sets of 16 or 20 icons at various vertical offsets (e.g. Y=24, 32, 40, 48, 56, 64) with size `16 × 7`.

These sidebar icons are indexed directly in the engine via the `mSpriteSheet_PStuff` array.

#### Terrain-Specific Lead Soldier Ranks (`*copt.dat`)

The rank icon displayed above the lead soldier in the main play area is actually stored in the terrain-specific helicopter sprite sheet (`juncopt.dat`, `descopt.dat`, etc.) as group index **0x95**.

| Sheet Index | Entries | Dimensions | Name            |
| ----------- | ------- | ---------- | --------------- |
| `0x95`      | 16      | 16 × 10    | In-game ranks   |

These icons use palette index `0xB0` (the 176+ range).

---

### 3.2. 8-bit Linear Images

Background images and service screens use a direct 1-byte-per-pixel raster
format at 320 pixels wide.

#### Known 8-bit Linear Files

| File           | Palette Offset | Count | Start Index | Pixel Area | Resolution |
| -------------- | -------------- | ----- | ----------- | ---------- | ---------- |
| `hill.dat`     | `0xFA00`       | 80    | `0x00`      | `0xFA00`   | 320 × 200  |
| `morphbig.dat` | `0xFA00`       | 64    | `0x00`      | `0xFA00`   | 320 × 200  |
| `cftitle.dat`  | `0xFA00`       | 80    | `0x00`      | `0xFA00`   | 320 × 200  |

These files store `pixelCount` bytes of linear 8-bit pixel data followed by a
palette at `paletteOffset`. Index `0` is typically treated as transparent.

---

### 3.3. Map Tile Blocks (8-bit)

Map terrains (Jungle, Desert, Ice, Moors, Interior) are built from 16×16 pixel
tiles stored inside 320-pixel-wide linear 8-bit canvases.

#### Format

- **Tile dimensions**: 16×16 pixels
- **Canvas layout**: 20 columns × 12 rows = 240 tiles per block file
- **Canvas width**: `20 × 16 = 320` pixels (matches VGA screen width)
- **Palette**: Base blocks store 128 colours at offset `0xFA00`.
  Sub-blocks reuse the palette from their matching base block.

#### Tile Extraction

Tiles are arranged in a grid within the canvas. For sequential tile index `n`:

- Column = `n % 20`, Row = `n / 20`
- Pixel offset = `(row × 16 × 320) + (column × 16)`
- Each tile row reads 16 consecutive bytes, then advances 320 bytes for the next
  pixel row.

#### Known Tile Block Files

**Base blocks** (contain palette at `0xFA00`, 128 colours starting at index 0):

| File          | Terrain  |
| ------------- | -------- |
| `junbase.blk` | Jungle   |
| `desbase.blk` | Desert   |
| `icebase.blk` | Ice      |
| `morbase.blk` | Moors    |
| `intbase.blk` | Interior |

**Sub-blocks** (reuse base block palette, same layout):

| File          | Terrain  | Notes                       |
| ------------- | -------- | --------------------------- |
| `junsub0.blk` | Jungle   | Sub-tileset 0               |
| `junsub1.blk` | Jungle   | Sub-tileset 1 (Jungle only) |
| `dessub0.blk` | Desert   |                             |
| `icesub0.blk` | Ice      |                             |
| `morsub0.blk` | Moors    |                             |
| `intsub0.blk` | Interior |                             |

---

### 3.4. Planar Fullscreen Images (VGA Mode X)

These images correspond to raw DOS VGA Mode X video memory dumps. Each file
is exactly **64,768 bytes**: 64,000 bytes of pixel data + 768 bytes of palette
(256 colours × 3 bytes RGB).

#### Format

The 64,000 pixel bytes are stored in **4 consecutive bit-planes** of 16,000
bytes each, rather than in linear order:

| Plane | Byte Range        | Pixel X-coordinates |
| ----- | ----------------- | ------------------- |
| 0     | `0x0000`–`0x3E7F` | X = 0, 4, 8, 12, …  |
| 1     | `0x3E80`–`0x7CFF` | X = 1, 5, 9, 13, …  |
| 2     | `0x7D00`–`0xBB7F` | X = 2, 6, 10, 14, … |
| 3     | `0xBB80`–`0xF9FF` | X = 3, 7, 11, 15, … |

**Palette**: 768 bytes at `fileSize - 0x300` (offset `0xFC00`). Standard 6-bit
VGA RGB triplets. When `pColors = 0x100`, all 256 colours are loaded.
When `pColors = 0xD0`, only the first 208 colours are loaded.

**De-interleaving** to a linear 320×200 buffer:

```dart
final linear = Uint8List(64000);
var src = 0;
for (var plane = 0; plane < 4; plane++) {
  for (var y = 0; y < 200; y++) {
    for (var x = plane; x < 320; x += 4) {
      linear[y * 320 + x] = data[src++];
    }
  }
}
```

#### Known Planar Fullscreen Files

TODO(bramp): I don't see 1-e.dat as png files.

**Intro sequence images**:

The intro sequence is data-driven via `mIntroText_PC`. Each entry has a
`mImageNumber` field whose ASCII character value becomes the filename.
For example, `0x31` = `'1'` → `1.dat`, `0x38` = `'8'` → `8.dat`.

| File    | `mImageNumber` | `pColors` | Purpose       |
| ------- | -------------- | --------- | ------------- |
| `1.dat` | `0x31`         | `0xD0`    | Intro image 1 |
| `2.dat` | `0x32`         | `0xD0`    | Intro image 2 |
| `3.dat` | `0x33`         | `0xD0`    | Intro image 3 |
| `4.dat` | `0x34`         | `0xD0`    | Intro image 4 |
| `5.dat` | `0x35`         | `0xD0`    | Intro image 5 |
| `6.dat` | `0x36`         | `0xD0`    | Intro image 6 |
| `7.dat` | `0x37`         | `0xD0`    | Intro image 7 |
| `8.dat` | `0x38`         | `0xD0`    | Intro image 8 |

**CF2-only intro images** (additional entries in `mIntroText_PC2`):

| File    | `mImageNumber` | `pColors` | Purpose       |
| ------- | -------------- | --------- | ------------- |
| `9.dat` | `0x39`         | `0xD0`    | Intro image 9 |
| `a.dat` | `0x61`         | `0xD0`    | Intro image A |
| `b.dat` | `0x62`         | `0xD0`    | Intro image B |
| `c.dat` | `0x63`         | `0xD0`    | Intro image C |
| `d.dat` | `0x64`         | `0xD0`    | Intro image D |
| `e.dat` | `0x65`         | `0xD0`    | Intro image E |

**Logo/title images** (loaded via `ShowImage_ForDuration` → `Load_And_Draw_Image`):

| File           | `pColors` | Purpose                |
| -------------- | --------- | ---------------------- |
| `cftitle.dat`  | `0x100`   | Game title screen      |
| `sensprod.dat` | `0x100`   | Sensible Software logo |
| `virgpres.dat` | `0x100`   | Virgin presents logo   |
| `won.dat`      | `0x100`   | Victory/win screen     |

> All logo/title files are 64,768 bytes. They load the full 256-colour palette.
> Note that `cftitle.dat` also appears as an 8-bit linear image (see §3.2) —
> the engine uses both interpretations in different contexts.

---

TODO(bramp): Read below here

### 3.5. Briefing Layer Images (Planar, variable size)

The mission briefing screen displays a horizontally scrolling parallax scene
composed of 5 layered images per terrain tileset, plus a shared helicopter
animation file.

#### Loading (`Mission_Intro_Load_Resources`)

Files are named `{terrain}p{N}.dat` where terrain is `jun`, `des`, `ice`,
`mor`, or `int`, and N is 1–5.

| Variable                       | File      | Layer Purpose             |
| ------------------------------ | --------- | ------------------------- |
| `mImageMissionIntro.mData`     | `*p1.dat` | Foreground (trees/close)  |
| `mMission_Intro_Gfx_Clouds1`   | `*p2.dat` | Cloud layer 1 (middle)    |
| `mMission_Intro_Gfx_Clouds2`   | `*p3.dat` | Cloud layer 2 (back)      |
| `mMission_Intro_Gfx_Clouds3`   | `*p4.dat` | Cloud layer 3 (very back) |
| `mMission_Intro_Gfx_TreesMain` | `*p5.dat` | Trees/ground main layer   |

#### Format

These files are **NOT** full 320×200 images. They are smaller, variable-sized
VGA Mode X planar buffers. The data is still stored as 4 consecutive planes,
but the dimensions vary per file (there is no fixed width/height metadata in
the file itself — the engine uses the `BackgroundPositions` tables and
`mMission_Intro_DrawX`/`mMission_Intro_DrawY` to determine rendering dimensions at draw time).

The blit functions `HeliIntroBlit_OpaqueAlignedX` (opaque) and
`HeliIntro_BlitMaskedAlignedX` (transparent where pixel = 0) write the planar
data directly to the screen surface with horizontal scrolling offsets.

File sizes vary significantly (from ~2.6 KB to ~30 KB):

| File        | Size (bytes) | File        | Size (bytes) |
| ----------- | ------------ | ----------- | ------------ |
| `junp1.dat` | 15,168       | `desp1.dat` | 16,128       |
| `junp2.dat` | 6,528        | `desp2.dat` | 16,128       |
| `junp3.dat` | 18,688       | `desp3.dat` | 25,088       |
| `junp4.dat` | 16,128       | `desp4.dat` | 19,328       |
| `junp5.dat` | 30,208       | `desp5.dat` | 21,248       |
| `icep1.dat` | 15,488       | `morp1.dat` | 16,128       |
| `icep2.dat` | 8,448        | `morp2.dat` | 2,688        |
| `icep3.dat` | 21,888       | `morp3.dat` | 21,248       |
| `icep4.dat` | 12,288       | `morp4.dat` | 10,048       |
| `icep5.dat` | 28,928       | `morp5.dat` | 27,008       |
| `intp1.dat` | 11,968       |             |              |
| `intp2.dat` | 11,648       |             |              |
| `intp3.dat` | 15,808       |             |              |
| `intp4.dat` | 21,248       |             |              |
| `intp5.dat` | 27,328       |             |              |

#### Palette Compositing

The briefing scene palette is assembled from multiple sources:

1. **`*p1.dat`** image contains a 768-byte palette at `fileSize - 0x300`
   (same trailer layout as fullscreen planar images). It provides 256 entries.

2. **`paraheli.dat`** at offset `0xF00` contains terrain-indexed palette data.
   For each tileset `t`, 16 RGB triplets (48 bytes) are at `0xF00 + (0x30 × t)`.
   These are copied over the `*p1.dat` palette at `paletteStart + 0x300 - 0x60`
   (i.e. palette entries `0xE0`–`0xEF`, the helicopter colour region).

3. **`pstuff.dat`** palette at `0xA000` (16 colours) is copied to the last
   16 entries (`0xF0`–`0xFF`) of the briefing palette.

#### Render Order (back to front)

The 5 layers are drawn with parallax scrolling at different speeds:

1. `*p4.dat` — Very back clouds (opaque blit)
2. `*p3.dat` — Back clouds (masked/transparent blit)
3. `*p2.dat` — Middle clouds (masked blit)
4. `*p5.dat` — Trees/ground main (opaque blit)
5. Helicopter sprite (4-bit from `paraheli.dat`, drawn via `Video_Draw_8`)
6. `*p1.dat` — Front foreground (masked blit)

---

### 3.6. Helicopter Animation (`paraheli.dat`)

**Size**: 4,608 bytes (0x1200)

This small file serves a dual purpose:

#### Helicopter Sprite Frames

The first portion contains 4 frames of the briefing helicopter animation,
rendered as 4-bit packed sprites (same format as §3.1).

- Frame size: 32 bytes (0x20) each
- Frame offsets: `[0x00, 0x20, 0x40, 0x60]`
- Dimensions: 64 pixels wide × 24 rows (`mVideo_Draw_Columns = 0x40`,
  `mVideo_Draw_Rows = 0x18`)
- Palette index: `0xE0` (helicopter colours from terrain-specific palette)

#### Terrain Palette Blocks

At offset `0xF00` (3,840 bytes into the file), there are 5 palette blocks,
one per terrain tileset:

| Tileset  | Index | Offset  | Size     |
| -------- | ----- | ------- | -------- |
| Jungle   | 0     | `0xF00` | 48 bytes |
| Desert   | 1     | `0xF30` | 48 bytes |
| Ice      | 2     | `0xF60` | 48 bytes |
| Moors    | 3     | `0xF90` | 48 bytes |
| Interior | 4     | `0xFC0` | 48 bytes |

Each 48-byte block contains 16 RGB triplets (6-bit VGA) that define the
helicopter's colours for that terrain. These are copied into palette entries
`0xE0`–`0xEF` during briefing initialisation.

---

### 3.7. Parallax Position Tables (`BackgroundPositions`)

Each terrain has 5 positions (one per layer) controlling vertical placement
and rendering dimensions. Format: `{ mX (height in rows), mY (byte offset × 4) }`.

BackgroundPositions are hardcoded in the engine:

```
Jungle:  [{0x30, 0x3190}, {0x38, 0x40B0}, {0x12, 0x74F0}, {0x5C, 0x8DB0}, {0x2D, 0xCFB0}]
Desert:  [{0x3A, 0x3190}, {0x4C, 0x4E70}, {0x30, 0x73A0}, {0x40, 0xB590}, {0x30, 0xCB90}]
Ice:     [{0x24, 0x3190}, {0x42, 0x40B0}, {0x18, 0x73A0}, {0x58, 0x9490}, {0x2E, 0xCE50}]
Moors:   [{0x1D, 0x3190}, {0x40, 0x44D0}, {0x06, 0x9490}, {0x52, 0x9CD0}, {0x30, 0xCB90}]
Interior:[{0x40, 0x3190}, {0x2F, 0x5AD0}, {0x22, 0x6CB0}, {0x53, 0x9B70}, {0x23, 0xDD70}]
```

---

## 4. Map Files

### 4.1. Map Data (`.map`)

Map files define the tile layout for each mission phase. File names follow the
pattern `mapm{N}.map` where N is the mission number (1–72 in CF1).

#### Layout

- **Bytes `0x00`–`0x0A`**: Base block filename (e.g., `junbase.blk`, null-padded to 11 bytes)
- **Bytes `0x10`–`0x1A`**: Sub-block filename (e.g., `junsub0.blk`, null-padded to 11 bytes)
- **Bytes `0x50`–`0x53`**: Map marker `ofed` (OpenFodder signature, offset `0x28` in uint16 terms)
- **Bytes `0x54`–`0x55`**: Map width in tiles (big-endian uint16)
- **Bytes `0x56`–`0x57`**: Map height in tiles (big-endian uint16)
- **Byte `0x62` onward**: Tile data — array of uint16 LE tile indices

Each tile index uint16 encodes:

- **Bits 0–12**: Tile graphic index (0–239 from base block, 240–479 from sub-block)
- **Bits 13–15**: Tile track/music zone data (`(value & 0xE000) >> 8`)

### 4.2. Sprite Placement (`.spt`)

Each `.map` file has a corresponding `.spt` file (e.g., `mapm1.spt`) containing
the initial positions and types of sprites (soldiers, vehicles, buildings, etc.)
for that mission phase.

---

## 5. Terrain-Related Data Files

Each terrain tileset has several associated non-graphics data files that control
collision, walkability, and destructible terrain behaviour:

| Extension | Purpose                                         |
| --------- | ----------------------------------------------- |
| `.hit`    | Per-tile terrain type / walkability data         |
| `.bht`    | Sub-tile (8×8) terrain bitmasks for mixed tiles  |
| `.swp`    | Tile swap/animation data (destructible terrain) |

Files follow the naming pattern `{terrain}{type}.{ext}`, e.g.:

- `junbase.hit`, `junbase.bht`, `junbase.swp`
- `junsub0.hit`, `junsub0.bht`, `junsub0.swp`

### 5.1. Terrain Type Files (`.hit`)

`.hit` files assign a terrain type to each tile in a tile block. The engine uses
these to determine walkability, driveability, and flyability for pathfinding and
collision.

#### Format

Each `.hit` file is a flat array of **big-endian signed int16** values, one per
tile:

- **Base `.hit`**: 480 bytes → 240 entries (one per base tile, indices 0–239)
- **Sub `.hit`**: 320 bytes → 160 entries (sub tiles 0–159); the remaining 80
  sub tiles (indices 160–239) default to terrain type 0 (Land).

#### Terrain Type Values (`eTerrainFeature`)

Each int16 entry maps to one of the following terrain feature types from
OpenFodder's `eTerrainFeature` enum:

| Value | Name           | Walkable | Driveable | Flyable |
| ----- | -------------- | -------- | --------- | ------- |
| 0     | Land           | yes      | yes       | yes     |
| 1     | Rocky          | yes      | yes       | no      |
| 2     | Boulders       | yes      | yes       | no      |
| 3     | **Block**      | **no**   | **no**    | no      |
| 4     | Wood / Tree    | yes      | yes       | no      |
| 5     | Mud / Swamp    | yes      | yes       | no      |
| 6     | Water          | yes*     | yes       | no      |
| 7     | Snow           | yes      | yes       | yes     |
| 8     | Quick Sand     | yes      | yes       | yes     |
| 9     | Wall           | yes      | yes       | no      |
| 10    | Fence          | yes      | no        | no      |
| 11    | Drop           | yes      | no        | no      |
| 12    | Drop2          | yes      | no        | no      |
| 13    | Intbase (int.) | yes      | no        | no      |
| 14    | Intbase2       | yes      | no        | no      |

\* Water tiles are walkable (soldiers can swim) but they are a distinct movement
mode in the original engine.

The engine's walkability lookup tables from OpenFodder:
- `mTiles_NotWalkable[]`  = only type **3** (`Block`) blocks walking
- `mTiles_NotDriveable[]` = types 3, 10, 11 block driving
- `mTiles_NotFlyable[]`   = types 1, 2, 3, 4, 5, 6, 9, 10, 11, 12, 13, 14

#### Negative Values (Mixed Terrain / BHIT Reference)

When an entry's int16 value is **negative** (bit 15 set), the tile spans two
terrain types and requires sub-tile resolution from the corresponding `.bht`
file. The absolute value is used as an index into the BHIT table. For
tile-level walkability queries, negative entries should be treated as walkable
(or resolved via the BHIT table for higher fidelity).

#### Known `.hit` Files

| File           | Size (bytes) | Entries | Terrain  |
| -------------- | ------------ | ------- | -------- |
| `junbase.hit`  | 480          | 240     | Jungle   |
| `junsub0.hit`  | 320          | 160     | Jungle   |
| `junsub1.hit`  | 320          | 160     | Jungle   |
| `desbase.hit`  | 480          | 240     | Desert   |
| `dessub0.hit`  | 320          | 160     | Desert   |
| `icebase.hit`  | 480          | 240     | Ice      |
| `icesub0.hit`  | 320          | 160     | Ice      |
| `morbase.hit`  | 480          | 240     | Moors    |
| `morsub0.hit`  | 320          | 160     | Moors    |
| `intbase.hit`  | 480          | 240     | Interior |
| `intsub0.hit`  | 320          | 160     | Interior |

### 5.2. Sub-Tile Terrain Bitmasks (`.bht`)

`.bht` (BHIT) files provide sub-tile terrain resolution for tiles that span
two terrain types (indicated by a negative value in the `.hit` file).

#### Format

Each `.bht` file is a flat array of 8-byte entries. Each entry describes a
single mixed tile and contains an **8×8 bitmask** (8 rows × 8 bits = 8 bytes)
that divides the 16×16 tile into 64 sub-cells (each sub-cell covering a 2×2
pixel area).

- **Base `.bht`**: 1,920 bytes → 240 entries (one per base tile)
- **Sub `.bht`**: 1,280 bytes → 160 entries (sub tiles 0–159)

For each bit in the bitmask:
- `0` = sub-cell uses the primary terrain type
- `1` = sub-cell uses the secondary terrain type

The engine function `Map_Terrain_Get_Type_And_Walkable()` first looks up the
tile's `.hit` value. If negative, it indexes into the BHIT table and checks
the specific 2×2 sub-cell under the queried pixel coordinate.

### 5.3. Tile Swap Data (`.swp`)

`.swp` files define which tiles are replaced when terrain is destroyed (e.g.,
by explosions or rockets). The exact binary format is not yet fully documented.

Files follow the same naming convention: `junbase.swp`, `junsub0.swp`, etc.

---

## 6. Audio Files

### Sound Effects (`.voc`)

Creative Voice File (VOC) format sound effects. Named by terrain prefix and
effect number, e.g., `jun26.voc`, `des26.voc`, `ice26.voc`, or `all02.voc`
for effects shared across all terrains.

### Music (`.sng`, `.adl`, `.rol`)

| File           | Format | Purpose              |
| -------------- | ------ | -------------------- |
| `jon.sng`      | SNG    | Music data           |
| `*base.sng`    | SNG    | Per-terrain music    |
| `warx4.sng`    | SNG    | War/combat music     |
| `fodmus.adl`   | AdLib  | Music (AdLib)        |
| `fodmus.rol`   | Roland | Music (Roland MT-32) |
| `fodtitle.adl` | AdLib  | Title music (AdLib)  |
| `fodtitle.rol` | Roland | Title music (Roland) |

### Driver/Configuration Files

| File         | Purpose                    |
| ------------ | -------------------------- |
| `adlib.drv`  | AdLib sound driver         |
| `roland.drv` | Roland MT-32 sound driver  |
| `null.drv`   | Null (silent) sound driver |
| `blank.sb`   | Blank SoundBlaster data    |
| `warvox.sb`  | Voice/sound effect data    |
| `null.mid`   | Empty MIDI placeholder     |
| `player.bin` | Sound player binary        |
| `rjnull.bin` | Null player binary         |

---

## 7. Complete File Inventory

### Cannon Fodder 1 (Dos_CD) — Graphics Files

| File            | Type                | Size (bytes) | Section   |
| --------------- | ------------------- | ------------ | --------- |
| `pstuff.dat`    | 4-bit sprite sheet  | —            | §3.1      |
| `font.dat`      | 4-bit sprite sheet  | —            | §3.1      |
| `hillbits.dat`  | 4-bit sprite sheet  | —            | §3.1      |
| `rankfont.dat`  | 4-bit sprite sheet  | —            | §3.1      |
| `junarmy.dat`   | 4-bit sprite sheet  | —            | §3.1      |
| `desarmy.dat`   | 4-bit sprite sheet  | —            | §3.1      |
| `icearmy.dat`   | 4-bit sprite sheet  | —            | §3.1      |
| `morarmy.dat`   | 4-bit sprite sheet  | —            | §3.1      |
| `intarmy.dat`   | 4-bit sprite sheet  | —            | §3.1      |
| `juncopt.dat`   | 4-bit sprite sheet  | —            | §3.1      |
| `descopt.dat`   | 4-bit sprite sheet  | —            | §3.1      |
| `icecopt.dat`   | 4-bit sprite sheet  | —            | §3.1      |
| `morcopt.dat`   | 4-bit sprite sheet  | —            | §3.1      |
| `intcopt.dat`   | 4-bit sprite sheet  | —            | §3.1      |
| `hill.dat`      | 8-bit linear        | —            | §3.2      |
| `morphbig.dat`  | 8-bit linear        | —            | §3.2      |
| `cftitle.dat`   | 8-bit / planar dual | 64,768       | §3.2/§3.4 |
| `junbase.blk`   | Tile block          | —            | §3.3      |
| `desbase.blk`   | Tile block          | —            | §3.3      |
| `icebase.blk`   | Tile block          | —            | §3.3      |
| `morbase.blk`   | Tile block          | —            | §3.3      |
| `intbase.blk`   | Tile block          | —            | §3.3      |
| `junsub0.blk`   | Tile block          | —            | §3.3      |
| `junsub1.blk`   | Tile block          | —            | §3.3      |
| `dessub0.blk`   | Tile block          | —            | §3.3      |
| `icesub0.blk`   | Tile block          | —            | §3.3      |
| `morsub0.blk`   | Tile block          | —            | §3.3      |
| `intsub0.blk`   | Tile block          | —            | §3.3      |
| `1.dat`–`8.dat` | Planar fullscreen   | 64,768 each  | §3.4      |
| `sensprod.dat`  | Planar fullscreen   | 64,768       | §3.4      |
| `virgpres.dat`  | Planar fullscreen   | 64,768       | §3.4      |
| `won.dat`       | Planar fullscreen   | 64,768       | §3.4      |
| `junp1-p5.dat`  | Briefing layers     | varies       | §3.5      |
| `desp1-p5.dat`  | Briefing layers     | varies       | §3.5      |
| `icep1-p5.dat`  | Briefing layers     | varies       | §3.5      |
| `morp1-p5.dat`  | Briefing layers     | varies       | §3.5      |
| `intp1-p5.dat`  | Briefing layers     | varies       | §3.5      |
| `paraheli.dat`  | Heli animation+pal  | 4,608        | §3.6      |

### Cannon Fodder 2 (Dos2_CD) — Additional Files

CF2 contains all CF1 files plus:

| File    | Type              | Size (bytes) | Purpose         |
| ------- | ----------------- | ------------ | --------------- |
| `9.dat` | Planar fullscreen | 64,768       | CF2 intro image |
| `a.dat` | Planar fullscreen | 64,768       | CF2 intro image |
| `b.dat` | Planar fullscreen | 64,768       | CF2 intro image |
| `c.dat` | Planar fullscreen | 64,768       | CF2 intro image |
| `d.dat` | Planar fullscreen | 64,768       | CF2 intro image |
| `e.dat` | Planar fullscreen | 64,768       | CF2 intro image |
| `c.dat` | Planar fullscreen | 64,768       | CF2 intro image |
| `d.dat` | Planar fullscreen | 64,768       | CF2 intro image |
| `e.dat` | Planar fullscreen | 64,768       | CF2 intro image |
