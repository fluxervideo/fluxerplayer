// FluxerPlayer: qué servidores guardados son de Fluxer (se entró en ellos
// con «Entrar con Fluxer»). Sirve para destacar «Continuar con Fluxer» en la
// pantalla de servidores y ofrecer entrar sin contraseña.

import 'package:shared_preferences/shared_preferences.dart';

class FluxerServers {
  FluxerServers._();

  static const _key = 'fluxer_server_ids';
  static Set<String> _cache = {};
  static bool _loaded = false;

  /// Carga la lista (una vez). Las pantallas la leen luego con [contains].
  static Future<Set<String>> load() async {
    if (_loaded) return _cache;
    try {
      final prefs = await SharedPreferences.getInstance();
      _cache = (prefs.getStringList(_key) ?? const []).toSet();
    } catch (_) {}
    _loaded = true;
    return _cache;
  }

  static bool contains(String serverId) => _cache.contains(serverId);

  static Future<void> add(String serverId) async {
    await load();
    if (!_cache.add(serverId)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, _cache.toList());
    } catch (_) {}
  }
}
