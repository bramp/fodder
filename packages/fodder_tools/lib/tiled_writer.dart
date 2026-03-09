import 'package:fodder_tools/map_reader.dart';
import 'package:fodder_tools/spt_reader.dart';
import 'package:fodder_tools/terrain_data.dart';
import 'package:fodder_tools/tileset_builder.dart';

/// Generates a Tiled `.tsx` tileset definition in XML format.
///
/// [name] is the tileset name (e.g. `jungle`).
/// [imageFilename] is the relative path to the tileset PNG (e.g.
/// `jungle.png`).
/// [imageWidth] and [imageHeight] are the tileset PNG dimensions in pixels.
///
/// When [terrainData] is provided (length = [totalTileCount]), each tile
/// receives custom properties:
///   - `terrain` (int 0–14): the primary terrain type.
///   - `terrain_secondary` (int 0–14): the secondary terrain type, only
///     present for mixed-terrain tiles.
///   - `terrain_mask` (string, 16 hex chars): the 8-byte BHIT sub-tile
///     bitmask, only present for mixed-terrain tiles. Each pair of hex
///     digits represents one row (top to bottom); within each byte bit 7
///     is the leftmost column.
///
/// Pass [warn] to receive diagnostic messages about unexpected data.
// TODO(bramp): Is there a tiled library we should be using instead?
String generateTsx({
  required String name,
  required String imageFilename,
  required int imageWidth,
  required int imageHeight,
  List<TileTerrainData>? terrainData,
  void Function(String)? warn,
}) {
  if (terrainData != null && terrainData.length != totalTileCount) {
    warn?.call(
      'TSX "$name": terrainData length ${terrainData.length} '
      'does not match expected $totalTileCount.',
    );
  }
  final buf = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln(
      '<tileset version="1.10" tiledversion="1.11.2" '
      'name="$name" '
      'tilewidth="$tileSize" tileheight="$tileSize" '
      'tilecount="$totalTileCount" '
      'columns="$blkColumns">',
    )
    ..writeln(
      ' <image source="$imageFilename" '
      'width="$imageWidth" height="$imageHeight"/>',
    );

  // Emit per-tile terrain properties when available.
  if (terrainData != null) {
    for (var id = 0; id < terrainData.length; id++) {
      final td = terrainData[id];
      buf
        ..writeln(' <tile id="$id">')
        ..writeln('  <properties>')
        ..writeln(
          '   <property name="terrain" type="int" value="${td.primary}"/>',
        );

      if (td.isMixed) {
        buf.writeln(
          '   <property name="terrain_secondary" type="int" '
          'value="${td.secondary}"/>',
        );
        final hex = td.mask!
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
        buf.writeln('   <property name="terrain_mask" value="$hex"/>');
      }

      buf
        ..writeln('  </properties>')
        ..writeln(' </tile>');
    }
  }

  buf.writeln('</tileset>');
  return buf.toString();
}

