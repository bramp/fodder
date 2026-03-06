/// Data model for an individual soldier (recruit) during a mission.
///
/// Corresponds to `sMission_Troop` in the original engine.
/// See `docs/PLAYER.md §5`.
library;

import 'package:fodder_game/game/config/game_config.dart';
import 'package:fodder_game/game/config/weapon_data.dart';

/// A soldier's data — identity, rank, kills, and per-mission stats.
class MissionTroop {
  MissionTroop({required this.recruitId, this.rank = 0, this.kills = 0})
    : phaseCount = 0;

  /// Index into the global recruit name list (0–359). -1 = empty slot.
  final int recruitId;

  /// Current rank (0–[maxRank]).
  int rank;

  /// Phases survived this mission (reset at mission start).
  int phaseCount;

  /// Lifetime kill count.
  int kills;

  /// Returns weapon stats for this soldier's current rank.
  WeaponStats get weaponStats => weaponStatsForRank(rank);

  /// Applies end-of-mission promotion.
  ///
  /// `new_rank = min(current_rank + phases_survived, 15)`
  void promote() {
    rank = (rank + phaseCount).clamp(0, maxRank);
  }

  /// Resets per-mission counters at the start of a new mission.
  void resetForMission() {
    phaseCount = 0;
  }

  /// Records that this soldier survived a phase.
  void survivedPhase() {
    phaseCount++;
  }

  /// Records a kill.
  void recordKill() {
    kills++;
  }
}
