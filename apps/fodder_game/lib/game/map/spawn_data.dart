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
    required this.all,
  });

  /// Extracts spawn data from a loaded Tiled map.
  ///
  /// Looks for an [ObjectGroup] layer named "Sprites" and reads
  /// each object's `sprite_type` custom property (int) to classify
  /// spawn points as player or enemy.
  ///
  /// [destTileSize] is the destination tile size used to scale the
  /// original-coordinate positions into world space. The original .spt
  /// coordinates are in 16 px tile space; the TMX stores these directly,
  /// so we scale by `destTileSize / 16`.
  factory SpawnData.fromTiledMap(TiledMap map, {required double destTileSize}) {
    // Find the "Sprites" object group.
    final layer = map.layers
        .whereType<ObjectGroup>()
        .where((l) => l.name == 'Sprites')
        .firstOrNull;

    if (layer == null) return SpawnData.empty;

    final scale = destTileSize / 16;

    final all = <SpawnPoint>[];
    final players = <SpawnPoint>[];
    final enemies = <SpawnPoint>[];

    for (final obj in layer.objects) {
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

    return SpawnData(players: players, enemies: enemies, all: all);
  }

  /// Creates an empty [SpawnData] with no spawn points.
  static const empty = SpawnData(players: [], enemies: [], all: []);

  /// Player (goodie) spawn points.
  final List<SpawnPoint> players;

  /// Enemy (baddie) spawn points — includes basic enemies, rocket enemies,
  /// and enemy leaders.
  final List<SpawnPoint> enemies;

  /// All spawn points in their original order.
  final List<SpawnPoint> all;

  /// Whether any spawn points were found.
  bool get isEmpty => all.isEmpty;

  /// Whether any spawn points were found.
  bool get isNotEmpty => all.isNotEmpty;
}
