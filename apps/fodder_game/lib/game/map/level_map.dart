import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_tiled/flame_tiled.dart';

import 'package:fodder_core/mission_objective.dart';
import 'package:fodder_game/game/map/spawn_data.dart';
import 'package:fodder_game/game/systems/walkability_grid.dart';

/// A component that loads and renders a Tiled `.tmx` map.
///
/// Wraps [TiledComponent] to load maps exported by the `maps` tool from the
/// original Cannon Fodder data. The tile map files (`.tmx`, `.tsx`, and
/// tileset `.png` images) are expected in
/// `packages/fodder_assets/assets/`.
///
/// ## Usage
///
/// ```dart
/// final level = LevelMap(mapFile: 'cf1/maps/mapm1.tmx');
/// await add(level);
/// // After load, objectives are available:
/// print(level.objectives); // [MissionObjective.killAllEnemy]
/// ```
class LevelMap extends Component with HasGameReference<FlameGame> {
  /// Creates a level map that will load [mapFile] on mount.
  ///
  /// [mapFile] is the relative path to the `.tmx` file (e.g. `cf1/maps/mapm1.tmx`),
  /// resolved relative to [_prefix].
  LevelMap({
    required this.mapFile,
  });

  /// The `.tmx` filename to load.
  final String mapFile;

  /// The objectives that must be met to clear this level.
  ///
  /// Parsed from the map's `objectives` property during [onLoad].
  /// Empty until the map has been loaded.
  List<MissionObjective> objectives = const [];

  /// Enemy aggression range for this phase, parsed from map properties.
  int aggressionMin = 4;

  /// Enemy aggression range for this phase, parsed from map properties.
  int aggressionMax = 8;

  /// The mission display name (e.g. "THE SENSIBLE INITIATION").
  String? missionName;

  /// The phase display name (e.g. "IT'S A JUNGLE OUT THERE").
  String? phaseName;

  /// The asset prefix where map files live.
  ///
  /// Used for loading `.tmx` and `.tsx` files via `rootBundle.loadString`,
  /// and for loading tileset images via [Images].
  static const _prefix = 'packages/fodder_assets/assets/';

  /// Destination tile size in pixels (2× the original 16 px tiles).
  static const _destTileSize = 32.0;

  /// Destination tile size exposed for coordinate conversion.
  static const double destTileSize = _destTileSize;

  /// Size of a sub-tile cell in pixels (at 2× scale).
  ///
  /// Each 16×16 source tile has 8×8 sub-tile cells (2×2 pixels each).
  /// At 2× scale, each sub-cell is 4×4 pixels.
  static const double destSubTileSize = _destTileSize / 8; // 4.0

  /// The loaded Tiled component (available after [onLoad]).
  TiledComponent? _tiledComponent;

  /// The underlying [TiledComponent], or `null` if not yet loaded.
  TiledComponent? get tiledComponent => _tiledComponent;

  /// The walkability grid derived from tileset terrain properties.
  ///
  /// Available after [onLoad] completes.
  WalkabilityGrid? walkabilityGrid;

  /// Parsed spawn data (players, enemies) from the map's Sprites layer.
  ///
  /// Available after [onLoad] completes.
  SpawnData spawnData = SpawnData.empty;

  /// The pixel width of the loaded map (map columns × dest tile width).
  double get mapWidth => _tiledComponent?.width ?? 0;

  /// The pixel height of the loaded map (map rows × dest tile height).
  double get mapHeight => _tiledComponent?.height ?? 0;

  @override
  Future<void> onLoad() async {
    // TiledComponent.load requires the map file name without path separators,
    // so we split by '/' to get the filename and prepend the path to the prefix.
    final pathSegments = mapFile.split('/');
    final fileName = pathSegments.last;
    final folderPath = pathSegments.length > 1
        ? pathSegments.sublist(0, pathSegments.length - 1).join('/')
        : '';
    final finalPrefix = folderPath.isEmpty ? _prefix : '$_prefix$folderPath/';

    // Flame's default Images instance uses prefix 'assets/images/', but our
    // tileset PNGs live alongside the .tmx/.tsx files. Provide a custom
    // Images instance whose prefix matches finalPrefix so tileset images are
    // resolved correctly.
    final images = Images(prefix: finalPrefix);

    final tiled = await TiledComponent.load(
      fileName,
      Vector2.all(_destTileSize),
      prefix: finalPrefix,
      images: images,
      // Disable atlas rendering to prevent thin lines (sub-pixel gaps) between
      // tiles that appear when drawAtlas scales pixel-art tiles.
      useAtlas: false,
      // Use nearest-neighbour filtering for crisp pixel-art rendering.
      layerPaintFactory: (opacity) => Paint()
        ..color = Color.fromRGBO(255, 255, 255, opacity)
        ..filterQuality = FilterQuality.none,
    );

    _tiledComponent = tiled;
    walkabilityGrid = WalkabilityGrid.fromTiled(tiled);
    spawnData = SpawnData.fromTiledMap(
      tiled.tileMap.map,
      destTileSize: _destTileSize,
    );

    // Parse map-level properties injected by the maps tool.
    _parseMapProperties(tiled);

    await add(tiled);
  }

  /// Reads campaign metadata from map-level custom properties.
  void _parseMapProperties(TiledComponent tiled) {
    final props = tiled.tileMap.map.properties;

    final objectivesStr = props.getValue<String>('objectives');
    if (objectivesStr != null && objectivesStr.isNotEmpty) {
      objectives = objectivesStr
          .split(',')
          .map((name) {
            return MissionObjective.values.firstWhere(
              (o) => o.name == name,
              orElse: () => MissionObjective.none,
            );
          })
          .where((o) => o != MissionObjective.none)
          .toList();
    }

    aggressionMin = props.getValue<int>('aggressionMin') ?? aggressionMin;
    aggressionMax = props.getValue<int>('aggressionMax') ?? aggressionMax;
    missionName = props.getValue<String>('missionName');
    phaseName = props.getValue<String>('phaseName');
  }
}
