# OpenFodder Resource Extraction CLI - Development Plan

## 1. Objective

Build a standalone Dart CLI tool (`tool/sprites/main.dart`) to extract, decompress, and decode raw assets from Cannon Fodder's PC DAT files (including the compressed `CF_ENG.DAT` archive) into modern, web- and engine-ready `.png` SpriteSheets for use in the Flame/Flutter remake.

## 2. System Architecture

Following the structure defined in `DESIGN.md`, the extraction tool will be divided into the following core Dart modules:

- `main.dart`: CLI orchestrator using `package:args`.
- `dat_reader.dart`: File ingestion and `CF_ENG.DAT` Huffman decompression logic.
- `palette_decoder.dart`: 6-bit VGA RGB to 32-bit RGBA parsing.
- `openfodder_maps.dart`: Pure Dart ports of `SpriteData_PC.hpp` structured coordinates.
- `sprite_decoder.dart`: Slicer determining pixel locations for 4-bit packed nibbles, planar, and linear 8-bit canvases.
- `sprite_packer.dart`: Orchestrator using `package:image` to assemble transparent SpriteSheets and export metadata.

## 3. Extraction Phases

### Phase 1: Archive Decompression (`dat_reader.dart`)

Based on `Resource_PC_CD.cpp`, `CF_ENG.DAT` acts as a continuous archive using an Adaptive Huffman + Bitstream algorithm.

- **Header Structure**:
  - Read `uint16` offset to the end of the dictionary.
  - Skip `uint16` padding.
  - Loop entries continuously: Read `uint8` string limit, the target filename (e.g., `army.dat`), `uint32 mAddressStart`, and `uint32 mSize`.
- **Extraction Logic**:
  - Port `Huffman_InitTables`, `Huffman_DecodeSymbol`, `Huffman_RebuildTables`, and `Bitstream_ReadByte` into Dart.
  - Utilize OpenFodder's static lookup tables (`byte_29921` and `byte_29A21`) to properly reconstruct uncompressed `.dat` files into raw `Uint8List` buffers.

### Phase 2: Palette Parsing (`palette_decoder.dart`)

- **Extraction**: Read 256-color sequential blocks (RGB triplets). For files like `pstuff.dat`, locating the injected palette at known offsets (`0xA000`).
- **Translation**: Convert natively 6-bit VGA channels (scaled 0-63) to 8-bit (0-255) variables by multiplying by 4 (or a left bit-shift). Assign palette index `0` as fully transparent `0x00000000`.

### Phase 3: 4-Bit Packed Sprite Demuxing (`sprite_decoder.dart`)

As shown in `SpriteData_PC.hpp` (`eGFX_RECRUIT`, `eGFX_FONT`, etc.), game entities refer to sub-rectangles inside large continuous memory canvases (`160` bytes / `320` pixels pitch).

- **Coordinate Lookups**: Translate structures mapped in `SpriteData_PC.hpp` capturing properties such as `mLoadOffset`, `mColCount` (width), and `mRowCount` (height).
- **Nibble Parsing**: Read pixels pairwise per-byte:
  - Pixel 1 (Left): `(byte >> 4) & 0x0F`
  - Pixel 2 (Right): `byte & 0x0F`
- **Color Assignment**: Compute the final index inside the 256-color palette globally by binding the respective "Base Palette Index" of the graphical sheet to the calculated non-zero nibble values.

### Phase 4: Environment & Fullscreen Processing

- **8-Bit Linear Backgrounds / Map Tiles (`BaseBlk`, `SubBlk`)**: Bypass nibble unpacking. Maps store their 16x16 tiles sequentially across a `320-pixel wide linear 2D canvas`. Extract rows stepping forward by 16 bytes inline, dynamically fast-forwarding pointer logic over the remaining `304` row bytes to reach consecutive Y rows.
- **VGA Planar Images (`jungp1.dat`, Briefings)**: Isolate raw DOS Mode X memory interleaved blocks resolving perfectly to `64,000` byte frames (320x200). De-interleave spatial offsets reading `Plane 0` directly to X%4=0 coordinate increments, `Plane 1` to X%4=1, etc.

### Phase 5: Image Assembly & Integration (`sprite_packer.dart`)

- Instantiate a large canvas using `package:image` to export out.
- Loop over `openfodder_maps.dart` enumerations, processing all sprite families (Soldiers, Icons, UI, Fonts).
- Write `Image` buffers cleanly mapping exact transparent pixels to the master `.png` sprite sheet. Output a contiguous `.json` or `.dart` definitions atlas for immediate consumption natively by the `Flame` framework's `SpriteAnimationGroupComponent`.

## 4. Execution Plan

1. **Repository Setup**: Initialise `tool/sprites/main.dart` with args handling. Configure strict linting to satisfy `very_good_analysis`.
2. **Decompressor Module**: Port OpenFodder C++ bit/byte manipulation logics exactly, testing file size equivalence extracting `CF_ENG.DAT`.
3. **Palette Baseline**: Isolate global index array; visually export as `palette_debug.png` guaranteeing RGB normalization isn't offset.
4. **Sprite Mapping Translation**: Port initial sub-components in `mRecruitSpriteFrames` (from offsets like `10880`, dimensions `16x16`) out of C++ structs into `openfodder_maps.dart`. Assemble tests validating one visually correct transparent `.png` frame.
5. **Mass Loop Assembly**: Apply extraction pipeline simultaneously across all `SpriteData_PC.hpp` mappings and engine`references natively to generate the fully playable asset manifests inside`assets/images/`.
