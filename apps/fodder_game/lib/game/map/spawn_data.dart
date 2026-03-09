import 'package:flame/components.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:fodder_game/game/map/spawn_type.dart';

/// A single spawn point extracted from a Tiled object-group layer.
class SpawnPoint {
  /// Creates a spawn point with the given [position] and [spawnType].
  const SpawnPoint({
    required this.position,
    required this.spawnType,
    required this.name,
  });

  /// World-space position (already scaled to destination tile size).
  final Vector2 position;

  /// The type of entity at this spawn point.
  final SpawnType spawnType;

  /// Human-readable name from the Tiled object (e.g. "player", "enemy").
  final String name;

  @override
  String toString() => 'SpawnPoint($name, $spawnType, $position)';
}

/// Parsed spawn data for a level, split into player and enemy groups.
class SpawnData {
  /// Creates spawn data from pre-sorted lists.
  const SpawnData({
    required this.players,
    required this.enemies,
    required this.birds,
    required this.environment,
    required this.all,
  });

  /// Extracts spawn data from a loaded Tiled map.
  ///
  /// Looks for [ObjectGroup] layers named "Spawns" (players, enemies, etc.)
  /// and "Raised" (trees, shrubs, building roofs, etc.) and maps each
  /// object's `name` attribute to a [SpawnType] to classify entries.
  ///
  /// [destTileSize] is the destination tile size used to scale the
  /// original-coordinate positions into world space. The original .spt
  /// coordinates are in 16 px tile space; the TMX stores these directly,
  /// so we scale by `destTileSize / 16`.
  factory SpawnData.fromTiledMap(TiledMap map, {required double destTileSize}) {
    final scale = destTileSize / 16;

    final all = <SpawnPoint>[];
    final players = <SpawnPoint>[];
    final enemies = <SpawnPoint>[];
    final birds = <SpawnPoint>[];
    final environment = <SpawnPoint>[];

    // Parse the "Spawns" object group (players, enemies, etc.).
    final spawnsLayer = map.layers
        .whereType<ObjectGroup>()
        .where((l) => l.name == 'Spawns')
        .firstOrNull;

    if (spawnsLayer != null) {
      for (final obj in spawnsLayer.objects) {
        final spawnType = SpawnType.fromName(obj.name);

        final point = SpawnPoint(
          position: Vector2(obj.x * scale, obj.y * scale),
          spawnType: spawnType,
          name: obj.name,
        );

        all.add(point);

        if (spawnType.isPlayer) players.add(point);
        if (spawnType.isEnemy) enemies.add(point);
        if (spawnType.isBird) birds.add(point);
      }
    }

    // Parse the "Raised" object group (trees, shrubs, etc.).
    final raisedLayer = map.layers
        .whereType<ObjectGroup>()
        .where((l) => l.name == 'Raised')
        .firstOrNull;

    if (raisedLayer != null) {
      for (final obj in raisedLayer.objects) {
        final spawnType = SpawnType.fromName(obj.name);

        environment.add(
          SpawnPoint(
            position: Vector2(obj.x * scale, obj.y * scale),
            spawnType: spawnType,
            name: obj.name,
          ),
        );
      }
    }

    if (all.isEmpty && environment.isEmpty) return SpawnData.empty;

    return SpawnData(
      players: players,
      enemies: enemies,
      birds: birds,
      environment: environment,
      all: all,
    );
  }

  /// Creates an empty [SpawnData] with no spawn points.
  static const empty = SpawnData(
    players: [],
    enemies: [],
    birds: [],
    environment: [],
    all: [],
  );

  /// Player (goodie) spawn points.
  final List<SpawnPoint> players;

  /// Enemy (baddie) spawn points — includes basic enemies, rocket enemies,
  /// and enemy leaders.
  final List<SpawnPoint> enemies;

  /// Bird spawn points (left and right).
  final List<SpawnPoint> birds;

  /// Environment decoration points (trees, shrubs, building roofs, etc.).
  ///
  /// These are not true spawn points — they represent static decorations
  /// rendered from the copt sprite atlas.
  final List<SpawnPoint> environment;

  /// All spawn points in their original order (excluding environment sprites).
  final List<SpawnPoint> all;

  /// Whether any spawn points were found.
  bool get isEmpty => all.isEmpty;

  /// Whether any spawn points were found.
  bool get isNotEmpty => all.isNotEmpty;
}
