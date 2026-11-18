// FluxerPlayer: Qué servidores guardados son de Fluxer.

import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';

import '../../auth/repositories/session_repository.dart';
import '../../preference/user_preferences.dart';

class FluxerServers {
  FluxerServers._();

  static final _pref = Preference<String>(key: 'fluxer_server_ids', defaultValue: '');

  static UserPreferences? get _prefs =>
      GetIt.instance.isRegistered<UserPreferences>() ? GetIt.instance<UserPreferences>() : null;

  static Set<String> get ids {
    final raw = _prefs?.get(_pref) ?? '';
    return raw.split(',').where((id) => id.isNotEmpty).toSet();
  }

  /// Compatibilidad con quien lo pedía de forma diferida.
  static Future<Set<String>> load() async => ids;

  static bool contains(String serverId) => ids.contains(serverId);

  static Future<void> add(String serverId) async {
    final current = ids;
    if (!current.add(serverId)) return;
    await _prefs?.set(_pref, current.join(','));
  }

  static final _usersPref = Preference<String>(key: 'fluxer_user_keys', defaultValue: '');

  static Set<String> get _users =>
      (_prefs?.get(_usersPref) ?? '').split(',').where((k) => k.isNotEmpty).toSet();

  /// Usuario con el que se entró con Fluxer (para «Cambiar de usuario»).
  static Future<void> addUser(String serverId, String userId) async {
    final current = _users;
    if (!current.add('$serverId:$userId')) return;
    await _prefs?.set(_usersPref, current.join(','));
  }

  static bool isFluxerUser(String serverId, String userId) => _users.contains('$serverId:$userId');

  /// ¿Hay algún usuario apuntado? (Quien entró con una versión anterior no
  /// lo tiene: entonces no se filtra nada.)
  static bool get hasUsers => _users.isNotEmpty;

  /// ¿La sesión activa es de un servidor de Fluxer?
  static bool get activeIsFluxer {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<SessionRepository>()) return false;
    final serverId = getIt<SessionRepository>().activeServerId;
    return serverId != null && contains(serverId);
  }
}
