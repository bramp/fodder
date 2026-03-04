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
import 'package:fodder_game/game/components/soldier.dart';
import 'package:fodder_game/game/components/soldier_animations.dart';
import 'package:fodder_game/game/map/level_map.dart';
import 'package:fodder_game/game/models/squad.dart';
import 'package:fodder_game/game/systems/aggression.dart';
import 'package:fodder_game/game/systems/pathfinder.dart';
import 'package:fodder_game/game/systems/squad_movement.dart';
import 'package:fodder_game/game/systems/walkability_grid.dart';

class FodderGame extends FlameGame
    with
        HasCollisionDetection,
        TapCallbacks,
        SecondaryTapCallbacks,
        KeyboardEvents {
  FodderGame({
    this.initialMap = 'cf1/maps/mapm1.tmx',
    this.enableDebugOverlay = false,
  });

  /// The relative path to the `.tmx` map file to load on start.
  final String initialMap;

  /// Whether the debug overlay should be shown immediately after loading.
  final bool enableDebugOverlay;

  /// Called whenever the debug overlay visibility changes (e.g. via D key).
  VoidCallback? onDebugToggled;

  late LevelMap levelMap;
  Pathfinder? _pathfinder;
  late DebugBarrierOverlay _debugOverlay;

  /// The active player squad.
  late Squad playerSquad;

  /// Player soldiers in the active squad, ordered by index (0 = leader).
  final List<PlayerSoldier> playerSoldiers = [];

  /// The squad leader — the first alive soldier (or the first soldier if all
  /// are dead). Used for camera positioning and pathfinding origin.
  PlayerSoldier get leader => playerSoldiers.firstWhere(
    (s) => s.isAlive,
    orElse: () => playerSoldiers.first,
  );

  /// Legacy accessor for the squad leader.
  ///
  /// Used by [DebugBarrierOverlay] and the debug panel which reference a
  /// single player soldier for display/debugging.
  PlayerSoldier get playerSoldier => leader;

  /// Active enemy soldiers on the current map.
  final List<EnemySoldier> _enemies = [];

  /// Unmodifiable view of active enemies (for debug stats).
  List<EnemySoldier> get enemies =>
      isLoaded ? List.unmodifiable(_enemies) : const [];

  /// Number of bullets currently in-flight.
  int get activeBulletCount =>
      isLoaded ? world.children.whereType<Bullet>().length : 0;

  /// Whether the player soldier is currently invincible.
  bool get isPlayerInvincible =>
      isLoaded && playerSoldiers.isNotEmpty && leader.isInvincible;

  /// Toggles player invincibility (cheat) — applies to **all** squad members.
  set isPlayerInvincible(bool value) {
    if (!isLoaded) return;
    for (final soldier in playerSoldiers) {
      soldier.isInvincible = value;
    }
  }

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

    // 4. Load soldier animations and spawn the player squad.
    final playerAnims = await SoldierAnimations.load(
      prefix: '${_spritePrefix}cf1/sprites/',
      atlasJsonFile: 'junarmy.json',
      imageFile: 'junarmy.png',
    );

    playerSquad = Squad();
    await _spawnPlayerSquad(playerAnims, grid);

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
      player: leader,
      spawnData: levelMap.spawnData,
    )..enemies = _enemies;
    await world.add(_debugOverlay);

    // 8. If requested via URL param, enable the debug overlay now.
    if (enableDebugOverlay) {
      _debugOverlay.isVisible = true;
      _syncSoldierDebugMode();
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    super.onTapUp(event);

    final grid = levelMap.walkabilityGrid;
    if (grid == null || _pathfinder == null) return;
    if (playerSoldiers.isEmpty) return;

    // Convert screen tap to world coordinates.
    final worldPos = camera.globalToLocal(event.devicePosition);

    // Convert to sub-tile coordinates (8 sub-tiles per tile).
    var subTileX = (worldPos.x / LevelMap.destSubTileSize).floor();
    var subTileY = (worldPos.y / LevelMap.destSubTileSize).floor();

    // If the clicked tile is unwalkable, trace back toward the player and
    // find the nearest walkable sub-tile along the line.
    if (!grid.isSubTileWalkable(subTileX, subTileY)) {
      final leaderPos = leader.position;
      final originX = (leaderPos.x / LevelMap.destSubTileSize).floor();
      final originY = (leaderPos.y / LevelMap.destSubTileSize).floor();

      final nearest = _pathfinder!.findNearestWalkableSubTile(
        origin: (originX, originY),
        target: (subTileX, subTileY),
      );
      if (nearest == null) return;
      subTileX = nearest.$1;
      subTileY = nearest.$2;
    }

    // Pathfind from the squad leader's position to the tap target.
    final leaderPos = leader.position;
    final soldierSubX = (leaderPos.x / LevelMap.destSubTileSize).floor();
    final soldierSubY = (leaderPos.y / LevelMap.destSubTileSize).floor();

    final waypoints = _pathfinder!.findPath(
      start: (soldierSubX, soldierSubY),
      end: (subTileX, subTileY),
    );

    if (waypoints.isNotEmpty) {
      _setSquadWalkTarget(waypoints);
    }
  }

  @override
  void onSecondaryTapUp(SecondaryTapUpEvent event) {
    super.onSecondaryTapUp(event);

    // Convert screen position to world coordinates.
    final worldPos = camera.globalToLocal(event.devicePosition);

    _fireSquadBullet(worldPos);
  }

  /// Fires a bullet from the next soldier in the fire rotation.
  void _fireSquadBullet(Vector2 worldPos) {
    final alive = playerSoldiers.where((s) => s.isAlive).toList();
    if (alive.isEmpty) return;

    // Get the next firer index from the squad's fire rotation.
    final firerIndex = playerSquad.nextFirer();
    if (firerIndex < 0 || firerIndex >= alive.length) return;

    final soldier = alive[firerIndex];
    final bullet = soldier.fire(worldPos);
    if (bullet != null) {
      _spawnPlayerBullet(bullet);
    }
  }

  /// Adds a player [Bullet] to the world with the correct sprite.
  void _spawnPlayerBullet(Bullet bullet) {
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
    _applyBulletDebugMode(spawnedBullet);
    // ignore: discarded_futures, Bullet.onLoad is synchronous; safe to fire-and-forget.
    world.add(spawnedBullet);
  }

  /// Loads a different map, replacing the current one.
  Future<void> loadMap(String mapFile) async {
    // Remove soldiers and enemies from old world.
    for (final soldier in playerSoldiers) {
      soldier.removeFromParent();
    }
    playerSoldiers.clear();
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

    // Spawn a fresh player squad.
    final playerAnims = await SoldierAnimations.load(
      prefix: '${_spritePrefix}cf1/sprites/',
      atlasJsonFile: 'junarmy.json',
      imageFile: 'junarmy.png',
    );
    playerSquad = Squad();
    await _spawnPlayerSquad(playerAnims, grid);

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

  /// Toggles the debug overlay on/off.
  ///
  /// Also enables/disables collision hitbox rendering on all soldiers.
  void toggleDebugMode() {
    if (!isLoaded) return;
    _debugOverlay.isVisible = !_debugOverlay.isVisible;
    _syncSoldierDebugMode();
    onDebugToggled?.call();
  }

  /// Whether the debug overlay is currently visible.
  bool get isDebugOverlayVisible => isLoaded && _debugOverlay.isVisible;

  /// Shows the debug overlay.
  void showDebugOverlay() {
    if (!isLoaded) return;
    _debugOverlay.isVisible = true;
    _syncSoldierDebugMode();
  }

  /// Hides the debug overlay.
  void hideDebugOverlay() {
    if (!isLoaded) return;
    _debugOverlay.isVisible = false;
    _syncSoldierDebugMode();
  }

  /// Sets `debugMode` on every soldier and its children to match overlay
  /// visibility. Only the soldier itself shows coordinates; child hitboxes
  /// have their coordinate text suppressed.
  void _syncSoldierDebugMode() {
    final visible = _debugOverlay.isVisible;
    for (final soldier in world.children.whereType<Soldier>()) {
      soldier.debugMode = visible;
      for (final child in soldier.children) {
        child.debugMode = visible;
        if (child is PositionComponent) {
          child.debugCoordinatesPrecision = null;
        }
      }
    }
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
        playerSquad.cycleSpeedMode();
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

  /// Spawns player soldiers at each player spawn point (or a single soldier
  /// at the fallback position) and assigns them to [playerSquad].
  Future<void> _spawnPlayerSquad(
    SoldierAnimations anims,
    WalkabilityGrid? grid,
  ) async {
    final spawns = levelMap.spawnData.players;

    // Determine spawn positions. Always spawn at least one soldier.
    final positions = spawns.isNotEmpty
        ? spawns.map((s) => s.position.clone()).toList()
        : [_playerSpawnPosition()];

    for (var i = 0; i < positions.length; i++) {
      final soldier = PlayerSoldier(soldierAnimations: anims)
        ..position = positions[i]
        ..walkabilityGrid = grid
        ..squad = playerSquad
        ..predecessor = i > 0 ? playerSoldiers[i - 1] : null;

      playerSoldiers.add(soldier);
      await world.add(soldier);
    }

    playerSquad.soldierCount = playerSoldiers.length;
  }

  /// Distributes walk paths to squad members using the follow-the-leader
  /// chain mechanic (see PLAYER.md §4.3).
  ///
  /// The [pathToTarget] is a pathfound route from the leader's current
  /// position to the click destination. The leader follows it directly; each
  /// subsequent soldier first walks through the positions of soldiers ahead
  /// of them, then joins the pathfound route.
  void _setSquadWalkTarget(List<Vector2> pathToTarget) {
    final alive = playerSoldiers.where((s) => s.isAlive).toList();
    if (alive.isEmpty) return;

    final chainPaths = buildChainPaths(
      memberCount: alive.length,
      pathToTarget: pathToTarget,
    );

    for (var i = 0; i < alive.length; i++) {
      alive[i]
        ..predecessor = i > 0 ? alive[i - 1] : null
        ..followPath(chainPaths[i]);
    }
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
        ..players = playerSoldiers
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
    _applyBulletDebugMode(spawnedBullet);
    // ignore: discarded_futures, Bullet.onLoad is synchronous; safe to fire-and-forget.
    world.add(spawnedBullet);
  }

  /// Applies debug-mode settings to a newly spawned [bullet] so its hitbox
  /// outline is visible when the debug overlay is active.
  void _applyBulletDebugMode(Bullet bullet) {
    if (!_debugOverlay.isVisible) return;
    bullet
      ..debugMode = true
      ..debugCoordinatesPrecision = null;
  }
}
