# Systems

This directory implements the core gameplay algorithms, pathfinding mechanics, AI, and systems that operate dynamically on the components in the game.

## Key Files
* `pathfinder.dart`: Implementations for searching grid arrays for paths. Most likely utilizing A* or similar algorithms for entity movement across terrain mapping.
* `walkability_grid.dart`: Grid structure defining the traversable cells of the level map (factoring in terrain block types and map bounds) used by the `pathfinder`.
* `line_of_sight.dart`: Logic for calculating if entities can see one another (e.g., enemy spotting a player) through the level's obstacles and geometry.
* `aggression.dart`: Determines when and how enemy AI units transition from idle to aggressive states and initiate attacks upon players entering line-of-sight.
