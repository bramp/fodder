import 'package:flame/events.dart';
import 'package:flame/game.dart';

import 'package:fodder_game/game/components/player_soldier.dart';

class FodderGame extends FlameGame with HasCollisionDetection, TapCallbacks {
  late PlayerSoldier player;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 1. Initialize map (placeholder until real asset is ready)
    // levelMap = LevelMap();
    // await add(levelMap);

    // 2. Initialize player
    // player = PlayerSoldier();
    // await add(player);

    // 3. Configure camera logic
    // camera.follow(player);
  }

  // --- Input Handlers ---

  @override
  void onTapUp(TapUpEvent event) {
    // Desktop: Left-click | Mobile: Tap
    // final worldPosition = camera.globalToLocal(event.localPosition);
    // player.moveTo(worldPosition);
    super.onTapUp(event);
  }
}
