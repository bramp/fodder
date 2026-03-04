import 'dart:async';

import 'package:flutter/material.dart';

import 'package:fodder_game/game/fodder_game.dart';
import 'package:fodder_game/ui/level_selector.dart';

/// Width of the debug side panel in logical pixels.
const double _panelWidth = 280;

/// Interval between debug stats refreshes.
const Duration _statsRefreshInterval = Duration(milliseconds: 500);

/// A collapsible side panel providing debug/cheat tools.
///
/// Features:
/// - Level selector (CF1 / CF2 maps)
/// - Invincibility toggle
/// - Debug overlay toggle
/// - Live sprite/enemy stats
class DebugPanel extends StatefulWidget {
  const DebugPanel({
    required this.game,
    required this.isOpen,
    required this.onToggle,
    required this.currentMap,
    required this.onMapChanged,
    super.key,
  });

  /// The game instance to query and control.
  final FodderGame game;

  /// Whether the panel is currently open.
  final bool isOpen;

  /// Called when the panel open/close state should change.
  final VoidCallback onToggle;

  /// The currently loaded map path (e.g. `cf1/maps/mapm1.tmx`).
  final String currentMap;

  /// Called when the user selects a different map.
  final ValueChanged<String> onMapChanged;

  @override
  State<DebugPanel> createState() => _DebugPanelState();
}

class _DebugPanelState extends State<DebugPanel> {
  Timer? _statsTimer;

  // Cached stats (refreshed periodically).
  int _enemiesAlive = 0;
  int _enemiesTotal = 0;
  int _activeBullets = 0;
  String _playerState = '';
  String _playerPosition = '';
  bool _playerInWater = false;

  @override
  void initState() {
    super.initState();
    _startStatsTimer();
  }

  @override
  void didUpdateWidget(DebugPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen && !oldWidget.isOpen) {
      _refreshStats();
      _startStatsTimer();
    } else if (!widget.isOpen && oldWidget.isOpen) {
      _stopStatsTimer();
    }
  }

  @override
  void dispose() {
    _stopStatsTimer();
    super.dispose();
  }

  void _startStatsTimer() {
    _stopStatsTimer();
    if (widget.isOpen) {
      _statsTimer = Timer.periodic(_statsRefreshInterval, (_) {
        if (mounted) _refreshStats();
      });
    }
  }

  void _stopStatsTimer() {
    _statsTimer?.cancel();
    _statsTimer = null;
  }

  void _refreshStats() {
    final game = widget.game;
    if (!game.isLoaded) return;

    final enemies = game.enemies;
    final player = game.playerSoldier;

    setState(() {
      _enemiesTotal = enemies.length;
      _enemiesAlive = enemies.where((e) => e.isAlive).length;
      _activeBullets = game.activeBulletCount;
      _playerState = player.current?.name ?? 'unknown';
      _playerPosition =
          '(${player.position.x.toStringAsFixed(0)}, '
          '${player.position.y.toStringAsFixed(0)})';
      _playerInWater = player.isInWater;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The debug icon button (always visible).
        Positioned(
          top: 8,
          right: 8,
          child: _DebugToggleButton(
            isOpen: widget.isOpen,
            isInvincible: widget.game.isPlayerInvincible,
            onPressed: widget.onToggle,
          ),
        ),

        // The sliding panel.
        AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          top: 0,
          bottom: 0,
          right: widget.isOpen ? 0 : -_panelWidth,
          width: _panelWidth,
          child: _PanelBody(
            currentMap: widget.currentMap,
            onMapChanged: widget.onMapChanged,
            isInvincible: widget.game.isPlayerInvincible,
            onInvincibleChanged: (value) {
              setState(() {
                widget.game.isPlayerInvincible = value;
              });
            },
            isDebugOverlay: widget.game.isDebugOverlayVisible,
            onDebugOverlayChanged: (value) {
              setState(() {
                if (value) {
                  widget.game.showDebugOverlay();
                } else {
                  widget.game.hideDebugOverlay();
                }
              });
            },
            enemiesAlive: _enemiesAlive,
            enemiesTotal: _enemiesTotal,
            activeBullets: _activeBullets,
            playerState: _playerState,
            playerPosition: _playerPosition,
            playerInWater: _playerInWater,
          ),
        ),
      ],
    );
  }
}

/// The bug icon button that toggles the debug panel open/closed.
class _DebugToggleButton extends StatelessWidget {
  const _DebugToggleButton({
    required this.isOpen,
    required this.isInvincible,
    required this.onPressed,
  });

  final bool isOpen;
  final bool isInvincible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isInvincible
            ? Colors.amber.withValues(alpha: 0.8)
            : Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(
          Icons.bug_report,
          color: isOpen ? Colors.greenAccent : Colors.white,
          size: 20,
        ),
        tooltip: isOpen ? 'Close debug panel' : 'Open debug panel',
        onPressed: onPressed,
      ),
    );
  }
}

/// The scrollable panel body containing all debug controls and stats.
class _PanelBody extends StatelessWidget {
  const _PanelBody({
    required this.currentMap,
    required this.onMapChanged,
    required this.isInvincible,
    required this.onInvincibleChanged,
    required this.isDebugOverlay,
    required this.onDebugOverlayChanged,
    required this.enemiesAlive,
    required this.enemiesTotal,
    required this.activeBullets,
    required this.playerState,
    required this.playerPosition,
    required this.playerInWater,
  });

  final String currentMap;
  final ValueChanged<String> onMapChanged;
  final bool isInvincible;
  final ValueChanged<bool> onInvincibleChanged;
  final bool isDebugOverlay;
  final ValueChanged<bool> onDebugOverlayChanged;
  final int enemiesAlive;
  final int enemiesTotal;
  final int activeBullets;
  final String playerState;
  final String playerPosition;
  final bool playerInWater;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black87,
      child: SafeArea(
        left: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 48, 12, 12),
          children: [
            // --- Cheats Section ---
            _sectionHeader('Cheats'),
            _toggleRow(
              icon: Icons.shield,
              label: 'Invincibility',
              value: isInvincible,
              onChanged: onInvincibleChanged,
              activeColor: Colors.amber,
            ),

            const SizedBox(height: 16),

            // --- Tools Section ---
            _sectionHeader('Tools'),
            _toggleRow(
              icon: Icons.grid_on,
              label: 'Debug overlay',
              value: isDebugOverlay,
              onChanged: onDebugOverlayChanged,
              activeColor: Colors.greenAccent,
            ),

            const SizedBox(height: 16),

            // --- Level Section ---
            _sectionHeader('Level'),
            LevelSelector(
              currentMap: currentMap,
              onChanged: onMapChanged,
            ),

            const SizedBox(height: 16),

            // --- Stats Section ---
            _sectionHeader('Stats'),
            _statRow('Enemies', '$_enemiesAlive / $_enemiesTotal'),
            _statRow('Bullets', '$activeBullets'),
            _statRow('Player state', playerState),
            _statRow('Position', playerPosition),
            if (playerInWater) _statRow('Terrain', 'Water'),
          ],
        ),
      ),
    );
  }

  /// Helper to get the formatted enemies string.
  String get _enemiesAlive => '$enemiesAlive';
  String get _enemiesTotal => '$enemiesTotal';

  static Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  static Widget _toggleRow({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color activeColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: value ? activeColor : Colors.white54,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: value ? activeColor : Colors.white,
                fontSize: 13,
              ),
            ),
          ),
          SizedBox(
            height: 24,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: activeColor,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
