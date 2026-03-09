import 'dart:convert';

import 'package:fodder_core/mission_objective.dart';

export 'package:fodder_core/mission_objective.dart';

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
  final List<MissionObjective> objectives;
  final int aggressionMin;
  final int aggressionMax;
}

/// Maps OpenFodder objective title strings to [MissionObjective] values.
const _objectiveTitleToEnum = <String, MissionObjective>{
  'KILL ALL ENEMY': MissionObjective.killAllEnemy,
  'DESTROY ENEMY BUILDINGS': MissionObjective.destroyEnemyBuildings,
  'RESCUE HOSTAGES': MissionObjective.rescueHostages,
  'PROTECT ALL CIVILIANS': MissionObjective.protectAllCivilians,
  'KIDNAP ENEMY LEADER': MissionObjective.kidnapEnemyLeader,
  'DESTROY FACTORY': MissionObjective.destroyFactory,
  'DESTROY COMPUTER': MissionObjective.destroyComputer,
  'GET CIVILIAN HOME': MissionObjective.getCivilianHome,
  'ACTIVATE ALL SWITCHES': MissionObjective.activateAllSwitches,
  'RESCUE HOSTAGE': MissionObjective.rescueHostageCF2,
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
      final objectives = <MissionObjective>[];
      for (final obj in rawObjectives) {
        final title = (obj as String).toUpperCase();
        final objective = _objectiveTitleToEnum[title];
        if (objective == null) {
          warn?.call('Unknown objective: "$obj"');
          continue;
        }
        objectives.add(objective);
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
