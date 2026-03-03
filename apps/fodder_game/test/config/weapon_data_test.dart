import 'package:flutter_test/flutter_test.dart';
import 'package:fodder_game/game/config/weapon_data.dart';

void main() {
  group('WeaponStats', () {
    test('bulletSpeed converts original to px/s', () {
      const stats = WeaponStats(
        bulletSpeedOriginal: 100,
        aliveTimeTicks: 8,
        cooldownTicks: 5,
        deviation: 15,
      );

      expect(stats.bulletSpeed, 500.0); // 100 * 5
    });

    test('aliveTime converts ticks to seconds', () {
      const stats = WeaponStats(
        bulletSpeedOriginal: 100,
        aliveTimeTicks: 8,
        cooldownTicks: 5,
        deviation: 15,
      );

      expect(stats.aliveTime, closeTo(0.48, 0.001)); // 8 * 0.06
    });

    test('cooldown converts ticks to seconds', () {
      const stats = WeaponStats(
        bulletSpeedOriginal: 100,
        aliveTimeTicks: 8,
        cooldownTicks: 5,
        deviation: 15,
      );

      expect(stats.cooldown, closeTo(0.3, 0.001)); // 5 * 0.06
    });

    test('range is bulletSpeed × aliveTime', () {
      const stats = WeaponStats(
        bulletSpeedOriginal: 100,
        aliveTimeTicks: 8,
        cooldownTicks: 5,
        deviation: 15,
      );

      expect(stats.range, closeTo(500.0 * 0.48, 0.1));
    });
  });

  group('weaponStatsForRank', () {
    test('rank 0 returns index 8 stats', () {
      final stats = weaponStatsForRank(0);
      expect(stats.bulletSpeedOriginal, 105); // index 8
    });

    test('rank 7 returns index 15 stats', () {
      final stats = weaponStatsForRank(7);
      expect(stats.bulletSpeedOriginal, 120); // index 15
    });

    test('ranks 8-15 all clamp to index 15', () {
      for (var rank = 8; rank <= 15; rank++) {
        final stats = weaponStatsForRank(rank);
        expect(
          stats.bulletSpeedOriginal,
          120, // index 15
          reason: 'rank $rank should clamp to index 15',
        );
      }
    });

    test('each rank 0-7 has unique or monotonic stats', () {
      final speeds = <int>[];
      for (var rank = 0; rank <= 7; rank++) {
        speeds.add(weaponStatsForRank(rank).bulletSpeedOriginal);
      }
      // Verify we got 8 values (not all the same).
      expect(speeds.toSet().length, greaterThan(1));
    });
  });

  group('fallbackWeaponStats', () {
    test('index 0 returns first fallback entry', () {
      final stats = fallbackWeaponStats(0);
      expect(stats.bulletSpeedOriginal, 70);
    });

    test('index 7 returns last fallback entry', () {
      final stats = fallbackWeaponStats(7);
      expect(stats.bulletSpeedOriginal, 105);
    });

    test('index clamps to valid range', () {
      final statsLow = fallbackWeaponStats(-1);
      expect(statsLow.bulletSpeedOriginal, 70); // clamps to 0

      final statsHigh = fallbackWeaponStats(100);
      expect(statsHigh.bulletSpeedOriginal, 105); // clamps to 7
    });
  });
}
