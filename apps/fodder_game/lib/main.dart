import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fodder_game/game/fodder_game.dart';

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

/// Total number of maps available in Cannon Fodder 1.
const _totalMaps = 72;

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final _game = FodderGame();
  String _currentMap = 'mapm1.tmx';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Stack(
          children: [
            GameWidget(game: _game),
            Positioned(
              top: 8,
              right: 8,
              child: _LevelDropdown(
                currentMap: _currentMap,
                onChanged: (map) async {
                  setState(() => _currentMap = map);
                  await _game.loadMap(map);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelDropdown extends StatelessWidget {
  const _LevelDropdown({
    required this.currentMap,
    required this.onChanged,
  });

  final String currentMap;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<String>(
        value: currentMap,
        dropdownColor: Colors.black87,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        underline: const SizedBox.shrink(),
        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
        items: [
          for (var i = 1; i <= _totalMaps; i++)
            DropdownMenuItem(
              value: 'mapm$i.tmx',
              child: Text('Map $i'),
            ),
        ],
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}
