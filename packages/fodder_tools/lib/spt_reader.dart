import 'dart:typed_data';

/// A single sprite entry from a `.spt` file.
///
/// Each entry describes an entity placed on the map: soldiers (goodies &
/// baddies), obstacles (shrubs, trees), vehicles, etc.
class SptSprite {
  /// Creates a sprite entry.
  const SptSprite({required this.x, required this.y, required this.type});

  /// Pixel X position in the original 16 px tile coordinate space.
  ///
  /// OpenFodder adds 0x10 (16) to the stored value when loading; this
  /// reader applies that offset automatically so callers see the true
  /// in-game position.
  final int x;

  /// Pixel Y position in the original 16 px tile coordinate space.
  final int y;

  /// Sprite type from the [SpriteType] enum.
  final int type;

  /// The resolved [SpriteType], or `null` if [type] is not a known value.
  SpriteType? get spriteType => SpriteType.fromValue(type);

  @override
  String toString() {
    final label = spriteType?.name ?? 'Type$type';
    return 'SptSprite(x: $x, y: $y, type: $type ($label))';
  }
}

/// Well-known sprite type constants from the original Cannon Fodder engine.
///
/// Only the types commonly found in `.spt` map data are listed here.
/// The full enum (`eSprites`) in OpenFodder has ~118 entries; we only
/// need the subset relevant for map spawn placement.
enum SpriteType {
  /// Player-controlled soldier (goodie).
  player(0),

  /// Grenade.
  grenade(2),

  /// Small shadow.
  shadowSmall(3),

  /// Null / placeholder.
  nullSprite(4),

  /// Basic enemy soldier (baddie).
  enemy(5),

  /// Explosion.
  explosion(12),

  /// Shrub (decoration).
  shrub(13),

  /// Tree (decoration).
  tree(14),

  /// Building roof.
  buildingRoof(15),

  /// Snowman (decoration).
  snowman(16),

  /// Small shrub (decoration).
  shrub2(17),

  /// Building door.
  buildingDoor(20),

  /// Enemy with rocket launcher.
  enemyRocket(36),

  /// Grenade ammo box.
  grenadeBox(37),

  /// Rocket ammo box.
  rocketBox(38),

  /// Enemy helicopter (with grenades).
  helicopterGrenadeEnemy(40),

  /// Flashing light (decoration).
  flashingLight(41),

  /// Enemy helicopter (unarmed).
  helicopterUnarmedEnemy(42),

  /// Enemy helicopter (with missiles).
  helicopterMissileEnemy(43),

  /// Land mine.
  mine(54),

  /// Spike trap.
  spike(56),

  /// Boiling pot (decoration).
  boilingPot(60),

  /// Civilian.
  civilian(61),

  /// Bird flying left (decoration).
  birdLeft(66),

  /// Bird flying right (decoration).
  birdRight(67),

  /// Seal (decoration).
  seal(68),

  /// Enemy tank.
  tankEnemy(69),

  /// Hostage.
  hostage(72),

  /// Hostage rescue tent.
  hostageRescueTent(73),

  /// Enemy leader (must be killed to complete mission).
  enemyLeader(106)
  ;

  const SpriteType(this.value);

  /// The integer value from the original engine's `eSprites` enum.
  final int value;

  /// Index for fast lookup by [value].
  static final Map<int, SpriteType> _byValue = {
    for (final t in values) t.value: t,
  };

  /// Returns the [SpriteType] for the given integer [value], or `null`
  /// if the value is not in the known set.
  static SpriteType? fromValue(int value) => _byValue[value];

  /// Returns `true` if this sprite type is a player-controlled soldier.
  bool get isPlayer => this == player;

  /// Returns `true` if this sprite type is an enemy combatant (includes
  /// basic enemies, rocket enemies, and enemy leaders).
  bool get isEnemy =>
      this == enemy || this == enemyRocket || this == enemyLeader;

  /// Returns `true` if this sprite type is a static environment decoration
  /// (shrubs, trees, roofs, snowmen) rather than a dynamic entity.
  // TODO(bramp): Why exactly is this needed here?
  bool get isEnvironment =>
      this == shrub ||
      this == tree ||
      this == buildingRoof ||
      this == snowman ||
      this == shrub2;
}

/// Parses a `.spt` file into a list of [SptSprite] entries.
///
/// The `.spt` format stores sprite placement data for a map as a flat
/// array of 10-byte big-endian records:
///
/// | Offset | Size | Field     | Notes                          |
/// |--------|------|-----------|--------------------------------|
/// | 0      | 2    | direction | Always 0x007C (ignored)        |
/// | 2      | 2    | padding   | Always 0x0000 (ignored)        |
/// | 4      | 2    | x         | Pixel X (add 16 for true pos)  |
/// | 6      | 2    | y         | Pixel Y                        |
/// | 8      | 2    | type      | Sprite type enum value         |
///
/// Player sprites are always listed first, followed by all other sprites.
///
/// The optional [warn] callback receives non-fatal messages about
/// unexpected data.
List<SptSprite> parseSpt(Uint8List data, {void Function(String)? warn}) {
  if (data.isEmpty) return [];

  if (data.length % 10 != 0) {
    warn?.call(
      'SPT file size (${data.length}) is not a multiple of 10 — '
      'trailing bytes will be ignored.',
    );
  }

  final count = data.length ~/ 10;
  final view = ByteData.sublistView(data);
  final sprites = <SptSprite>[];

  for (var i = 0; i < count; i++) {
    final offset = i * 10;
    // Skip direction (offset+0) and padding (offset+2).
    final rawX = view.getUint16(offset + 4);
    final rawY = view.getUint16(offset + 6);
    final type = view.getUint16(offset + 8);

    // OpenFodder adds 0x10 to the stored X when loading (see
    // cOriginalMap::loadCF1Spt: `Sprite->field_0 = ax + 0x10`).
    sprites.add(SptSprite(x: rawX + 0x10, y: rawY, type: type));
  }

  return sprites;
}
