import 'package:flutter_test/flutter_test.dart';
import 'package:fodder_game/game/config/game_config.dart';
import 'package:fodder_game/game/models/squad.dart';

void main() {
  group('SpeedMode', () {
    test('halted is 40 px/s', () {
      expect(SpeedMode.halted.pixelsPerSecond, playerSpeedHalted);
    });

    test('normal is 80 px/s', () {
      expect(SpeedMode.normal.pixelsPerSecond, playerSpeedNormal);
    });

    test('running is 120 px/s', () {
      expect(SpeedMode.running.pixelsPerSecond, playerSpeedRunning);
    });
  });

  group('Squad', () {
    test('defaults to running speed mode', () {
      final squad = Squad();
      expect(squad.speedMode, SpeedMode.running);
    });

    test('defaults to zero ammo', () {
      final squad = Squad();
      expect(squad.grenades, 0);
      expect(squad.rockets, 0);
    });

    test('can be created with custom ammo', () {
      final squad = Squad(grenades: 4, rockets: 2);
      expect(squad.grenades, 4);
      expect(squad.rockets, 2);
    });
  });

  group('Squad.initAmmo', () {
    test('no ammo before mission 4 (CF1)', () {
      final squad = Squad()..initAmmo(soldiers: 3, missionNumber: 3);

      expect(squad.grenades, 0);
      expect(squad.rockets, 0);
    });

    test('grenades unlock at mission 4 (CF1)', () {
      final squad = Squad()..initAmmo(soldiers: 3, missionNumber: 4);

      expect(squad.grenades, 3 * grenadesPerSoldier); // 6
      expect(squad.rockets, 0);
    });

    test('rockets unlock at mission 5 (CF1)', () {
      final squad = Squad()..initAmmo(soldiers: 3, missionNumber: 5);

      expect(squad.grenades, 6);
      expect(squad.rockets, 3 * rocketsPerSoldier); // 3
    });

    test('CF2 unlocks grenades at mission 3', () {
      final squad = Squad()
        ..initAmmo(soldiers: 2, missionNumber: 3, isCf2: true);

      expect(squad.grenades, 2 * grenadesPerSoldier); // 4
      expect(squad.rockets, 0);
    });

    test('CF2 unlocks rockets at mission 4', () {
      final squad = Squad()
        ..initAmmo(soldiers: 2, missionNumber: 4, isCf2: true);

      expect(squad.grenades, 4);
      expect(squad.rockets, 2 * rocketsPerSoldier); // 2
    });

    test('sets soldierCount', () {
      final squad = Squad()..initAmmo(soldiers: 5, missionNumber: 1);

      expect(squad.soldierCount, 5);
    });
  });

  group('Squad.nextFirer', () {
    test('solo soldier always fires', () {
      final squad = Squad()..soldierCount = 1;

      expect(squad.nextFirer(), 0);
      // Second call returns -1 (sentinel), then wraps.
      expect(squad.nextFirer(), -1);
      expect(squad.nextFirer(), 0);
    });

    test('two soldiers alternate', () {
      final squad = Squad()..soldierCount = 2;

      // Pattern: [0, 1, -1]
      expect(squad.nextFirer(), 0);
      expect(squad.nextFirer(), 1);
      expect(squad.nextFirer(), -1); // sentinel
      expect(squad.nextFirer(), 0); // wraps
    });

    test('three soldiers: leader fires every other turn', () {
      final squad = Squad()..soldierCount = 3;

      // Pattern: [0, 1, 0, 2, -1]
      expect(squad.nextFirer(), 0);
      expect(squad.nextFirer(), 1);
      expect(squad.nextFirer(), 0);
      expect(squad.nextFirer(), 2);
      expect(squad.nextFirer(), -1);
      expect(squad.nextFirer(), 0); // wraps
    });

    test('returns -1 for empty squad', () {
      final squad = Squad()..soldierCount = 0;
      expect(squad.nextFirer(), -1);
    });

    test('resetFireRotation restarts pattern', () {
      final squad = Squad()
        ..soldierCount = 2
        ..nextFirer() // 0
        ..nextFirer() // 1
        ..resetFireRotation();

      expect(squad.nextFirer(), 0); // restarted
    });
  });

  group('Squad ammo consumption', () {
    test('useGrenade decrements and returns true', () {
      final squad = Squad(grenades: 2);

      expect(squad.useGrenade(), isTrue);
      expect(squad.grenades, 1);
      expect(squad.useGrenade(), isTrue);
      expect(squad.grenades, 0);
    });

    test('useGrenade returns false when empty', () {
      final squad = Squad();

      expect(squad.useGrenade(), isFalse);
      expect(squad.grenades, 0);
    });

    test('useRocket decrements and returns true', () {
      final squad = Squad(rockets: 1);

      expect(squad.useRocket(), isTrue);
      expect(squad.rockets, 0);
    });

    test('useRocket returns false when empty', () {
      final squad = Squad();

      expect(squad.useRocket(), isFalse);
    });

    test('hasGrenades and hasRockets report availability', () {
      final squad = Squad(grenades: 1);

      expect(squad.hasGrenades, isTrue);
      expect(squad.hasRockets, isFalse);
    });
  });

  group('Squad.cycleSpeedMode', () {
    test('cycles halted → normal', () {
      final squad = Squad(speedMode: SpeedMode.halted)..cycleSpeedMode();
      expect(squad.speedMode, SpeedMode.normal);
    });

    test('cycles normal → running', () {
      final squad = Squad(speedMode: SpeedMode.normal)..cycleSpeedMode();
      expect(squad.speedMode, SpeedMode.running);
    });

    test('cycles running → halted', () {
      final squad = Squad()..cycleSpeedMode(); // default is running
      expect(squad.speedMode, SpeedMode.halted);
    });

    test('full cycle returns to original', () {
      final squad =
          Squad() // running
            ..cycleSpeedMode() // halted
            ..cycleSpeedMode() // normal
            ..cycleSpeedMode(); // running
      expect(squad.speedMode, SpeedMode.running);
    });
  });
}
