import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fodder_game/game/components/bullet.dart';
import 'package:fodder_game/game/components/direction8.dart';
import 'package:fodder_game/game/components/soldier.dart';
import 'package:fodder_game/game/components/soldier_animations.dart';

/// A minimal concrete [Soldier] subclass for testing.
class _TestSoldier extends Soldier {
  _TestSoldier({required super.soldierAnimations, super.random});

  @override
  Vector2 get hitboxSize => Vector2(10, 10);

  @override
  Faction get opposingFaction => Faction.enemy;
}

/// Builds a fake [SoldierAnimations] with 1×1 transparent sprites.
///
/// Uses a 1-pixel [Image] so no real GPU assets are needed.
/// When [includeCombatAnims] is true, firing, throw, and death animations
/// are populated; otherwise they default to empty maps.
/// When [includeDeath2] is true, death2Animations are also populated.
SoldierAnimations _buildFakeAnims({
  bool includeCombatAnims = false,
  bool includeDeath2 = false,
}) {
  final image = _FakeImage();
  final walkAnims = <Direction8, SpriteAnimation>{};
  final idleAnims = <Direction8, SpriteAnimation>{};
  final firingAnims = <Direction8, SpriteAnimation>{};
  final throwAnims = <Direction8, SpriteAnimation>{};
  final deathAnims = <Direction8, SpriteAnimation>{};
  final death2Anims = <Direction8, SpriteAnimation>{};

  for (final dir in Direction8.values) {
    final sprite = Sprite(image, srcSize: Vector2.all(16));
    walkAnims[dir] = SpriteAnimation.spriteList(
      [sprite, sprite, sprite],
      stepTime: 0.15,
    );
    idleAnims[dir] = SpriteAnimation.spriteList(
      [sprite],
      stepTime: double.infinity,
    );

    if (includeCombatAnims) {
      firingAnims[dir] = SpriteAnimation.spriteList(
        [sprite],
        stepTime: double.infinity,
      );
      throwAnims[dir] = SpriteAnimation.spriteList(
        [sprite, sprite, sprite],
        stepTime: 0.12,
      );
      deathAnims[dir] = SpriteAnimation.spriteList(
        [sprite, sprite],
        stepTime: 0.2,
      );
    }

    if (includeDeath2) {
      // Use a distinct single-frame animation so tests can distinguish it.
      death2Anims[dir] = SpriteAnimation.spriteList(
        [sprite],
        stepTime: 0.3,
      );
    }
  }

  return SoldierAnimations.fromMaps(
    walkAnimations: walkAnims,
    idleAnimations: idleAnims,
    firingAnimations: firingAnims,
    throwAnimations: throwAnims,
    deathAnimations: deathAnims,
    death2Animations: death2Anims,
  );
}

/// Minimal fake [Image] for testing (1×1 pixel).
class _FakeImage extends Fake implements Image {
  @override
  int get width => 1;

  @override
  int get height => 1;
}

