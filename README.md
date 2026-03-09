# fodder

This repository is a monorepo managed with [Melos](https://melos.invertase.dev/).

## Project Layout

- `apps/fodder_game`: The main Flutter application.
- `packages/fodder_tools`: Pure Dart tools for archive extraction and sprite processing.

## Getting Started

To initialize the project and link all packages:

```bash
git clone --recursive git@github.com:bramp/fodder.git
# or `git submodule update --init --recursive` if you forgot

dart pub global activate melos
dart run melos bootstrap
```

## Importing Original Game Assets

The tools are now part of the `fodder_tools` package. To run them:

### Extract Game Assets

To run the game, you need the original assets. You can extract them using the provided tools.

First, clone the OpenFodder campaign data (contains mission objectives, aggression
levels, and demo data):

```bash
git clone https://github.com/OpenFodder/data.git vendor/openfodder-data
```

#### Cannon Fodder 1

```bash
SRC=original_game/Dos_CD
OUT=packages/fodder_assets/assets/cf1

# Extract the archive
dart run packages/fodder_tools/bin/extract.dart -i ${SRC?}/CF_ENG.DAT -o ${SRC?}_Extracted --extract-all

# Extract sprites, maps, and audio
dart run packages/fodder_tools/bin/sprites.dart -i ${SRC?}_Extracted -o ${OUT?}/sprites
dart run packages/fodder_tools/bin/maps.dart    -i ${SRC?}_Extracted -o ${OUT?}/maps -c 'vendor/openfodder-data/Campaigns/Cannon Fodder.ofc'
dart run packages/fodder_tools/bin/audio.dart   -i ${SRC?}_Extracted -o ${OUT?}/audio
```

#### Cannon Fodder 2

```bash
SRC=original_game/Dos2_CD
OUT=packages/fodder_assets/assets/cf2

# Extract the archive
dart run packages/fodder_tools/bin/extract.dart -i ${SRC?}/CF_ENG.DAT -o ${SRC?}_Extracted --extract-all

# Extract sprites, maps, and audio
dart run packages/fodder_tools/bin/sprites.dart -i ${SRC?}_Extracted -o ${OUT?}/sprites
dart run packages/fodder_tools/bin/maps.dart    -i ${SRC?}_Extracted -o ${OUT?}/maps
dart run packages/fodder_tools/bin/audio.dart   -i ${SRC?}_Extracted -o ${OUT?}/audio
```
