/// Fire rotation patterns for squad members.
///
/// Derived from the original engine (see `docs/PLAYER.md §4.1`).
/// Squad members take turns firing. The squad leader (index 0) fires
/// every other turn in squads of 3+.
///
/// Each pattern is a list of soldier indices. A value of `-1` marks the
/// end; the pattern then loops from the beginning.
library;

/// Fire rotation patterns indexed by squad size (1–8).
///
/// Access with `fireRotation[squadSize]` (index 0 is unused).
const List<List<int>> fireRotation = [
  [], // 0 soldiers (unused)
  [0, -1], // 1 soldier
  [0, 1, -1], // 2 soldiers
  [0, 1, 0, 2, -1], // 3 soldiers
  [0, 1, 0, 2, 0, 3, -1], // 4 soldiers
  [0, 1, 0, 2, 0, 3, 0, 4, -1], // 5 soldiers
  [0, 1, 0, 2, 0, 3, 0, 4, 0, 5, -1], // 6 soldiers
  [0, 1, 0, 2, 0, 3, 0, 4, 0, 5, 0, 6, -1], // 7 soldiers
  [0, 1, 0, 2, 0, 3, 0, 4, 0, 5, 0, 6, 0, 5, 0, 4, 0, 3, 0, 2, -1], // 8
];

/// Returns the fire rotation pattern for a squad of [size] soldiers.
///
/// Returns an empty list for invalid sizes.
List<int> fireRotationForSize(int size) {
  if (size < 0 || size >= fireRotation.length) return const [];
  return fireRotation[size];
}
