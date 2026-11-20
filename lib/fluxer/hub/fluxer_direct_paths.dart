// FluxerPlayer: Carpetas que la app lee directamente de otra dirección, sin
// pasar por el servidor Emby (la lista llega de FluxerHub).

import 'dart:convert';

import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:playback_emby/playback_emby.dart';

import '../../preference/user_preferences.dart';

class FluxerDirectPaths {
  FluxerDirectPaths._();

  /// `{"host": "<servidor Emby>", "paths": [{"prefix": "/…/", "url": "https://…/"}]}`
  static final _pref = Preference<String>(key: 'fluxer_direct_paths', defaultValue: '');

  static UserPreferences? get _prefs =>
      GetIt.instance.isRegistered<UserPreferences>() ? GetIt.instance<UserPreferences>() : null;

  /// Engancha la lectura directa al reproductor de Emby.
  static void install() => EmbyMediaStreamResolver.directPathUrl = urlFor;

  /// Guarda la lista del servidor que manda el Hub en `me` (`server`).
  static Future<void> save(Map<String, dynamic>? server) async {
    final prefs = _prefs;
    if (prefs == null) return;
    final host = _host(server?['url'] as String?);
    final paths = [
      for (final p in (server?['direct_paths'] as List?) ?? const [])
        if (p is Map && p['prefix'] is String && p['url'] is String)
          {'prefix': p['prefix'] as String, 'url': p['url'] as String},
    ];
    final value = host == null || paths.isEmpty ? '' : jsonEncode({'host': host, 'paths': paths});
    if (prefs.get(_pref) != value) await prefs.set(_pref, value);
  }

  /// La dirección de donde leer [path] del servidor [serverBaseUrl], o null
  /// si va por el servidor.
  static String? urlFor(String serverBaseUrl, String path) {
    final raw = _prefs?.get(_pref) ?? '';
    if (raw.isEmpty) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['host'] != _host(serverBaseUrl)) return null;
      for (final p in (data['paths'] as List?) ?? const []) {
        final prefix = (p as Map)['prefix'] as String;
        if (!path.startsWith(prefix)) continue;
        final rest = path.substring(prefix.length).split('/').map(Uri.encodeComponent).join('/');
        return '${p['url']}$rest';
      }
    } catch (_) {}
    return null;
  }

  static String? _host(String? url) {
    final host = url == null ? null : Uri.tryParse(url)?.host.toLowerCase();
    return host == null || host.isEmpty ? null : host;
  }
}
