/// Squad movement utilities — follow-the-leader chain path building.
///
/// See `docs/PLAYER.md §4.3`.
library;

import 'package:flame/components.dart';

/// Default spacing between squad members in pixels.
///
/// Matches the original game's collision avoidance threshold (~16 px).
const double squadMemberSpacing = 16;

/// Builds paths for each squad member.
///
/// Every member receives a deep-cloned copy of [pathToTarget]. Runtime
/// spacing is enforced by `PlayerSoldier` checking its `predecessor`
/// distance each frame, not by modifying the path.
///
/// [memberCount] Number of alive squad members.
///
/// [pathToTarget] Pathfound waypoints from the leader's position to the
/// click destination.
List<List<Vector2>> buildChainPaths({
  required int memberCount,
  required List<Vector2> pathToTarget,
}) {
  assert(memberCount > 0, 'memberCount must be positive');

  return [
    for (var i = 0; i < memberCount; i++)
      pathToTarget.map((v) => v.clone()).toList(),
  ];
}
