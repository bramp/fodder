# fodder

This repository is a monorepo managed with [Melos](https://melos.invertase.dev/).

## Project Layout

- `apps/fodder_game`: The main Flutter application.
- `packages/fodder_tools`: Pure Dart tools for archive extraction and sprite processing.

## Getting Started

To initialize the project and link all packages:

```bash
dart pub get
dart run melos bootstrap
```

## Importing Original Game Assets

The tools are now part of the `fodder_tools` package. To run them:

### Extract Game Assets

To run the game, you need the original assets. You can extract them using the provided tools.

#### Cannon Fodder 1
```bash
# Extract Sprites
dart run packages/fodder_tools/bin/sprites.dart --dat original_game/Dos_CD/CF_ENG.DAT --output packages/fodder_assets/assets/cf1/sprites

# Extract Maps
dart run packages/fodder_tools/bin/maps.dart -d original_game/Dos_CD/CF_ENG.DAT -o packages/fodder_assets/assets/cf1/maps
```

#### Cannon Fodder 2
```bash
# Extract Sprites
dart run packages/fodder_tools/bin/sprites.dart --dat original_game/Dos2_CD/CF2.DAT --output packages/fodder_assets/assets/cf2/sprites

# Extract Maps
dart run packages/fodder_tools/bin/maps.dart -d original_game/Dos2_CD/CF2.DAT -o packages/fodder_assets/assets/cf2/maps
```
