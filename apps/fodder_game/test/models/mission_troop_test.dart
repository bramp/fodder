import 'package:flutter_test/flutter_test.dart';
import 'package:fodder_game/game/config/game_config.dart';
import 'package:fodder_game/game/models/mission_troop.dart';

void main() {
  group('MissionTroop', () {
    test('can be created with defaults', () {
      final troop = MissionTroop(recruitId: 0);

      expect(troop.recruitId, 0);
      expect(troop.rank, 0);
      expect(troop.kills, 0);
      expect(troop.phaseCount, 0);
    });

    test('can be created with custom rank and kills', () {
      final troop = MissionTroop(recruitId: 5, rank: 3, kills: 10);

      expect(troop.recruitId, 5);
      expect(troop.rank, 3);
      expect(troop.kills, 10);
    });

    test('weaponStats returns stats for current rank', () {
      final troop = MissionTroop(recruitId: 0);

      // Rank 0 → table index 8 → bulletSpeedOriginal = 105
      expect(troop.weaponStats.bulletSpeedOriginal, 105);
    });

    test('weaponStats changes with rank', () {
      final troop = MissionTroop(recruitId: 0, rank: 3);

      // Rank 3 → table index 11 → bulletSpeedOriginal = 125
      expect(troop.weaponStats.bulletSpeedOriginal, 125);
    });
  });

  group('MissionTroop.promote', () {
    test('increases rank by phaseCount', () {
      final troop = MissionTroop(recruitId: 0)
        ..survivedPhase()
        ..survivedPhase() // phaseCount = 2
        ..promote();

      expect(troop.rank, 2); // 0 + 2
    });

    test('clamps rank to maxRank', () {
      final troop = MissionTroop(recruitId: 0, rank: 14)
        ..survivedPhase()
        ..survivedPhase()
        ..survivedPhase() // phaseCount = 3
        ..promote();

      expect(troop.rank, maxRank); // min(14 + 3, 15) = 15
    });

    test('no phases survived means no promotion', () {
      final troop = MissionTroop(recruitId: 0, rank: 5)..promote();

      expect(troop.rank, 5); // 5 + 0 = 5
    });
  });

  group('MissionTroop mission lifecycle', () {
    test('resetForMission clears phaseCount', () {
      final troop = MissionTroop(recruitId: 0)
        ..survivedPhase()
        ..survivedPhase()
        ..resetForMission();

      expect(troop.phaseCount, 0);
    });

    test('survivedPhase increments phaseCount', () {
      final troop = MissionTroop(recruitId: 0)
        ..survivedPhase()
        ..survivedPhase()
        ..survivedPhase();

      expect(troop.phaseCount, 3);
    });

    test('recordKill increments kills', () {
      final troop = MissionTroop(recruitId: 0)
        ..recordKill()
        ..recordKill();

      expect(troop.kills, 2);
    });
  });
}
