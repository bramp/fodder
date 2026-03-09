/// Defines the objectives that must be completed to finish a mission phase.
///
/// In the original Amiga/DOS game, these goals were likely defined externally
/// (hardcoded arrays or the MAIN.CF index). In modern source ports like
/// OpenFodder, they are defined in `.ofc` campaign JSON files alongside
/// phase definitions. They do not appear directly in the `.map` or `.spt`
/// files.
enum MissionObjective {
  none(0, 'None'),
  killAllEnemy(1, 'Kill All Enemy'),
  destroyEnemyBuildings(2, 'Destroy Enemy Buildings'),
  rescueHostages(3, 'Rescue Hostages'),
  protectAllCivilians(4, 'Protect All Civilians'),
  kidnapEnemyLeader(5, 'Kidnap Enemy Leader'),
  destroyFactory(6, 'Destroy Factory'),
  destroyComputer(7, 'Destroy Computer'),
  getCivilianHome(8, 'Get Civilian Home'),
  activateAllSwitches(9, 'Activate All Switches'), // Cannon Fodder 2
  rescueHostageCF2(10, 'Rescue Hostage (CF2)')
  ; // Cannon Fodder 2

  const MissionObjective(this.id, this.title);

  final int id;
  final String title;
}
