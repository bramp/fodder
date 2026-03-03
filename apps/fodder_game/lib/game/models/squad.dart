/// Squad model — a group of player soldiers sharing ammo and waypoints.
///
/// See `docs/PLAYER.md §4`.
library;

import 'package:fodder_game/game/config/fire_rotation.dart';
import 'package:fodder_game/game/config/game_config.dart';

/// Speed mode for a squad. All soldiers in the squad move at the same speed.
enum SpeedMode {
  /// Halted / slow (original speed 8 → 40 px/s).
  halted(playerSpeedHalted),

  /// Normal walk (original speed 16 → 80 px/s).
  normal(playerSpeedNormal),

  /// Running — the default (original speed 24 → 120 px/s).
  running(playerSpeedRunning)
  ;

  const SpeedMode(this.pixelsPerSecond);

  /// Movement speed in pixels/second.
  final double pixelsPerSecond;
}

/// A squad of up to [maxSoldiersPerSquad] player soldiers.
///
/// Manages shared ammo pools, fire rotation, and speed mode.
class Squad {
  Squad({
    this.grenades = 0,
    this.rockets = 0,
    SpeedMode? speedMode,
  }) : speedMode = speedMode ?? SpeedMode.running;

  /// Number of soldiers currently in this squad.
  int soldierCount = 0;

  /// Shared grenade pool.
  int grenades;

  /// Shared rocket pool.
  int rockets;

  /// Current speed mode (affects all soldiers in the squad).
  SpeedMode speedMode;

  /// Current position in the fire rotation pattern.
  int _fireRotationIndex = 0;

  /// Initialises ammo pools based on soldier count and mission number.
  ///
  /// Grenades available from mission 4 (CF1) / mission 3 (CF2).
  /// Rockets available from mission 5 (CF1) / mission 4 (CF2).
  void initAmmo({
    required int soldiers,
    required int missionNumber,
    bool isCf2 = false,
  }) {
    soldierCount = soldiers;

    final grenadeUnlockMission = isCf2 ? 3 : 4;
    final rocketUnlockMission = isCf2 ? 4 : 5;

    grenades = missionNumber >= grenadeUnlockMission
        ? soldiers * grenadesPerSoldier
        : 0;
    rockets = missionNumber >= rocketUnlockMission
        ? soldiers * rocketsPerSoldier
        : 0;
  }

  /// Returns the index of the next soldier who should fire, or -1 if none.
  ///
  /// Advances the rotation pointer. Returns -1 at the sentinel and wraps.
  int nextFirer() {
    final pattern = fireRotationForSize(soldierCount);
    if (pattern.isEmpty) return -1;

    // Wrap if past end.
    if (_fireRotationIndex >= pattern.length) {
      _fireRotationIndex = 0;
    }

    final result = pattern[_fireRotationIndex];
    _fireRotationIndex++;

    // If we hit the sentinel, wrap and return -1 (skip this cycle).
    if (result == -1) {
      _fireRotationIndex = 0;
      return -1;
    }

    // Skip if the index refers to a soldier that doesn't exist.
    if (result >= soldierCount) {
      return nextFirer(); // Recurse to find next valid firer.
    }

    return result;
  }

  /// Resets the fire rotation to the beginning.
  void resetFireRotation() {
    _fireRotationIndex = 0;
  }

  /// Whether a grenade can be consumed.
  bool get hasGrenades => grenades > 0;

  /// Whether a rocket can be consumed.
  bool get hasRockets => rockets > 0;

  /// Consumes one grenade. Returns `true` if successful.
  bool useGrenade() {
    if (grenades <= 0) return false;
    grenades--;
    return true;
  }

  /// Consumes one rocket. Returns `true` if successful.
  bool useRocket() {
    if (rockets <= 0) return false;
    rockets--;
    return true;
  }

  /// Cycles the speed mode: halted → normal → running → halted.
  void cycleSpeedMode() {
    speedMode = switch (speedMode) {
      SpeedMode.halted => SpeedMode.normal,
      SpeedMode.normal => SpeedMode.running,
      SpeedMode.running => SpeedMode.halted,
    };
  }
}
