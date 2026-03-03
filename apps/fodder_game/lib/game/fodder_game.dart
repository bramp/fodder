import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:fodder_game/game/components/bullet.dart';
import 'package:fodder_game/game/components/bullet_sprites.dart';
import 'package:fodder_game/game/components/debug_barrier_overlay.dart';
import 'package:fodder_game/game/components/enemy_soldier.dart';
import 'package:fodder_game/game/components/player_soldier.dart';
import 'package:fodder_game/game/components/soldier_animations.dart';
import 'package:fodder_game/game/map/level_map.dart';
import 'package:fodder_game/game/systems/aggression.dart';
import 'package:fodder_game/game/systems/pathfinder.dart';
import 'package:fodder_game/game/systems/walkability_grid.dart';

class FodderGame extends FlameGame
    with
        HasCollisionDetection,
        TapCallbacks,
        SecondaryTapCallbacks,
        KeyboardEvents {
  FodderGame({this.initialMap = 'cf1/maps/mapm1.tmx'});

  /// The relative path to the `.tmx` map file to load on start.
  final String initialMap;

  late LevelMap levelMap;
  late PlayerSoldier playerSoldier;
  Pathfinder? _pathfinder;
  late DebugBarrierOverlay _debugOverlay;

  /// Active enemy soldiers on the current map.
  final List<EnemySoldier> _enemies = [];

  /// Bullet sprites loaded from the copt atlas.
  late BulletSprites bulletSprites;

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

    // Wire up the walkability grid for terrain-aware movement (water, etc.).
    playerSoldier.walkabilityGrid = grid;

    await world.add(playerSoldier);

    // 5. Load enemy animations and spawn enemies at their spawn points.
    final enemyAnims = await SoldierAnimations.load(
      prefix: '${_spritePrefix}cf1/sprites/',
      atlasJsonFile: 'junarmy.json',
      imageFile: 'junarmy.png',
      walkPrefix: walkPrefixEnemy,
      firingPrefix: firingPrefixEnemy,
      throwPrefix: throwPrefixEnemy,
      deathPrefix: deathPrefixEnemy,
      death2Prefix: death2PrefixEnemy,
    );

    await _spawnEnemies(enemyAnims);

    // 6. Load bullet sprites from the copt (helicopter) atlas.
    bulletSprites = await BulletSprites.load(
      prefix: '${_spritePrefix}cf1/sprites/',
      atlasJsonFile: 'juncopt.json',
      imageFile: 'juncopt.png',
    );

    // 7. Add the debug overlay (initially hidden).
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

  @override
  void onSecondaryTapUp(SecondaryTapUpEvent event) {
    super.onSecondaryTapUp(event);

    // Convert screen position to world coordinates.
    final worldPos = camera.globalToLocal(event.devicePosition);

    _firePlayerBullet(worldPos);
  }

  void _firePlayerBullet(Vector2 worldPos) {
    final bullet = playerSoldier.fire(worldPos);
    if (bullet != null) {
      // Attach the correct sprite at display scale.
      final spawnedBullet = Bullet(
        position: bullet.position,
        velocity: bullet.velocity,
        faction: bullet.faction,
        bulletSprite: bulletSprites.spriteFor(Faction.player),
        size: bulletSprites.scaledSize.clone(),
        maxRange: bullet.maxRange,
        maxLifetime: bullet.maxLifetime,
        walkabilityGrid: levelMap.walkabilityGrid,
      );
      // ignore: discarded_futures, Bullet.onLoad is synchronous; safe to fire-and-forget.
      world.add(spawnedBullet);
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
    // TODO(bramp): Consider using collision instead of grid reference for
    // terrain-aware movement.
    playerSoldier.walkabilityGrid = grid;
    playerSoldier.followPath([]);
    await world.add(playerSoldier);

    // Spawn enemies for the new map.
    final enemyAnims = await SoldierAnimations.load(
      prefix: '${_spritePrefix}cf1/sprites/',
      atlasJsonFile: 'junarmy.json',
      imageFile: 'junarmy.png',
      walkPrefix: walkPrefixEnemy,
      firingPrefix: firingPrefixEnemy,
      throwPrefix: throwPrefixEnemy,
      deathPrefix: deathPrefixEnemy,
      death2Prefix: death2PrefixEnemy,
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

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    switch (event.logicalKey) {
      // Debug overlay toggle.
      case LogicalKeyboardKey.keyD:
        toggleDebugMode();
        return KeyEventResult.handled;

      // Speed mode cycling: S key cycles halted → normal → running → halted.
      case LogicalKeyboardKey.keyS:
        final squad = playerSoldier.squad;
        if (squad != null) {
          squad.cycleSpeedMode();
        }
        return KeyEventResult.handled;

      default:
        return KeyEventResult.ignored;
    }
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
  ///
  /// Assigns aggression via the ping-pong assigner, wires up walkability grid,
  /// player references, staggered fire delays, and bullet callbacks.
  Future<void> _spawnEnemies(SoldierAnimations enemyAnims) async {
    final assigner = AggressionAssigner();
    final grid = levelMap.walkabilityGrid;
    var fireDelay = 0.0;
    const fireDelayIncrement = 0.5; // ~0x0A ticks ≈ 0.5 s

    for (final spawn in levelMap.spawnData.enemies) {
      final agg = assigner.next();
      fireDelay += fireDelayIncrement;

      final enemy = EnemySoldier(soldierAnimations: enemyAnims)
        ..position = spawn.position.clone()
        ..aggression = agg
        ..initialFireDelay = agg > 4 ? 0 : fireDelay
        ..walkabilityGrid = grid
        ..players = [playerSoldier]
        ..onFireBullet = _spawnEnemyBullet;
      enemy.onDeath = () => _enemies.remove(enemy);

      _enemies.add(enemy);
      await world.add(enemy);
    }
  }

  /// Callback for enemy soldiers to spawn bullets into the world.
  void _spawnEnemyBullet(Bullet bullet) {
    final spawnedBullet = Bullet(
      position: bullet.position,
      velocity: bullet.velocity,
      faction: bullet.faction,
      maxRange: bullet.maxRange,
      maxLifetime: bullet.maxLifetime,
      bulletSprite: bulletSprites.spriteFor(Faction.enemy),
      size: bulletSprites.scaledSize.clone(),
      walkabilityGrid: levelMap.walkabilityGrid,
    );
    // ignore: discarded_futures, Bullet.onLoad is synchronous; safe to fire-and-forget.
    world.add(spawnedBullet);
  }
}
