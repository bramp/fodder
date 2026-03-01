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

```bash
# Extract assets
dart run packages/fodder_tools/bin/extract.dart --extract-all --input original_game/Dos_CD/CF_ENG.DAT --output assets/Dos_CD

# Export sprites (from fodder_tools)
dart run packages/fodder_tools/bin/sprites.dart --dat original_game/Dos_CD/CF_ENG.DAT --output apps/fodder_game/assets/original/sprites
```
