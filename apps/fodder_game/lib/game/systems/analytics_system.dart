import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flame/components.dart';

/// Central analytics component for Fodder Game.
///
/// Added to the `FlameGame` tree and accessed via [HasAnalyticsSystem].
/// Provides standardized methods for logging game-specific events.
class AnalyticsSystem extends Component {
  /// Logs when a level starts.
  Future<void> logLevelStart(String levelName) async {}

  /// Logs when a level is completed with stats.
  Future<void> logLevelEnd({
    required String levelName,
    required String success, // 'win', 'loss', 'quit'
    required int bulletsFired,
    required int deaths,
    required int kills,
    required double durationSeconds,
  }) async {}

  /// Logs when a player fires a bullet.
  Future<void> logBulletFired() async {}

  /// Logs when a unit dies.
  Future<void> logUnitDeath({
    required String unitType,
    required String side, // 'player', 'enemy'
  }) async {}

  /// Logs when the player uses a specialized tool.
  Future<void> logToolUsage(String toolType) async {}

  /// Logs when a player toggles a game setting or cheat.
  Future<void> logSettingToggled({
    required String setting,
    required bool value,
  }) async {}

  /// Logs any other useful game events.
  Future<void> logGameEvent(
    String name, {
    Map<String, Object>? parameters,
  }) async {}
}

/// Firebase analytics implementation of the [AnalyticsSystem].
class FirebaseAnalyticsSystem extends AnalyticsSystem {
  /// The Firebase Analytics instance.
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  @override
  Future<void> logLevelStart(String levelName) async {
    await _analytics.logLevelStart(levelName: levelName);
  }

  @override
  Future<void> logLevelEnd({
    required String levelName,
    required String success, // 'win', 'loss', 'quit'
    required int bulletsFired,
    required int deaths,
    required int kills,
    required double durationSeconds,
  }) async {
    await _analytics.logLevelEnd(
      levelName: levelName,
      success: success == 'win' ? 1 : 0,
    );
    await _analytics.logEvent(
      name: 'level_stats',
      parameters: {
        'level_name': levelName,
        'status': success,
        'bullets_fired': bulletsFired,
        'deaths': deaths,
        'kills': kills,
        'duration_seconds': durationSeconds.round(),
      },
    );
  }

  @override
  Future<void> logBulletFired() async {
    await _analytics.logEvent(name: 'bullet_fired');
  }

  @override
  Future<void> logUnitDeath({
    required String unitType,
    required String side, // 'player', 'enemy'
  }) async {
    await _analytics.logEvent(
      name: 'unit_death',
      parameters: {
        'unit_type': unitType,
        'side': side,
      },
    );
  }

  @override
  Future<void> logToolUsage(String toolType) async {
    await _analytics.logEvent(
      name: 'tool_usage',
      parameters: {'tool_type': toolType},
    );
  }

  @override
  Future<void> logSettingToggled({
    required String setting,
    required bool value,
  }) async {
    await _analytics.logEvent(
      name: 'setting_toggled',
      parameters: {
        'setting': setting,
        'value': value ? 1 : 0,
      },
    );
  }

  @override
  Future<void> logGameEvent(
    String name, {
    Map<String, Object>? parameters,
  }) async {
    await _analytics.logEvent(name: name, parameters: parameters);
  }
}

/// Silent mock implementation of [AnalyticsSystem] for tests.
class SilentAnalyticsSystem extends AnalyticsSystem {}

/// Mixin for components that need to log analytics.
///
/// Uses [HasAncestor] to find the [AnalyticsSystem] in the component tree.
mixin HasAnalyticsSystem on Component {
  AnalyticsSystem? _analyticsSystem;

  AnalyticsSystem get analytics {
    if (_analyticsSystem != null) return _analyticsSystem!;

    _analyticsSystem =
        findParent<AnalyticsSystem>() ??
        ancestors().whereType<AnalyticsSystem>().firstOrNull;

    if (_analyticsSystem == null && this is HasGameReference) {
      final hasGame = this as HasGameReference;
      try {
        final game = hasGame.game;
        _analyticsSystem = game.children
            .whereType<AnalyticsSystem>()
            .firstOrNull;
      } on Object {
        // game is not yet available, or session is not active.
      }
    }

    return _analyticsSystem ?? SilentAnalyticsSystem();
  }
}
