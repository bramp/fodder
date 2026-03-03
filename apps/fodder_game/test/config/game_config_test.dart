import 'package:flutter_test/flutter_test.dart';
import 'package:fodder_game/game/config/game_config.dart';

void main() {
  group('game_config timing', () {
    test('tickDuration is 0.06 seconds', () {
      expect(tickDuration, 0.06);
    });

    test('tickRate is approximately 16.67', () {
      expect(tickRate, closeTo(16.67, 0.01));
    });

    test('speedScale is 5.0', () {
      expect(speedScale, 5.0);
    });

    test('ticksToSeconds converts correctly', () {
      expect(ticksToSeconds(1), closeTo(0.06, 0.001));
      expect(ticksToSeconds(10), closeTo(0.6, 0.001));
      expect(ticksToSeconds(0), 0.0);
    });

    test('speedToPixelsPerSecond converts correctly', () {
      expect(speedToPixelsPerSecond(16), closeTo(80, 0.01));
      expect(speedToPixelsPerSecond(24), closeTo(120, 0.01));
      expect(speedToPixelsPerSecond(0), 0.0);
    });
  });

  group('game_config player speeds', () {
    test('halted speed is 40 px/s', () {
      expect(playerSpeedHalted, 40.0);
    });

    test('normal speed is 80 px/s', () {
      expect(playerSpeedNormal, 80.0);
    });

    test('running speed is 120 px/s', () {
      expect(playerSpeedRunning, 120.0);
    });

    test('water speed is 30 px/s', () {
      expect(playerSpeedWater, 30.0);
    });
  });

  group('game_config enemy', () {
    test('enemySpeedMax is 130 px/s', () {
      expect(enemySpeedMax, 130.0);
    });

    test('enemySpeedBase is 12', () {
      expect(enemySpeedBase, 12);
    });
  });

  group('game_config detection ranges', () {
    test('detectionRange is 200', () {
      expect(detectionRange, 200.0);
    });

    test('closeRange is 64', () {
      expect(closeRange, 64.0);
    });

    test('alwaysEngageRange is 40', () {
      expect(alwaysEngageRange, 40.0);
    });

    test('autoFireRange is 210', () {
      expect(autoFireRange, 210.0);
    });
  });

  group('game_config combat timing', () {
    test('enemyPostFirePauseBullet is 0.9 s', () {
      expect(enemyPostFirePauseBullet, closeTo(0.9, 0.001));
    });

    test('enemyPostFirePauseGrenade is 0.72 s', () {
      expect(enemyPostFirePauseGrenade, closeTo(0.72, 0.001));
    });

    test('playerFiringHoldDuration is 0.3 s', () {
      expect(playerFiringHoldDuration, 0.3);
    });
  });

  group('game_config dodge', () {
    test('dodgeChanceOneIn is 8', () {
      expect(dodgeChanceOneIn, 8);
    });

    test('dodgeMinBulletAge is 0.24 s', () {
      expect(dodgeMinBulletAge, closeTo(0.24, 0.001));
    });
  });

  group('game_config squads', () {
    test('maxSquads is 3', () {
      expect(maxSquads, 3);
    });

    test('maxSoldiersPerSquad is 8', () {
      expect(maxSoldiersPerSquad, 8);
    });

    test('maxSoldiersPerMission is 9', () {
      expect(maxSoldiersPerMission, 9);
    });
  });

  group('game_config ammo', () {
    test('grenadesPerSoldier is 2', () {
      expect(grenadesPerSoldier, 2);
    });

    test('rocketsPerSoldier is 1', () {
      expect(rocketsPerSoldier, 1);
    });
  });

  group('game_config death', () {
    test('deathAnimDuration is 0.5 s', () {
      expect(deathAnimDuration, 0.5);
    });

    test('deathFadeDuration is 0.5 s', () {
      expect(deathFadeDuration, 0.5);
    });
  });
}
