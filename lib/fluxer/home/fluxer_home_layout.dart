// FluxerPlayer: Filas de inicio según las secciones de inicio del servidor Emby.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:server_core/server_core.dart';

import '../../auth/repositories/session_repository.dart';
import '../../preference/home_section_config.dart';
import '../../preference/preference_constants.dart';
import '../../preference/user_preferences.dart';
import '../../ui/navigation/home_refresh_bus.dart';
import '../hub/fluxer_servers.dart';

class FluxerHomeLayout {
  FluxerHomeLayout._();

  /// {"owner": "<serverId>:<userId>", "json": "<home_sections_config>"}
  static final _pref = Preference<String>(key: 'fluxer_home_layout', defaultValue: '');

  /// Prefijo de las filas del servidor que carga FluxerPlayer.
  static const sectionPrefix = 'fluxer:';

  static UserPreferences? get _prefs =>
      GetIt.instance.isRegistered<UserPreferences>() ? GetIt.instance<UserPreferences>() : null;

  static String? get _owner {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<SessionRepository>()) return null;
    final session = getIt<SessionRepository>();
    final serverId = session.activeServerId;
    final userId = session.activeUserId;
    return serverId == null || userId == null ? null : '$serverId:$userId';
  }

  /// La configuración de filas que manda el servidor para la sesión activa,
  /// o null si aún no se ha leído (entonces se usa la de Moonfin).
  static String? get lockedJson {
    if (!FluxerServers.activeIsFluxer) return null;
    final raw = _prefs?.get(_pref) ?? '';
    if (raw.isEmpty) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['owner'] != _owner) return null;
      final json = data['json'] as String?;
      return json == null || json.isEmpty ? null : json;
    } catch (_) {
      return null;
    }
  }

  static bool _running = false;

  /// Lee las secciones de Emby y, si han cambiado, guarda la nueva
  /// configuración y pide recargar el inicio.
  static Future<void> refresh() async {
    if (_running || !FluxerServers.activeIsFluxer) return;
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<MediaServerClient>()) return;
    final owner = _owner;
    if (owner == null) return;
    _running = true;
    try {
      final client = getIt<MediaServerClient>();
      final sections = await _fetchSections(client);
      if (sections == null) return;
      final serverId = owner.split(':').first;
      final json = HomeSectionConfig.toJsonString(_translate(sections, serverId));
      if (json == lockedJson) return;
      await _prefs?.set(_pref, jsonEncode({'owner': owner, 'json': json}));
      homeRefreshBus.requestNowOrAfterNavigation();
    } catch (_) {
      // Sin conexión o Emby caído: se queda la última configuración leída.
    } finally {
      _running = false;
    }
  }

  static Future<List<Map<String, dynamic>>?> _fetchSections(MediaServerClient client) async {
    final userId = client.userId;
    final token = client.accessToken;
    if (userId == null || token == null) return null;
    final response = await _dio(client).get<List<dynamic>>('/Users/$userId/HomeSections');
    return response.data?.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
  }

  static Dio _dio(MediaServerClient client) => Dio(
    BaseOptions(
      baseUrl: client.baseUrl.endsWith('/') ? client.baseUrl.substring(0, client.baseUrl.length - 1) : client.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'X-Emby-Token': client.accessToken ?? '', 'Accept': 'application/json'},
    ),
  );

  static List<HomeSectionConfig> _translate(List<Map<String, dynamic>> sections, String serverId) {
    final configs = <HomeSectionConfig>[];
    var spotlightUsed = false;
    var latestUsed = false;

    void builtin(HomeSectionType type) {
      if (configs.any((c) => c.isBuiltin && c.type == type)) return;
      configs.add(HomeSectionConfig(type: type, order: configs.length));
    }

    void serverRow(Map<String, dynamic> section, Map<String, dynamic> query) {
      final name = (section['CustomName'] ?? section['Name'] ?? '').toString();
      configs.add(
        HomeSectionConfig.pluginDynamic(
          serverId: serverId,
          pluginSection: '$sectionPrefix${section['Id']}',
          pluginAdditionalData: jsonEncode(query),
          pluginDisplayText: name,
          pluginSource: HomeSectionPluginSource.server,
          order: configs.length,
        ),
      );
    }

    List<String> ids(Object? value) =>
        value is List ? value.map((v) => v.toString()).where((v) => v.isNotEmpty).toList() : const [];

    for (final section in sections) {
      final type = (section['SectionType'] ?? '').toString().toLowerCase();
      final query = (section['Query'] as Map?)?.cast<String, dynamic>() ?? const {};
      switch (type) {
        case 'boxset':
          final parentId = (section['ParentId'] ?? '').toString();
          if (parentId.isEmpty) break;
          if (!spotlightUsed && (section['ViewType'] ?? '').toString().toLowerCase() == 'spotlight') {
            spotlightUsed = true;
            builtin(HomeSectionType.mediaBar);
          } else {
            serverRow(section, {'kind': 'boxset', 'parentId': parentId});
          }
        case 'resume':
          builtin(HomeSectionType.resume);
        case 'nextup':
          builtin(HomeSectionType.nextUp);
        case 'userviews':
        case 'mymedia':
          builtin(HomeSectionType.libraryTilesSmall);
        case 'latestmedia':
          if (!latestUsed) {
            latestUsed = true;
            builtin(HomeSectionType.latestMedia);
          }
        case 'collections':
          serverRow(section, {
            'kind': 'collections',
            'sortBy': section['SortBy'],
            'sortOrder': section['SortOrder'],
          });
        case 'items':
          serverRow(section, {
            'kind': 'items',
            'itemTypes': ids(section['ItemTypes']),
            'tagIds': ids(query['TagIds']),
            'genreIds': ids(query['GenreIds']),
            'studioIds': ids(query['StudioIds']),
            'sortBy': section['SortBy'],
            'sortOrder': section['SortOrder'],
          });
        default:
          // Tipos que Moonfin no sabe enseñar igual (TV en directo…): fuera.
          break;
      }
    }
    return configs;
  }

  /// Contenido de una fila del servidor (`fluxer:<id>`), como lo pediría la
  /// web de Emby. Null si la fila no es de FluxerPlayer.
  static Future<Map<String, dynamic>?> serverRowItems(
    MediaServerClient client,
    String section,
    String? additionalData,
  ) async {
    if (!section.startsWith(sectionPrefix)) return null;
    final userId = client.userId;
    if (userId == null) return const {'Items': [], 'TotalRecordCount': 0};
    Map<String, dynamic> query = const {};
    try {
      query = (jsonDecode(additionalData ?? '{}') as Map).cast<String, dynamic>();
    } catch (_) {}

    String? csv(Object? value) {
      final list = value is List ? value.map((v) => v.toString()).where((v) => v.isNotEmpty).toList() : const <String>[];
      return list.isEmpty ? null : list.join(',');
    }

    final params = <String, dynamic>{
      'Limit': 60,
      'Fields': 'PrimaryImageAspectRatio,BasicSyncInfo,Overview,ProductionYear,Genres,'
          'CommunityRating,OfficialRating,ProviderIds,ChildCount,RecursiveItemCount',
      'EnableImageTypes': 'Primary,Backdrop,Thumb,Logo',
      'ImageTypeLimit': 1,
      'EnableTotalRecordCount': false,
    };
    switch (query['kind']) {
      case 'boxset':
        params['ParentId'] = query['parentId'];
      case 'collections':
        params['Recursive'] = true;
        params['IncludeItemTypes'] = 'BoxSet';
        params['SortBy'] = query['sortBy'] ?? 'SortName';
        params['SortOrder'] = query['sortOrder'] ?? 'Ascending';
      case 'items':
        params['Recursive'] = true;
        if (csv(query['itemTypes']) case final types?) params['IncludeItemTypes'] = types;
        if (csv(query['tagIds']) case final tags?) params['TagIds'] = tags;
        if (csv(query['genreIds']) case final genres?) params['GenreIds'] = genres;
        if (csv(query['studioIds']) case final studios?) params['StudioIds'] = studios;
        if (query['sortBy'] != null) params['SortBy'] = query['sortBy'];
        if (query['sortOrder'] != null) params['SortOrder'] = query['sortOrder'];
      default:
        return const {'Items': [], 'TotalRecordCount': 0};
    }
    final response = await _dio(client).get<Map<String, dynamic>>('/Users/$userId/Items', queryParameters: params);
    return response.data ?? const {'Items': [], 'TotalRecordCount': 0};
  }
}
