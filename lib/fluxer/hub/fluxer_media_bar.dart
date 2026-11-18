// FluxerPlayer: la barra de medios de inicio enseña «Tendencias de hoy».
//
// En cuentas de Fluxer, en vez de elegir al azar, usa la colección
// «Tendencias de hoy» que FluxerHub rellena cada noche (lo más visto hoy en
// TMDb que tiene su servidor), en su orden: la nº 1 primero. Si no hay
// tendencias (servidor sin la colección, sin conexión con el Hub…), lista
// vacía y la barra sigue como en Moonfin.
//
// Enganche: lib/data/repositories/media_bar_repository.dart (`// FLUXER:`).

import 'package:server_core/server_core.dart';

import 'fluxer_hub_client.dart';
import 'fluxer_servers.dart';

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
    return withBackdrop.take(maxItems).toList();
  } catch (_) {
    return const [];
  }
}