void main() {
  group('Soldier', () {
    late _TestSoldier soldier;

    setUp(() {
      soldier = _TestSoldier(soldierAnimations: _buildFakeAnims());
    });

    test('defaults to isAlive true', () {
      expect(soldier.isAlive, isTrue);
    });

    test('defaults to facing south', () {
      expect(soldier.facing, Direction8.south);
    });

    test('die sets isAlive to false', () {
      soldier
        ..updateAnimations()
        ..current = SoldierState.idle
        ..die();

      expect(soldier.isAlive, isFalse);
    });

    test('die without death anims keeps current state', () {
      soldier
        ..updateAnimations()
        ..current = SoldierState.idle
        ..die();

      // No death animation loaded → stays idle.
      expect(soldier.current, SoldierState.idle);
      expect(soldier.isAlive, isFalse);
    });

    test('die transitions to dying state', () {
      soldier
        ..updateAnimations()
        ..current = SoldierState.idle;

      // Need combat anims for dying state.
      final combatSoldier = _TestSoldier(
        soldierAnimations: _buildFakeAnims(includeCombatAnims: true),
      )
        ..updateAnimations()
        ..current = SoldierState.idle
        ..die();

      expect(combatSoldier.current, SoldierState.dying);
    });

    test('die is idempotent', () {
      final combatSoldier = _TestSoldier(
        soldierAnimations: _buildFakeAnims(includeCombatAnims: true),
      )
        ..updateAnimations()
        ..current = SoldierState.idle
        ..die();

      expect(combatSoldier.isAlive, isFalse);

      // Calling die again should not throw or change state.
      combatSoldier.die();
      expect(combatSoldier.isAlive, isFalse);
    });

    test('setState changes current state', () {
      soldier
        ..updateAnimations()
        ..current = SoldierState.idle
        ..setState(SoldierState.walking);
      expect(soldier.current, SoldierState.walking);
    });

    test('setState does not fire if already in that state', () {
      soldier
        ..updateAnimations()
        ..current = SoldierState.idle
        // No-op — already idle.
        ..setState(SoldierState.idle);
      expect(soldier.current, SoldierState.idle);
    });

    test('updateAnimations populates animations map', () {
      soldier.updateAnimations();

      expect(soldier.animations, isNotNull);
      expect(soldier.animations!.containsKey(SoldierState.walking), isTrue);
      expect(soldier.animations!.containsKey(SoldierState.idle), isTrue);
    });

    test('updateAnimations uses current facing direction', () {
      soldier
        ..facing = Direction8.north
        ..updateAnimations();

      // The animation should correspond to the north direction.
      expect(soldier.animations, isNotNull);
      expect(soldier.animations![SoldierState.walking], isNotNull);
      expect(soldier.animations![SoldierState.idle], isNotNull);
    });

    test('updateAnimations omits combat states when anims empty', () {
      // Default _buildFakeAnims() has no combat animations.
      soldier.updateAnimations();

      expect(soldier.animations!.containsKey(SoldierState.firing), isFalse);
      expect(
        soldier.animations!.containsKey(SoldierState.throwing),
        isFalse,
      );
      expect(soldier.animations!.containsKey(SoldierState.dying), isFalse);
    });
  });

  group('Soldier with combat animations', () {
    late _TestSoldier soldier;

    setUp(() {
      soldier = _TestSoldier(
        soldierAnimations: _buildFakeAnims(includeCombatAnims: true),
      );
    });

    test('updateAnimations includes firing state', () {
      soldier.updateAnimations();

      expect(soldier.animations!.containsKey(SoldierState.firing), isTrue);
    });

    test('updateAnimations includes throwing state', () {
      soldier.updateAnimations();

      expect(
        soldier.animations!.containsKey(SoldierState.throwing),
        isTrue,
      );
    });

    test('updateAnimations includes dying state', () {
      soldier.updateAnimations();

      expect(soldier.animations!.containsKey(SoldierState.dying), isTrue);
    });

    test('setState transitions to firing', () {
      soldier
        ..updateAnimations()
        ..current = SoldierState.idle
        ..setState(SoldierState.firing);

      expect(soldier.current, SoldierState.firing);
    });

    test('setState transitions to dying', () {
      soldier
        ..updateAnimations()
        ..current = SoldierState.idle
        ..setState(SoldierState.dying);

      expect(soldier.current, SoldierState.dying);
    });
  });

  group('Soldier death animation variants', () {
    test('picks death variant randomly when both are available', () {
      // Use seeded Random for deterministic testing.
      // Seed 42: first nextInt(2) = 0 → picks death variant 1.
      final soldier = _TestSoldier(
        soldierAnimations: _buildFakeAnims(
          includeCombatAnims: true,
          includeDeath2: true,
        ),
        random: Random(42),
      )
        ..updateAnimations()
        ..current = SoldierState.idle
        ..die();

      expect(soldier.current, SoldierState.dying);
      // The animation should have been replaced with either variant.
      expect(
        soldier.animations!.containsKey(SoldierState.dying),
        isTrue,
      );
    });

    test('can select death2 variant', () {
      // Find a seed that picks variant index 1 (death2).
      // Try different seeds until nextInt(2) returns 1.
      var seed = 0;
      while (Random(seed).nextInt(2) != 1) {
        seed++;
      }

      final anims = _buildFakeAnims(
        includeCombatAnims: true,
        includeDeath2: true,
      );
      final soldier = _TestSoldier(
        soldierAnimations: anims,
        random: Random(seed),
      )
        ..updateAnimations()
        ..current = SoldierState.idle
        ..die();

      // Death2 uses single frame (stepTime 0.3), death1 uses 2 frames
      // (stepTime 0.2). Verify the variant was swapped in.
      final dyingAnim = soldier.animations![SoldierState.dying]!;
      expect(dyingAnim.frames.length, 1); // death2 = single frame
    });

    test('falls back to death1 when no death2 available', () {
      final soldier = _TestSoldier(
        soldierAnimations: _buildFakeAnims(includeCombatAnims: true),
      )
        ..updateAnimations()
        ..current = SoldierState.idle
        ..die();

      expect(soldier.current, SoldierState.dying);
      final dyingAnim = soldier.animations![SoldierState.dying]!;
      expect(dyingAnim.frames.length, 2); // death1 = 2 frames
    });
  });

  group('Soldier death fade-out', () {
    test('opacity decreases during fade period', () {
      final soldier = _TestSoldier(
        soldierAnimations: _buildFakeAnims(includeCombatAnims: true),
      )
        ..updateAnimations()
        ..current = SoldierState.idle
        ..die();

      // Initial opacity is 1.0 (death anim phase).
      expect(soldier.opacity, 1.0);

      // Advance past the death animation duration (0.5 s), into fade.
      // Fold into creation cascade would prevent the opacity check above,
      // so we use a separate call.
      soldier.update(0.6);

      // Should be fading — opacity < 1.
      expect(soldier.opacity, lessThan(1.0));
      expect(soldier.opacity, greaterThan(0.0));
    });

    test('opacity reaches zero at end of death', () {
      final soldier = _TestSoldier(
        soldierAnimations: _buildFakeAnims(includeCombatAnims: true),
      )
        ..updateAnimations()
        ..current = SoldierState.idle
        ..die()
        // Advance to just before full removal (1.0 s total - epsilon).
        ..update(0.99);

      expect(soldier.opacity, closeTo(0, 0.1));
    });
  });

  group('Soldier onDeath callback', () {
    test('invokes callback when soldier dies', () {
      var callbackInvoked = false;

      _TestSoldier(
        soldierAnimations: _buildFakeAnims(includeCombatAnims: true),
      )
        ..updateAnimations()
        ..current = SoldierState.idle
        ..onDeath = () {
          callbackInvoked = true;
        }
        ..die();

      expect(callbackInvoked, isTrue);
    });

    test('callback is not invoked on second die call', () {
      var callCount = 0;

      final soldier = _TestSoldier(
        soldierAnimations: _buildFakeAnims(includeCombatAnims: true),
      )
        ..updateAnimations()
        ..current = SoldierState.idle
        ..onDeath = () {
          callCount++;
        }
        ..die();

      expect(callCount, 1);

      soldier.die(); // Idempotent — should not increment.
      expect(callCount, 1);
    });
  });
}
