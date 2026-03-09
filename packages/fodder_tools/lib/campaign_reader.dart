import 'dart:convert';

/// Phase-level metadata extracted from an OpenFodder `.ofc` campaign JSON.
class CampaignPhase {
  CampaignPhase({
    required this.mapName,
    required this.missionName,
    required this.phaseName,
    required this.objectives,
    required this.aggressionMin,
    required this.aggressionMax,
  });

  final String mapName;
  final String missionName;
  final String phaseName;
  final List<String> objectives;
  final int aggressionMin;
  final int aggressionMax;
}

/// Maps OpenFodder objective title strings to Dart `MissionObjective` enum
/// names used in the game code.
const _objectiveTitleToEnum = <String, String>{
  'KILL ALL ENEMY': 'killAllEnemy',
  'DESTROY ENEMY BUILDINGS': 'destroyEnemyBuildings',
  'RESCUE HOSTAGES': 'rescueHostages',
  'PROTECT ALL CIVILIANS': 'protectAllCivilians',
  'KIDNAP ENEMY LEADER': 'kidnapEnemyLeader',
  'DESTROY FACTORY': 'destroyFactory',
  'DESTROY COMPUTER': 'destroyComputer',
  'GET CIVILIAN HOME': 'getCivilianHome',
  'ACTIVATE ALL SWITCHES': 'activateAllSwitches',
  'RESCUE HOSTAGE': 'rescueHostageCF2',
};

/// Parses an OpenFodder `.ofc` campaign JSON and returns a lookup table
/// mapping lowercase map names (e.g. `mapm1`) to [CampaignPhase] data.
///
/// Pass [warn] to receive diagnostic messages about unrecognised objectives.
Map<String, CampaignPhase> parseCampaignJson(
  String jsonString, {
  void Function(String)? warn,
}) {
  final data = jsonDecode(jsonString) as Map<String, dynamic>;
  final missions = data['Missions'] as List<dynamic>;
  final result = <String, CampaignPhase>{};

  for (final mission in missions) {
    final missionMap = mission as Map<String, dynamic>;
    final missionName = missionMap['Name'] as String;
    final phases = missionMap['Phases'] as List<dynamic>;

    for (final phase in phases) {
      final phaseMap = phase as Map<String, dynamic>;
      final mapName = (phaseMap['MapName'] as String).toLowerCase();
      final phaseName = phaseMap['Name'] as String;

      final aggression = phaseMap['Aggression'] as List<dynamic>;
      final aggrMin = (aggression[0] as num).toInt();
      final aggrMax = (aggression[1] as num).toInt();

      final rawObjectives = phaseMap['Objectives'] as List<dynamic>;
      final objectives = <String>[];
      for (final obj in rawObjectives) {
        final title = (obj as String).toUpperCase();
        final enumName = _objectiveTitleToEnum[title];
        if (enumName == null) {
          warn?.call('Unknown objective: "$obj"');
          continue;
        }
        objectives.add(enumName);
      }

      result[mapName] = CampaignPhase(
        mapName: mapName,
        missionName: missionName,
        phaseName: phaseName,
        objectives: objectives,
        aggressionMin: aggrMin,
        aggressionMax: aggrMax,
      );
    }
  }

  return result;
}
