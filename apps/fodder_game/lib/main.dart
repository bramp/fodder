import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fodder_game/game/fodder_game.dart';
import 'package:fodder_game/ui/debug_panel.dart';
import 'package:go_router/go_router.dart';

/// Default game (cf1 or cf2) and map name used when no URL path is given.
const _defaultGame = 'cf1';
const _defaultMapName = 'mapm1';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation and hide status bar for full-screen game experience.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const MainApp());
}

// ---------------------------------------------------------------------------
// URL ↔ internal map-path helpers
// ---------------------------------------------------------------------------

/// Converts URL path segments to an internal map file path.
///
/// Example: `game='cf1', mapName='mapm5'` → `'cf1/maps/mapm5.tmx'`.
String _toMapPath(String game, String mapName) => '$game/maps/$mapName.tmx';

/// Converts an internal map file path to a URL location.
///
/// Example: `'cf1/maps/mapm5.tmx'` → `'/map/cf1/mapm5'`.
String _toUrlPath(String mapPath, {bool debug = false}) {
  final withoutExt = mapPath.replaceAll('.tmx', '');
  final parts = withoutExt.split('/');
  final base = '/map/${parts.first}/${parts.last}';
  return debug ? '$base?debug=true' : base;
}

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

final GoRouter _router = GoRouter(
  initialLocation: '/map/$_defaultGame/$_defaultMapName',
  routes: [
    GoRoute(
      path: '/',
      redirect: (_, _) => '/map/$_defaultGame/$_defaultMapName',
    ),
    GoRoute(
      path: '/map/:game/:mapName',
      builder: (context, state) {
        final game = state.pathParameters['game']!;
        final mapName = state.pathParameters['mapName']!;
        final debug = state.uri.queryParameters['debug'] == 'true';
        return GameScreen(
          mapPath: _toMapPath(game, mapName),
          debug: debug,
        );
      },
    ),
  ],
);

// ---------------------------------------------------------------------------
// App
// ---------------------------------------------------------------------------

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
    );
  }
}

// ---------------------------------------------------------------------------
// Game screen
// ---------------------------------------------------------------------------

/// The main game screen that hosts the [FodderGame] and debug panel.
///
/// The [mapPath] and [debug] parameters come from the URL via go_router.
/// When the URL changes (e.g. browser back/forward), `didUpdateWidget` picks
/// up the new map and calls `loadMap`.
class GameScreen extends StatefulWidget {
  const GameScreen({
    required this.mapPath,
    this.debug = false,
    super.key,
  });

  /// Internal map file path (e.g. `cf1/maps/mapm5.tmx`).
  final String mapPath;

  /// Whether the debug overlay should be enabled on first load.
  final bool debug;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late FodderGame _game;
  bool _debugPanelOpen = false;

  @override
  void initState() {
    super.initState();
    _game = FodderGame(
      initialMap: widget.mapPath,
      enableDebugOverlay: widget.debug,
    )..onDebugToggled = _syncUrl;
  }

  @override
  void didUpdateWidget(GameScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Only reload the map when the path actually changed (ignore debug-only
    // URL updates which the game already handled).
    if (oldWidget.mapPath != widget.mapPath) {
      unawaited(_game.loadMap(widget.mapPath));
    }
  }

  // -----------------------------------------------------------------------
  // URL sync
  // -----------------------------------------------------------------------

  /// Navigates to a new map URL, preserving debug state.
  void _onMapChanged(String mapPath) {
    context.go(_toUrlPath(mapPath, debug: _game.isDebugOverlayVisible));
  }

  /// Updates the browser URL to reflect the current debug overlay state.
  ///
  /// Called when the debug overlay is toggled via D key or the panel switch.
  void _syncUrl() {
    if (!mounted) return;
    context.go(_toUrlPath(widget.mapPath, debug: _game.isDebugOverlayVisible));
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GameWidget(game: _game),
          DebugPanel(
            game: _game,
            isOpen: _debugPanelOpen,
            onToggle: () {
              setState(() => _debugPanelOpen = !_debugPanelOpen);
            },
            currentMap: widget.mapPath,
            onMapChanged: _onMapChanged,
            onDebugOverlayToggled: _syncUrl,
          ),
        ],
      ),
    );
  }
}
