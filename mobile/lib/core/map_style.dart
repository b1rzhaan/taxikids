import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

/// Shared base-map tile layer.
///
/// CartoDB "Voyager" — a clean, Yandex-like light style served from a fast CDN.
/// The cancellable provider aborts requests for tiles that scroll out of view,
/// which removes most of the stutter when panning/zooming.
TileLayer kidsTileLayer() => TileLayer(
      urlTemplate:
          'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
      subdomains: const ['a', 'b', 'c', 'd'],
      userAgentPackageName: 'kz.kidstransfer',
      tileProvider: CancellableNetworkTileProvider(),
      maxZoom: 20,
    );

const kMapAttribution = '© OpenStreetMap · © CARTO';
