/// Spawn-point type enum for the game.
///
/// Mirrors the original engine's `eSprites` enum values, but decouples the
/// game from the raw integer IDs.  The canonical string names match the TMX
/// object `name` attribute emitted by `tiled_writer.dart`.
enum SpawnType {
  /// Player-controlled soldier (goodie).
  player,

  /// Grenade.
  grenade,

  /// Small shadow.
  shadowSmall,

  /// Null / placeholder.
  nullSprite,

  /// Basic enemy soldier (baddie).
  enemy,

  /// Explosion.
  explosion,

  /// Shrub (decoration).
  shrub,

  /// Tree (decoration).
  tree,

  /// Building roof.
  buildingRoof,

  /// Snowman (decoration).
  snowman,

  /// Small shrub (decoration).
  shrub2,

  /// Building door.
  buildingDoor,

  /// Enemy with rocket launcher.
  enemyRocket,

  /// Grenade ammo box.
  grenadeBox,

  /// Rocket ammo box.
  rocketBox,

  /// Enemy helicopter (with grenades).
  helicopterGrenadeEnemy,

  /// Flashing light (decoration).
  flashingLight,

  /// Enemy helicopter (unarmed).
  helicopterUnarmedEnemy,

  /// Enemy helicopter (with missiles).
  helicopterMissileEnemy,

  /// Land mine.
  mine,

  /// Spike trap.
  spike,

  /// Boiling pot (decoration).
  boilingPot,

  /// Civilian.
  civilian,

  /// Bird flying left (decoration).
  birdLeft,

  /// Bird flying right (decoration).
  birdRight,

  /// Seal (decoration).
  seal,

  /// Enemy tank.
  tankEnemy,

  /// Hostage.
  hostage,

  /// Hostage rescue tent.
  hostageRescueTent,

  /// Enemy leader (must be killed to complete mission).
  enemyLeader,

  /// Unrecognised or unmapped sprite type.
  unknown
  ;

  /// Index for fast lookup by [name].
  static final Map<String, SpawnType> _byName = {
    for (final t in values) t.name: t,
  };

  /// Returns the [SpawnType] whose [name] matches the TMX object name,
  /// or [unknown] if no match is found.
  static SpawnType fromName(String name) => _byName[name] ?? unknown;

  /// Whether this type represents a player-controlled soldier.
  bool get isPlayer => this == player;

  /// Whether this type represents an enemy combatant (basic, rocket, or
  /// leader).
  bool get isEnemy =>
      this == enemy || this == enemyRocket || this == enemyLeader;

  /// Whether this type represents a bird decoration.
  bool get isBird => this == birdLeft || this == birdRight;

  /// Whether this type represents a static environment decoration
  /// (shrubs, trees, roofs, snowmen, etc.).
  bool get isEnvironment =>
      this == shrub ||
      this == tree ||
      this == buildingRoof ||
      this == snowman ||
      this == shrub2;
}
