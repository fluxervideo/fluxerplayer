// FluxerPlayer: Barra de inicio con «Tendencias de hoy».

import 'package:server_core/server_core.dart';

import 'fluxer_hub_client.dart';
import 'fluxer_servers.dart';

/// Tope de seguridad: la colección suele tener 10-30 títulos.
const _maxTrending = 40;

Future<List<Map<String, dynamic>>> fluxerTrendingMediaBarItems(
  MediaServerClient client, {
  required String fields,
  required int maxItems,
}) async {
  if (!FluxerServers.activeIsFluxer) return const [];
  try {
    final ids = await FluxerHubClient.instance.trendingIds().timeout(const Duration(seconds: 6));
    if (ids.isEmpty) return const [];

    final response = await client.itemsApi
        .getItems(
          ids: ids,
          fields: fields,
          enableTotalRecordCount: false,
          enableImageTypes: 'Backdrop,Logo,Banner',
        )
        .timeout(const Duration(seconds: 10));
    final items = (response['Items'] as List? ?? const []).cast<Map<String, dynamic>>();

    // Emby no garantiza el orden de los ids: se ordena por el del trending.
    // Lo que el usuario no puede ver no viene, y sin fondo no luce en la barra.
    final rank = {for (var i = 0; i < ids.length; i++) ids[i]: i};
    final withBackdrop = items
        .where((item) => (item['BackdropImageTags'] as List?)?.isNotEmpty ?? false)
        .toList()
      ..sort((a, b) => (rank[a['Id']] ?? 1 << 30).compareTo(rank[b['Id']] ?? 1 << 30));
    // Toda la lista de «Tendencias de hoy» (no el número de la barra de Moonfin).
    return withBackdrop.take(maxItems > _maxTrending ? maxItems : _maxTrending).toList();
  } catch (_) {
    return const [];
  }
}
