import 'package:flame/components.dart';
import 'package:flame_tiled/flame_tiled.dart';

/// A single spawn point extracted from a Tiled object-group layer.
class SpawnPoint {
  /// Creates a spawn point with the given [position] and [spriteType].
  const SpawnPoint({
    required this.position,
    required this.spriteType,
    required this.name,
  });

  /// World-space position (already scaled to destination tile size).
  final Vector2 position;

  /// The raw sprite type integer from the original engine's `eSprites` enum.
  // TODO(bramp): Change this to a proper enum
  final int spriteType;

  /// Human-readable name from the Tiled object (e.g. "player", "enemy").
  final String name;

  @override
  String toString() => 'SpawnPoint($name, type=$spriteType, $position)';
}

/// Parsed spawn data for a level, split into player and enemy groups.
class SpawnData {
  /// Creates spawn data from pre-sorted lists.
  const SpawnData({
    required this.players,
    required this.enemies,
    required this.environment,
    required this.all,
  });

  /// Extracts spawn data from a loaded Tiled map.
  ///
  /// Looks for [ObjectGroup] layers named "Spawns" (players, enemies, etc.)
  /// and "Raised" (trees, shrubs, building roofs, etc.) and reads
  /// each object's `sprite_type` custom property (int) to classify entries.
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
    final environment = <SpawnPoint>[];

    // Parse the "Spawns" object group (players, enemies, etc.).
    final spawnsLayer = map.layers
        .whereType<ObjectGroup>()
        .where((l) => l.name == 'Spawns')
        .firstOrNull;

    if (spawnsLayer != null) {
      for (final obj in spawnsLayer.objects) {
        final spriteType = obj.properties.getValue<int>('sprite_type');
        if (spriteType == null) continue;

        final point = SpawnPoint(
          position: Vector2(obj.x * scale, obj.y * scale),
          spriteType: spriteType,
          name: obj.name,
        );

        all.add(point);

        // Player type == 0.
        if (spriteType == 0) {
          players.add(point);
        }
        // Enemy types: 5 (basic), 36 (rocket), 106 (leader).
        if (spriteType == 5 || spriteType == 36 || spriteType == 106) {
          enemies.add(point);
        }
      }
    }

    // Parse the "Raised" object group (trees, shrubs, etc.).
    final raisedLayer = map.layers
        .whereType<ObjectGroup>()
        .where((l) => l.name == 'Raised')
        .firstOrNull;

    if (raisedLayer != null) {
      for (final obj in raisedLayer.objects) {
        final spriteType = obj.properties.getValue<int>('sprite_type');
        if (spriteType == null) continue;

        environment.add(
          SpawnPoint(
            position: Vector2(obj.x * scale, obj.y * scale),
            spriteType: spriteType,
            name: obj.name,
          ),
        );
      }
    }

    if (all.isEmpty && environment.isEmpty) return SpawnData.empty;

    return SpawnData(
      players: players,
      enemies: enemies,
      environment: environment,
      all: all,
    );
  }

  /// Creates an empty [SpawnData] with no spawn points.
  static const empty = SpawnData(
    players: [],
    enemies: [],
    environment: [],
    all: [],
  );

  /// Player (goodie) spawn points.
  final List<SpawnPoint> players;

  /// Enemy (baddie) spawn points — includes basic enemies, rocket enemies,
  /// and enemy leaders.
  final List<SpawnPoint> enemies;

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