/// Generates a Tiled `.tmx` map file in XML format.
///
/// [map] contains the parsed map data (dimensions and tile indices).
/// [tilesetTsxFilename] is the relative path to the `.tsx` tileset file.
/// [sprites] contains sprite entries from the `.spt` file; when
/// non-empty, an `<objectgroup>` layer named "Spawns" is emitted
/// with a `<object>` per sprite encoding its pixel position and type.
///
/// Tiled uses **1-based** Global Tile IDs (GID). GID 0 means "empty".
/// Since our tileset starts at firstgid=1, the GID for a tile with
/// graphic index `i` is `i + 1`.
String generateTmx({
  required MapData map,
  required String tilesetTsxFilename,
  List<SptSprite> sprites = const [],
}) {
  // Split sprites into spawn entities and environment decorations.
  final spawnSprites = sprites
      .where((s) => s.spriteType?.isEnvironment != true)
      .toList();
  final envSprites = sprites
      .where((s) => s.spriteType?.isEnvironment == true)
      .toList();

  // Compute nextlayerid / nextobjectid based on content.
  // Layers: 1=Ground, 2=Track, 3=Spawns (if any), 4=Raised (if any).
  var nextLayerId = 3;
  if (spawnSprites.isNotEmpty) nextLayerId++;
  if (envSprites.isNotEmpty) nextLayerId++;
  final nextObjectId = sprites.length + 1;

  final buf = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln(
      '<map version="1.10" tiledversion="1.11.2" '
      'orientation="orthogonal" renderorder="right-down" '
      'width="${map.width}" height="${map.height}" '
      'tilewidth="$tileSize" tileheight="$tileSize" '
      'infinite="0" '
      'nextlayerid="$nextLayerId" nextobjectid="$nextObjectId">',
    )
    ..writeln(' <tileset firstgid="1" source="$tilesetTsxFilename"/>')
    // --- Tile layer ---
    ..writeln(
      ' <layer id="1" name="Ground" '
      'width="${map.width}" height="${map.height}">',
    )
    ..writeln('  <data encoding="csv">');

  // Write tile GIDs row by row.
  for (var y = 0; y < map.height; y++) {
    final row = StringBuffer();
    for (var x = 0; x < map.width; x++) {
      final raw = map.rawTiles[y * map.width + x];
      // Tiled GID = tile graphic index + 1 (since firstgid=1).
      final gid = MapData.tileIndex(raw) + 1;
      if (x > 0) row.write(',');
      row.write(gid);
    }
    // Trailing comma on all rows except the last.
    if (y < map.height - 1) row.write(',');
    buf.writeln(row);
  }

  buf
    ..writeln('  </data>')
    ..writeln(' </layer>')
    // --- Track / music-zone layer (custom property per tile) ---
    ..writeln(
      ' <layer id="2" name="Track" '
      'width="${map.width}" height="${map.height}" visible="0">',
    )
    ..writeln('  <data encoding="csv">');

  // Use GID 0 when track == 0 (empty), otherwise encode track as a simple
  // integer. Since Tiled has no built-in "metadata-only" layer, we store
  // track values as tile GIDs in a hidden layer. Consumers can read these
  // values via the layer's tile data. We use firstgid-based IDs so that
  // track value 1 → GID 1, etc.
  for (var y = 0; y < map.height; y++) {
    final row = StringBuffer();
    for (var x = 0; x < map.width; x++) {
      final raw = map.rawTiles[y * map.width + x];
      final track = MapData.tileTrack(raw);
      if (x > 0) row.write(',');
      row.write(track);
    }
    if (y < map.height - 1) row.write(',');
    buf.writeln(row);
  }

  buf
    ..writeln('  </data>')
    ..writeln(' </layer>');

  // --- Spawn object group (players, enemies, etc.) ---
  var layerId = 3;
  var objectId = 1;
  if (spawnSprites.isNotEmpty) {
    buf.writeln(' <objectgroup id="$layerId" name="Spawns">');
    for (final s in spawnSprites) {
      final typeName = s.spriteType?.name ?? 'Type${s.type}';
      buf
        ..writeln(
          '  <object id="$objectId" name="$typeName" '
          'x="${s.x}" y="${s.y}" width="0" height="0">',
        )
        ..writeln('   <properties>')
        ..writeln(
          '    <property name="sprite_type" type="string"'
          ' value="$typeName"/>',
        )
        ..writeln('   </properties>')
        ..writeln('  </object>');
      objectId++;
    }
    buf.writeln(' </objectgroup>');
    layerId++;
  }

  // --- Raised object group (trees, shrubs, etc.) ---
  if (envSprites.isNotEmpty) {
    buf.writeln(' <objectgroup id="$layerId" name="Raised">');
    for (final s in envSprites) {
      final typeName = s.spriteType?.name ?? 'Type${s.type}';
      buf
        ..writeln(
          '  <object id="$objectId" name="$typeName" '
          'x="${s.x}" y="${s.y}" width="0" height="0">',
        )
        ..writeln('   <properties>')
        ..writeln(
          '    <property name="sprite_type" type="string"'
          ' value="$typeName"/>',
        )
        ..writeln('   </properties>')
        ..writeln('  </object>');
      objectId++;
    }
    buf.writeln(' </objectgroup>');
  }

  buf.writeln('</map>');
  return buf.toString();
}
