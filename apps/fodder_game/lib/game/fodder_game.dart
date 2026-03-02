import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';

import 'package:fodder_game/game/map/level_map.dart';

class FodderGame extends FlameGame with HasCollisionDetection, TapCallbacks {
  FodderGame({this.initialMap = 'cf1/maps/mapm1.tmx'});

  /// The relative path to the `.tmx` map file to load on start.
  final String initialMap;

  late LevelMap levelMap;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 1. Load the tile map.
    levelMap = LevelMap(mapFile: initialMap);
    await world.add(levelMap);

    // 2. Configure camera to show the full map.
    // Use a fixed-resolution viewport matching the map's native pixel size.
    // The camera will show the whole map and centre it on screen.
    camera.viewfinder.anchor = Anchor.topLeft;
  }

  /// Loads a different map, replacing the current one.
  Future<void> loadMap(String mapFile) async {
    levelMap.removeFromParent();
    levelMap = LevelMap(mapFile: mapFile);
    await world.add(levelMap);
  }
}
