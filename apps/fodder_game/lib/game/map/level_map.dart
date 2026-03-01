import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_tiled/flame_tiled.dart';

/// A component that loads and renders a Tiled `.tmx` map.
///
/// Wraps [TiledComponent] to load maps exported by the `maps` tool from the
/// original Cannon Fodder data. The tile map files (`.tmx`, `.tsx`, and
/// tileset `.png` images) are expected in `assets/original/maps/`.
///
/// ## Usage
///
/// ```dart
/// final level = LevelMap(mapFile: 'mapm1.tmx');
/// await add(level);
/// ```
class LevelMap extends Component with HasGameReference<FlameGame> {
  /// Creates a level map that will load [mapFile] on mount.
  ///
  /// [mapFile] is the `.tmx` filename (e.g. `mapm1.tmx`), resolved relative
  /// to [_prefix].
  LevelMap({required this.mapFile});

  /// The `.tmx` filename to load.
  final String mapFile;

  /// The asset prefix where map files live.
  ///
  /// Used for loading `.tmx` and `.tsx` files via `rootBundle.loadString`,
  /// and for loading tileset images via [Images].
  static const _prefix = 'assets/original/maps/';

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
    // Flame's default Images instance uses prefix 'assets/images/', but our
    // tileset PNGs live alongside the .tmx/.tsx files. Provide a custom
    // Images instance whose prefix matches _prefix so tileset images are
    // resolved correctly.
    final images = Images(prefix: _prefix);

    final tiled = await TiledComponent.load(
      mapFile,
      Vector2.all(_destTileSize),
      prefix: _prefix,
      images: images,
    );

    _tiledComponent = tiled;
    await add(tiled);
  }
}
