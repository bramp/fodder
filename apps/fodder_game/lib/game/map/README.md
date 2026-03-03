# Map

This directory manages the terrain, environment, and environmental logic of the game.

## Key Files
* `level_map.dart`: Logic for loading the original Cannon Fodder level formats (using packages like `fodder_assets`), mapping map data to sprites on the screen, and managing collision layers.
* `spawn_data.dart`: Logic mapping out initial positions for entities, soldiers, spawn points, and waypoints before handing them to the game systems to instantiate proper Flame `Component`s.
