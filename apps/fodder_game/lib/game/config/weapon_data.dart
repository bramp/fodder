/// Rank-indexed weapon statistics for player soldiers.
///
/// Derived from the `mSprite_Bullet_UnitData[26]` table in the original
/// engine (see `docs/PLAYER.md §5.4`).
///
/// The table is indexed by `min(rank + 8, 15)`, so:
/// - Ranks 0–7 each have unique stats (indices 8–15).
/// - Ranks 8–15 all clamp to index 15 (identical to rank 7).
library;

import 'package:fodder_game/game/config/game_config.dart';

/// Weapon statistics for a given rank.
class WeaponStats {
  const WeaponStats({
    required this.bulletSpeedOriginal,
    required this.aliveTimeTicks,
    required this.cooldownTicks,
    required this.deviation,
  });

  /// Original bullet speed value (per-tick units).
  final int bulletSpeedOriginal;

  /// How long the bullet stays alive (engine ticks).
  final int aliveTimeTicks;

  /// Minimum ticks between shots (fire cooldown).
  final int cooldownTicks;

  /// Random angular deviation mask. Lower = more accurate.
  final int deviation;

  /// Bullet speed in pixels/second.
  double get bulletSpeed => bulletSpeedOriginal * speedScale;

  /// Bullet lifetime in seconds.
  double get aliveTime => aliveTimeTicks * tickDuration;

  /// Fire cooldown in seconds.
  double get cooldown => cooldownTicks * tickDuration;

  /// Effective bullet range (pixels).
  double get range => bulletSpeed * aliveTime;
}

/// The 26-entry weapon data table from the original engine.
///
/// Indices 0–7 are fallback stats for sprites without troop data.
/// Indices 8–15 correspond to ranks 0–7.
/// Ranks 8–15 clamp to index 15 (same stats as rank 7).
const List<WeaponStats> _weaponTable = [
  // Indices 0–7: fallback (no troop data attached)
  // speed, alive, cooldown, deviation
  WeaponStats(
    bulletSpeedOriginal: 70,
    aliveTimeTicks: 8,
    cooldownTicks: 7,
    deviation: 31,
  ),
  WeaponStats(
    bulletSpeedOriginal: 75,
    aliveTimeTicks: 8,
    cooldownTicks: 7,
    deviation: 31,
  ),
  WeaponStats(
    bulletSpeedOriginal: 80,
    aliveTimeTicks: 8,
    cooldownTicks: 7,
    deviation: 31,
  ),
  WeaponStats(
    bulletSpeedOriginal: 85,
    aliveTimeTicks: 8,
    cooldownTicks: 7,
    deviation: 31,
  ),
  WeaponStats(
    bulletSpeedOriginal: 85,
    aliveTimeTicks: 8,
    cooldownTicks: 6,
    deviation: 31,
  ),
  WeaponStats(
    bulletSpeedOriginal: 100,
    aliveTimeTicks: 7,
    cooldownTicks: 6,
    deviation: 15,
  ),
  WeaponStats(
    bulletSpeedOriginal: 100,
    aliveTimeTicks: 7,
    cooldownTicks: 6,
    deviation: 15,
  ),
  WeaponStats(
    bulletSpeedOriginal: 105,
    aliveTimeTicks: 7,
    cooldownTicks: 6,
    deviation: 15,
  ),

  // Indices 8–15: ranks 0–7 (rank + 8 = table index)
  WeaponStats(
    bulletSpeedOriginal: 105,
    aliveTimeTicks: 7,
    cooldownTicks: 5,
    deviation: 15,
  ), // rank 0
  WeaponStats(
    bulletSpeedOriginal: 110,
    aliveTimeTicks: 7,
    cooldownTicks: 5,
    deviation: 15,
  ), // rank 1
  WeaponStats(
    bulletSpeedOriginal: 130,
    aliveTimeTicks: 6,
    cooldownTicks: 5,
    deviation: 15,
  ), // rank 2
  WeaponStats(
    bulletSpeedOriginal: 125,
    aliveTimeTicks: 7,
    cooldownTicks: 5,
    deviation: 7,
  ), // rank 3
  WeaponStats(
    bulletSpeedOriginal: 125,
    aliveTimeTicks: 7,
    cooldownTicks: 4,
    deviation: 7,
  ), // rank 4
  WeaponStats(
    bulletSpeedOriginal: 130,
    aliveTimeTicks: 7,
    cooldownTicks: 4,
    deviation: 7,
  ), // rank 5
  WeaponStats(
    bulletSpeedOriginal: 115,
    aliveTimeTicks: 8,
    cooldownTicks: 4,
    deviation: 7,
  ), // rank 6
  WeaponStats(
    bulletSpeedOriginal: 120,
    aliveTimeTicks: 8,
    cooldownTicks: 4,
    deviation: 7,
  ), // rank 7+
];

/// Returns the [WeaponStats] for a soldier at the given [rank] (0–15).
///
/// Ranks 0–7 each map to unique weapon stats.
/// Ranks 8–15 all return the same stats as rank 7.
WeaponStats weaponStatsForRank(int rank) {
  final index = (rank + 8).clamp(8, 15);
  return _weaponTable[index];
}

/// Returns the fallback [WeaponStats] for sprites without troop data.
WeaponStats fallbackWeaponStats(int index) {
  return _weaponTable[index.clamp(0, 7)];
}
