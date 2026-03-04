/// Human-readable names for soldier ranks.
///
/// In Cannon Fodder, soldiers are promoted by one rank for every phase
/// they survive. There are 16 ranks in total (0–15).
///
/// See `docs/PLAYER.md §5` and `docs/Cannon_Fodder.md`.
library;

/// The list of all soldier ranks in order from index 0 to 15.
const List<String> rankNames = [
  'Private',
  'Corporal',
  'Sergeant',
  'Staff Sergeant',
  'Sergeant First Class',
  'Master Sergeant',
  'Sergeant Major',
  'Specialist 4',
  'Specialist 6',
  'Warrant Officer',
  'Chief Warrant Officer',
  'Captain',
  'Major',
  'Colonel',
  'Brigadier General',
  'General',
];

/// Returns the name for the given rank [index] (0–15).
///
/// Returns 'Unknown' if the index is out of bounds.
String getRankName(int index) {
  if (index < 0 || index >= rankNames.length) {
    return 'Unknown';
  }
  return rankNames[index];
}
