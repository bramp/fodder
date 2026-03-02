import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_tiled/flame_tiled.dart';

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
/// ```
class LevelMap extends Component with HasGameReference<FlameGame> {
  /// Creates a level map that will load [mapFile] on mount.
  ///
  /// [mapFile] is the relative path to the `.tmx` file (e.g. `cf1/maps/mapm1.tmx`),
  /// resolved relative to [_prefix].
  LevelMap({required this.mapFile});

  /// The `.tmx` filename to load.
  final String mapFile;

  /// The asset prefix where map files live.
  ///
  /// Used for loading `.tmx` and `.tsx` files via `rootBundle.loadString`,
  /// and for loading tileset images via [Images].
  static const _prefix = 'packages/fodder_assets/assets/';

  /// Destination tile size in pixels (2× the original 16 px tiles).
  static const _destTileSize = 32.0;

  /// The loaded Tiled component (available after [onLoad]).
  TiledComponent? _tiledComponent;

  /// The underlying [TiledComponent], or `null` if not yet loaded.
  TiledComponent? get tiledComponent => _tiledComponent;

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
    await add(tiled);
  }
}
