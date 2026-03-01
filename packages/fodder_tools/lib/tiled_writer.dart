import 'package:fodder_tools/map_reader.dart';
import 'package:fodder_tools/tileset_builder.dart';

/// Generates a Tiled `.tsx` tileset definition in XML format.
///
/// [name] is the tileset name (e.g. `jungle`).
/// [imageFilename] is the relative path to the tileset PNG (e.g.
/// `jungle.png`).
/// [imageWidth] and [imageHeight] are the tileset PNG dimensions in pixels.
// TODO(bramp): Is there a tiled library we should be using instead?
String generateTsx({
  required String name,
  required String imageFilename,
  required int imageWidth,
  required int imageHeight,
}) {
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
    )
    ..writeln('</tileset>');
  return buf.toString();
}

/// Generates a Tiled `.tmx` map file in XML format.
///
/// [map] contains the parsed map data (dimensions and tile indices).
/// [tilesetTsxFilename] is the relative path to the `.tsx` tileset file.
///
/// Tiled uses **1-based** Global Tile IDs (GID). GID 0 means "empty".
/// Since our tileset starts at firstgid=1, the GID for a tile with
/// graphic index `i` is `i + 1`.
String generateTmx({required MapData map, required String tilesetTsxFilename}) {
  final buf = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln(
      '<map version="1.10" tiledversion="1.11.2" '
      'orientation="orthogonal" renderorder="right-down" '
      'width="${map.width}" height="${map.height}" '
      'tilewidth="$tileSize" tileheight="$tileSize" '
      'infinite="0" '
      'nextlayerid="3" nextobjectid="1">',
    )
    ..writeln(' <tileset firstgid="1" source="$tilesetTsxFilename"/>')
    // --- Tile layer ---
    ..writeln(
      ' <layer id="1" name="Tiles" '
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
    ..writeln(' </layer>')
    ..writeln('</map>');

  return buf.toString();
}
