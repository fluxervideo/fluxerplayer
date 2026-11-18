// FluxerPlayer: qué servidores guardados son de Fluxer (se entró en ellos
// con «Entrar con Fluxer»), y si la sesión activa es de uno de ellos.
//
// Sirve para destacar «Continuar con Fluxer», ofrecer entrar sin contraseña
// y aplicar las opciones que fija Fluxer (fluxer_locks.dart) SOLO en cuentas
// de Fluxer. Se guarda en el mismo almacén que las preferencias de Moonfin
// porque se lee de forma inmediata (al pintar).

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

  /// ¿La sesión activa es de un servidor de Fluxer?
  static bool get activeIsFluxer {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<SessionRepository>()) return false;
    final serverId = getIt<SessionRepository>().activeServerId;
    return serverId != null && contains(serverId);
  }
}
