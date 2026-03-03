# Fodder Game

This is the main application for the Fodder game, built with Flutter and Flame.

## Instructions

To run the game, use standard Flutter tooling:

```bash
cd apps/fodder_game
flutter run -d macos
```

## Game Layout and Architecture

The code is organized under `lib/`, primarily adopting the Flame Component System (FCS).

* `lib/main.dart`: Contains the Flutter application entry point and bootstrapping.
* `lib/game/fodder_game.dart`: The core `FlameGame` subclass that orchestrates loading assets, managing the map, and running the game loop.

### `lib/game/` Subdirectories
* **`components/`**: The visual and logical game objects.
  * Characters: Subclasses of soldiers like `player_soldier.dart` and `enemy_soldier.dart` with shared logic in `soldier.dart` and visual states in `soldier_animations.dart`.
  * Entities: Projectiles like `bullet.dart`.
* **`map/`**: Terrain and environmental logic.
  * `level_map.dart`: Map loading and rendering.
  * `spawn_data.dart`: Entity placement logic.
* **`systems/`**: Gameplay mechanics and AI operations.
  * Navigation: `pathfinder.dart` and `walkability_grid.dart` for A* routing.
  * AI & Combat: `line_of_sight.dart` and `aggression.dart` for determining enemy behaviors and visibility.

## TODOs

See [TODO.md](TODO.md) for what needs to be implemented.
