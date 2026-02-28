# Sprite Extraction Tool Design

## Goal
To build a standalone clean-room Dart CLI tool (`tool/sprites/main.dart`) that extracts original sprite assets from local installations of Cannon Fodder 1 (and eventually Cannon Fodder 2). The tool will output modern, web- and game-engine-ready SpriteSheets (`.png`) for use in our Flame/Flutter remake.

## Background
The original software (specifically the PC DOS version) stores its graphics in sequential, unstructured raw binary arrays, predominantly located in `.DAT` files (e.g., `CANNON.DAT`). These files rely on 8-bit indexed coloring mapped directly to injected 256-color Palettes. Because they lack modern headers detailing dimension or compression schemes, decoding requires knowing the hardcoded byte offsets, widths, heights, and palette locations. Based on references from OpenFodder's engine (`Graphics_PC.cpp`, `SpriteData_PC.hpp`), we will cleanly translate these mappings to extract isolated raw data buffers into recognizable shapes.

## Architecture
The process will live strictly in `tool/sprites/` and rely on core Dart tools alongside `package:args` and `package:image`. The target asset folders are safely git-ignored (`original_game/` and `raw_assets/`).

### Proposed File Structure
```
tool/sprites/
├── main.dart                 # CLI Arg parser and entry orchestrator
├── DESIGN.md                 # This document
├── lib/
│   ├── dat_reader.dart       # Read/buffer operations for .DAT & .PAL binary blocks
│   ├── palette_decoder.dart  # Translates 8-bit indexed buffers -> RGBA representations
│   ├── openfodder_maps.dart  # Pure dart static maps porting the hardcoded C++ sprite offsets
│   ├── sprite_decoder.dart   # Slices raw offsets + widths into pixel matrices
│   └── sprite_packer.dart    # Uses package:image to pack matrices into a transparent .png SpriteSheet
```

### Components
1. **Command Line Interface (`main.dart`)**:
   Consumes arguments `--cf1 <path>` and `--cf2 <path>`, verifying valid target directories before initiating the rip sequence.
2. **Buffer Parsing**:
   Reads `CANNON.DAT` completely into a `Uint8List` for high-speed segment slicing.
3. **Palette Processing**:
   Looks up the proper palette offsets. Converts byte triplets (R, G, B) into 32-bit Dart `packColor` formats. Dedicates index `#0` or designated background hex values to `0x00000000` (transparent).
4. **Sprite Decoding logic**:
   Leverages `openfodder_maps.dart` definitions (e.g., `SoldierWalking`, `Bullet`). Retrieves the byte array using `Buffer[Offset]` through to `Buffer[Offset + (Width * Height)]`. It then constructs 2D representations mapping each byte to the Palette lookup map.
5. **Image Assembly and Output**:
   Assembles the uncompressed raw frames via `package:image`. Organizes them optimally (or semantically, like row=animation, col=frame) on a clean master SpriteSheet. Exports to `.png` into `assets/images/` and autogenerates an associated manifest (`assets/images/sprites.json` or pure `.dart` definitions) for Flame to easily instantiate.

## Execution Plan (For Next Context)
1. **Tooling Skeleton**: Stabilize `tool/sprites/main.dart` parsing arguments and reading the raw binaries cleanly. Setup rigorous linting (`very_good_analysis`).
2. **Palette Test**: Dump the 256 color palette out as `palette_debug.png` to guarantee RGB offsets are aligned and color values aren't strangely shifted (e.g., needing 4-bit left shift).
3. **Single Output Test**: Create one specific raw extraction mapping (e.g., `offset: 0x4B3A2, width: 16, height: 16`) and get it drawing as a transparent `.png`.
4. **Mass Assembly**: Expand `openfodder_maps.dart` with all known necessary core entity coordinates (Soldiers, Movement, Shoot, Death, Chopper, UI) and execute the packing loop.
