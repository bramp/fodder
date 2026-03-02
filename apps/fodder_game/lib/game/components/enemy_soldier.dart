import 'package:fodder_game/game/components/soldier.dart';

/// An enemy soldier that stands at its spawn position.
///
/// Uses `SoldierAnimations` loaded with enemy walk groups for
/// 8-directional idle sprites. AI behaviour (patrolling, chasing,
/// shooting) will be added in a future iteration.
class EnemySoldier extends Soldier {
  EnemySoldier({required super.soldierAnimations});
}
