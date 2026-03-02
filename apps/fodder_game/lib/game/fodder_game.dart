import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';

import 'package:fodder_game/game/components/debug_barrier_overlay.dart';
import 'package:fodder_game/game/components/enemy_soldier.dart';
import 'package:fodder_game/game/components/player_soldier.dart';
import 'package:fodder_game/game/components/soldier_animations.dart';
import 'package:fodder_game/game/map/level_map.dart';
import 'package:fodder_game/game/systems/pathfinder.dart';
import 'package:fodder_game/game/systems/walkability_grid.dart';

class FodderGame extends FlameGame with HasCollisionDetection, TapCallbacks {
  FodderGame({this.initialMap = 'cf1/maps/mapm1.tmx'});

  /// The relative path to the `.tmx` map file to load on start.
  final String initialMap;

  late LevelMap levelMap;
  late PlayerSoldier playerSoldier;
  Pathfinder? _pathfinder;
  late DebugBarrierOverlay _debugOverlay;

  /// Active enemy soldiers on the current map.
  final List<EnemySoldier> _enemies = [];

  /// The asset prefix for sprite files.
  static const _spritePrefix = 'packages/fodder_assets/assets/';

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 1. Load the tile map.
    levelMap = LevelMap(mapFile: initialMap);
    await world.add(levelMap);

    // 2. Configure camera to show the full map.
    camera.viewfinder.anchor = Anchor.topLeft;

    // 3. Build the pathfinder from the walkability grid.
    final grid = levelMap.walkabilityGrid;
    if (grid != null) {
      _pathfinder = Pathfinder(grid);
    }

    // 4. Load soldier animations and spawn the player.
    final playerAnims = await SoldierAnimations.load(
      prefix: '${_spritePrefix}cf1/sprites/',
      atlasJsonFile: 'junarmy.json',
      imageFile: 'junarmy.png',
    );

    playerSoldier = PlayerSoldier(soldierAnimations: playerAnims);

    // Place soldier at the first player spawn point, or fall back to
    // scanning for the first walkable tile.
    playerSoldier.position = _playerSpawnPosition();

    await world.add(playerSoldier);

    // 5. Load enemy animations and spawn enemies at their spawn points.
    final enemyAnims = await SoldierAnimations.load(
      prefix: '${_spritePrefix}cf1/sprites/',
      atlasJsonFile: 'junarmy.json',
      imageFile: 'junarmy.png',
      walkBaseGroup: walkBaseGroupEnemy,
    );

    await _spawnEnemies(enemyAnims);

    // 6. Add the debug overlay (initially hidden).
    _debugOverlay = DebugBarrierOverlay(
      grid: grid ?? WalkabilityGrid.fromData([]),
      player: playerSoldier,
      spawnData: levelMap.spawnData,
    );
    await world.add(_debugOverlay);
  }

  @override
  void onTapUp(TapUpEvent event) {
    super.onTapUp(event);

    final grid = levelMap.walkabilityGrid;
    if (grid == null || _pathfinder == null) return;

    // Convert screen tap to world coordinates.
    final worldPos = camera.globalToLocal(event.devicePosition);

    // Convert to sub-tile coordinates (8 sub-tiles per tile).
    final subTileX = (worldPos.x / LevelMap.destSubTileSize).floor();
    final subTileY = (worldPos.y / LevelMap.destSubTileSize).floor();

    if (!grid.isSubTileWalkable(subTileX, subTileY)) return;

    // Current soldier position in sub-tile coordinates.
    final soldierSubX = (playerSoldier.position.x / LevelMap.destSubTileSize)
        .floor();
    final soldierSubY = (playerSoldier.position.y / LevelMap.destSubTileSize)
        .floor();

    final waypoints = _pathfinder!.findPath(
      start: (soldierSubX, soldierSubY),
      end: (subTileX, subTileY),
    );

    if (waypoints.isNotEmpty) {
      playerSoldier.followPath(waypoints);
    }
  }

  /// Loads a different map, replacing the current one.
  Future<void> loadMap(String mapFile) async {
    // Remove soldier and enemies from old world.
    playerSoldier.removeFromParent();
    for (final enemy in _enemies) {
      enemy.removeFromParent();
    }
    _enemies.clear();
    levelMap.removeFromParent();

    // Load new map.
    levelMap = LevelMap(mapFile: mapFile);
    await world.add(levelMap);

    // Rebuild pathfinder.
    final grid = levelMap.walkabilityGrid;
    if (grid != null) {
      _pathfinder = Pathfinder(grid);
    }

    // Reposition soldier.
    playerSoldier.position = _playerSpawnPosition();
    playerSoldier.followPath([]);
    await world.add(playerSoldier);

    // Spawn enemies for the new map.
    final enemyAnims = await SoldierAnimations.load(
      prefix: '${_spritePrefix}cf1/sprites/',
      atlasJsonFile: 'junarmy.json',
      imageFile: 'junarmy.png',
      walkBaseGroup: walkBaseGroupEnemy,
    );
    await _spawnEnemies(enemyAnims);

    // Update the overlay's grid and spawn data for the new map.
    _debugOverlay.grid = grid ?? WalkabilityGrid.fromData([]);
    _debugOverlay.spawnData = levelMap.spawnData;
  }

  /// Toggles the debug barrier overlay on/off.
  void toggleDebugMode() {
    _debugOverlay.isVisible = !_debugOverlay.isVisible;
  }

  /// Returns the world position for the first player spawn point.
  ///
  /// Falls back to the first walkable tile if the map has no player spawns.
  Vector2 _playerSpawnPosition() {
    final spawns = levelMap.spawnData.players;
    if (spawns.isNotEmpty) return spawns.first.position.clone();

    // Fallback: scan the grid for the first walkable tile.
    final grid = levelMap.walkabilityGrid;
    if (grid != null) {
      for (var y = 0; y < grid.height; y++) {
        for (var x = 0; x < grid.width; x++) {
          if (grid.isWalkable(x, y)) {
            return Vector2(
              x * LevelMap.destTileSize + LevelMap.destTileSize / 2,
              y * LevelMap.destTileSize + LevelMap.destTileSize / 2,
            );
          }
        }
      }
    }
    return Vector2(
      LevelMap.destTileSize + LevelMap.destTileSize / 2,
      LevelMap.destTileSize + LevelMap.destTileSize / 2,
    );
  }

  /// Creates [EnemySoldier] components at each enemy spawn point and adds them
  /// to the world.
  Future<void> _spawnEnemies(SoldierAnimations enemyAnims) async {
    for (final spawn in levelMap.spawnData.enemies) {
      final enemy = EnemySoldier(soldierAnimations: enemyAnims)
        ..position = spawn.position.clone();
      _enemies.add(enemy);
      await world.add(enemy);
    }
  }
}
