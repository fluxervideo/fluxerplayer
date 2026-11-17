// FluxerPlayer: la app frente a FluxerHub con su token propio.
//
// El token llega al entrar con código (FluxerLoginService) y SOLO abre
// /api/app/* en el Hub (estado del plan, avisos, reportar un problema).
// Se guarda en el almacén seguro del sistema. Si el Hub dice que la app ya
// no está vinculada (401), se borra y la app deja de preguntar.

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../fluxer_config.dart';

class FluxerHubClient {
  FluxerHubClient._();

  static final FluxerHubClient instance = FluxerHubClient._();

  static const _tokenKey = 'fluxer_hub_app_token';

  final _storage = const FlutterSecureStorage();
  final _dio = Dio(
    BaseOptions(
      baseUrl: '$fluxerHubUrl/api/app/',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: const {'Accept': 'application/json'},
    ),
  );

  String? _token;
  bool _loaded = false;

  Future<String?> token() async {
    if (!_loaded) {
      try {
        _token = await _storage.read(key: _tokenKey);
      } catch (_) {
        _token = null;
      }
      _loaded = true;
    }
    return _token;
  }

  Future<bool> get isLinked async => (await token()) != null;

  Future<void> saveToken(String token) async {
    _token = token;
    _loaded = true;
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (_) {
      // Sin almacén seguro (llavero bloqueado): vale para esta sesión.
    }
  }

  Future<void> clearToken() async {
    _token = null;
    _loaded = true;
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {}
  }

  /// Estado del plan, servidor, avisos y URLs del portal. Null si la app no
  /// está vinculada o no hay conexión.
  Future<Map<String, dynamic>?> me() async {
    final response = await _request((options) => _dio.get<Map<String, dynamic>>('me', options: options));
    return response?.data;
  }

  Future<void> acknowledgeNotice(int id) async {
    await _request((options) => _dio.post<dynamic>('notices/$id/acknowledge', options: options));
  }

  /// Manda un «Reportar un problema». Devuelve true si llegó.
  Future<bool> report({
    required String type,
    required String title,
    String? comment,
    String? symptom,
    String? embyItemId,
    String? embyItemType,
    int? seasonNumber,
    int? episodeNumber,
  }) async {
    final response = await _request(
      (options) => _dio.post<dynamic>(
        'reports',
        options: options,
        data: {
          'type': type,
          'title': title,
          'comment': ?comment,
          'symptom': ?symptom,
          'emby_item_id': ?embyItemId,
          'emby_item_type': ?embyItemType,
          'season_number': ?seasonNumber,
          'episode_number': ?episodeNumber,
        },
      ),
      rethrowErrors: true,
    );
    return response != null;
  }

  Future<void> logout() async {
    await _request((options) => _dio.post<dynamic>('logout', options: options));
    await clearToken();
  }

  Future<Response<T>?> _request<T>(
    Future<Response<T>> Function(Options options) send, {
    bool rethrowErrors = false,
  }) async {
    final current = await token();
    if (current == null) return null;
    try {
      return await send(Options(headers: {'X-App-Token': current}));
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await clearToken();
        return null;
      }
      if (rethrowErrors) rethrow;
      return null;
    }
  }
}
