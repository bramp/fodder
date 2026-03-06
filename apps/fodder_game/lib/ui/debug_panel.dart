import 'dart:async';

import 'package:flutter/material.dart';

import 'package:fodder_game/game/fodder_game.dart';
import 'package:fodder_game/game/map/level_map.dart';
import 'package:fodder_game/game/player_names.dart';
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
    this.onDebugOverlayToggled,
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

  /// Called after the debug overlay visibility is changed from the panel.
  final VoidCallback? onDebugOverlayToggled;

  @override
  State<DebugPanel> createState() => _DebugPanelState();
}

class _DebugPanelState extends State<DebugPanel> {
  Timer? _statsTimer;

  // Cached stats (refreshed periodically).
  int _enemiesAlive = 0;
  int _enemiesTotal = 0;
  int _activeBullets = 0;
  List<PlayerStats> _playerStats = [];
  String _mouseTileInfo = '';

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

    setState(() {
      _enemiesTotal = enemies.length;
      _enemiesAlive = enemies.where((e) => e.isAlive).length;
      _activeBullets = game.activeBulletCount;

      final mousePos = game.mousePosition;
      if (mousePos != null) {
        final grid = game.levelMap.walkabilityGrid;
        if (grid != null) {
          const tileSize = LevelMap.destTileSize;
          final tx = (mousePos.x / tileSize).floor();
          final ty = (mousePos.y / tileSize).floor();
          if (tx >= 0 && tx < grid.width && ty >= 0 && ty < grid.height) {
            final terrain = grid.terrainAt(tx, ty);
            _mouseTileInfo = '($tx, $ty) ${terrain.label}';
          } else {
            _mouseTileInfo =
                'out of bounds (${mousePos.x.toInt()}, ${mousePos.y.toInt()})';
          }
        } else {
          _mouseTileInfo = 'no grid';
        }
      } else {
        _mouseTileInfo = 'no mouse';
      }

      _playerStats = game.playerSoldiers.map((p) {
        final recruitId = p.troop?.recruitId ?? -1;
        final name = recruitId >= 0 && recruitId < playerNames.length
            ? playerNames[recruitId]
            : 'RECRUIT';

        return PlayerStats(
          name: name,
          state: p.current?.name ?? 'unknown',
          position:
              '(${p.position.x.toStringAsFixed(0)}, '
              '${p.position.y.toStringAsFixed(0)})',
          inWater: p.isInWater,
          isAlive: p.isAlive,
        );
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
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
            onRestart: () {
              unawaited(widget.game.restartLevel());
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
              widget.onDebugOverlayToggled?.call();
            },
            enemiesAlive: _enemiesAlive,
            enemiesTotal: _enemiesTotal,
            activeBullets: _activeBullets,
            playerStats: _playerStats,
            mouseTileInfo: _mouseTileInfo,
          ),
        ),

        // The debug icon button (always visible).
        Positioned(
          top: 0,
          right: 0,
          child: _DebugToggleButton(
            isOpen: widget.isOpen,
            isInvincible: widget.game.isPlayerInvincible,
            onPressed: widget.onToggle,
          ),
        ),
      ],
    );
  }
}

/// Data container for a single player's stats to be displayed in the panel.
class PlayerStats {
  const PlayerStats({
    required this.name,
    required this.state,
    required this.position,
    required this.inWater,
    required this.isAlive,
  });

  final String name;
  final String state;
  final String position;
  final bool inWater;
  final bool isAlive;
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
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(top: 8, right: 8),
        decoration: BoxDecoration(
          color: isInvincible
              ? Colors.amber.withValues(alpha: 0.8)
              : Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: IconButton(
          icon: Icon(
            isOpen ? Icons.close : Icons.bug_report,
            color: isOpen ? Colors.greenAccent : Colors.white,
            size: 20,
          ),
          tooltip: isOpen ? 'Close debug panel' : 'Open debug panel',
          onPressed: onPressed,
        ),
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
    required this.onRestart,
    required this.isDebugOverlay,
    required this.onDebugOverlayChanged,
    required this.enemiesAlive,
    required this.enemiesTotal,
    required this.activeBullets,
    required this.playerStats,
    required this.mouseTileInfo,
  });

  final String currentMap;
  final ValueChanged<String> onMapChanged;
  final bool isInvincible;
  final ValueChanged<bool> onInvincibleChanged;
  final VoidCallback onRestart;
  final bool isDebugOverlay;
  final ValueChanged<bool> onDebugOverlayChanged;
  final int enemiesAlive;
  final int enemiesTotal;
  final int activeBullets;
  final List<PlayerStats> playerStats;
  final String mouseTileInfo;

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
            _actionRow(
              icon: Icons.refresh,
              label: 'Restart level',
              onPressed: onRestart,
              activeColor: Colors.blueAccent,
            ),

            const SizedBox(height: 16),

            // --- Level Section ---
            _sectionHeader('Level'),
            LevelSelector(currentMap: currentMap, onChanged: onMapChanged),

            const SizedBox(height: 16),

            // --- Stats Section ---
            _sectionHeader('Stats'),
            _statRow('Enemies', '$_enemiesAlive / $_enemiesTotal'),
            _statRow('Bullets', '$activeBullets'),
            _statRow('Tile', mouseTileInfo),

            const SizedBox(height: 16),

            // --- Players Section ---
            _sectionHeader('Squad'),
            if (playerStats.isEmpty)
              const Text(
                'No players active.',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            for (final p in playerStats) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(
                  p.name,
                  style: TextStyle(
                    color: p.isAlive ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _statRow('State', p.state),
              _statRow('Position', p.position),
              if (p.inWater) _statRow('Terrain', 'Water'),
            ],
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
          Icon(icon, size: 16, color: value ? activeColor : Colors.white54),
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

  static Widget _actionRow({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color activeColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.white54,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
          SizedBox(
            height: 32,
            child: TextButton(
              onPressed: onPressed,
              style: TextButton.styleFrom(
                foregroundColor: activeColor,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('RESTART', style: TextStyle(fontSize: 10)),
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
