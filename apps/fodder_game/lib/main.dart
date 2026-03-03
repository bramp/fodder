import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fodder_game/game/fodder_game.dart';
import 'package:fodder_game/ui/debug_panel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation and hide status bar for full-screen game experience
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final _game = FodderGame();
  String _currentMap = 'cf1/maps/mapm1.tmx';
  bool _debugPanelOpen = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Stack(
          children: [
            GameWidget(game: _game),
            DebugPanel(
              game: _game,
              isOpen: _debugPanelOpen,
              onToggle: () {
                setState(() => _debugPanelOpen = !_debugPanelOpen);
              },
              currentMap: _currentMap,
              onMapChanged: (map) async {
                setState(() => _currentMap = map);
                await _game.loadMap(map);
              },
            ),
          ],
        ),
      ),
    );
  }
}
