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
    _meCache = null;
    _loaded = true;
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {}
  }

  /// Estado del plan, servidor, avisos y URLs del portal. Null si la app no
  /// está vinculada o no hay conexión.
  Future<Map<String, dynamic>?> me({bool fresh = false}) async {
    // Lo piden varias pantallas a la vez (lateral, menú del usuario, avisos):
    // 1 minuto de caché.
    final cached = _meCache;
    if (!fresh && cached != null && DateTime.now().difference(cached.$1) < const Duration(minutes: 1)) {
      return cached.$2;
    }
    final response = await _request((options) => _dio.get<Map<String, dynamic>>('me', options: options));
    final data = response?.data;
    _meCache = data == null ? null : (DateTime.now(), data);
    return data;
  }

  (DateTime, Map<String, dynamic>)? _meCache;

  Future<void> acknowledgeNotice(int id) async {
    await _request((options) => _dio.post<dynamic>('notices/$id/acknowledge', options: options));
  }

  /// Manda un «Reportar un problema». Devuelve su número en FluxerHub, o
  /// null si la app ya no está vinculada.
  Future<int?> report({
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
    return _id(response);
  }

  /// Manda el registro de diagnóstico: adjunto a [reportId] (un reporte que
  /// se acaba de mandar) o como solicitud nueva. Número de la solicitud, o
  /// null si la app ya no está vinculada.
  Future<int?> diagnostics(String log, {String? comment, int? reportId}) async {
    final response = await _request(
      (options) => _dio.post<dynamic>(
        'diagnostics',
        options: options.copyWith(sendTimeout: const Duration(seconds: 60)),
        data: {'log': log, 'comment': ?comment, 'report_id': ?reportId},
      ),
      rethrowErrors: true,
    );
    return _id(response);
  }

  static int? _id(Response<dynamic>? response) {
    if (response == null) return null;
    final data = response.data;
    final id = data is Map ? data['id'] : null;
    return id is int ? id : (id is num ? id.toInt() : 0);
  }

  /// Sesión de Emby nueva, sin contraseña, para la cuenta con la que se
  /// vinculó la app. Null si la app no está vinculada (o ya no lo está) o
  /// el Hub no puede dársela (cuenta inactiva, sin conexión…).
  Future<Map<String, dynamic>?> session() async {
    try {
      final response = await _request(
        (options) => _dio.post<Map<String, dynamic>>('session', options: options),
        rethrowErrors: true,
      );
      return response?.data;
    } catch (_) {
      return null;
    }
  }

  /// Enlace al portal con la sesión ya iniciada (un solo uso, 10 min).
  /// [to]: plans, account o support. Null si no está vinculada o sin conexión.
  Future<String?> portalLink(String to) async {
    try {
      final response = await _request(
        (options) => _dio.post<Map<String, dynamic>>('portal-link', options: options, data: {'to': to}),
        rethrowErrors: true,
      );
      return response?.data?['url'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// «Tendencias de hoy» del servidor de la app: ids de Emby en orden.
  Future<List<String>> trendingIds() async {
    final response = await _request((options) => _dio.get<Map<String, dynamic>>('trending', options: options));
    final ids = response?.data?['ids'];
    return ids is List ? ids.whereType<String>().toList() : const [];
  }

  /// Test de velocidad: lo que puede elegir (lo visto en 7 días o el vídeo
  /// de prueba) y si puede empezar ahora. Null si no está vinculada.
  Future<Map<String, dynamic>?> speedTestOptions() async {
    final response = await _request(
      (options) => _dio.get<Map<String, dynamic>>('connection-test', options: options),
      rethrowErrors: true,
    );
    return response?.data;
  }

  /// Empieza una prueba: el enlace firmado al tramo del vídeo y el del ping.
  /// Lanza [FluxerHubMessage] con el texto para el cliente si no se puede.
  Future<Map<String, dynamic>?> speedTestStart(int? eventId) async {
    try {
      final response = await _request(
        (options) => _dio.post<Map<String, dynamic>>('connection-test', options: options, data: {'event_id': eventId}),
        rethrowErrors: true,
      );
      return response?.data;
    } on DioException catch (e) {
      throw FluxerHubMessage(_message(e));
    }
  }

  /// Manda lo medido; el Hub calcula las medias y el veredicto.
  Future<Map<String, dynamic>?> speedTestResult(int id, Map<String, dynamic> data) async {
    try {
      final response = await _request(
        (options) => _dio.post<Map<String, dynamic>>('connection-test/$id/result', options: options, data: data),
        rethrowErrors: true,
      );
      return response?.data;
    } on DioException catch (e) {
      throw FluxerHubMessage(_message(e));
    }
  }

  /// Recargar saldo: métodos (los de la web), atajos de importe, saldo y
  /// el Telegram de soporte. Null si no está vinculada.
  Future<Map<String, dynamic>?> rechargeOptions() async {
    final response = await _request(
      (options) => _dio.get<Map<String, dynamic>>('recharge', options: options),
      rethrowErrors: true,
    );
    return response?.data;
  }

  /// El código de 4 cifras para el concepto del pago (reservado para él).
  Future<String?> rechargeCode(String method) async {
    try {
      final response = await _request(
        (options) => _dio.post<Map<String, dynamic>>('recharge/code', options: options, data: {'payment_method': method}),
        rethrowErrors: true,
      );
      return response?.data?['code'] as String?;
    } on DioException catch (e) {
      throw FluxerHubMessage(_message(e));
    }
  }

  /// Anota la solicitud de recarga; devuelve {id, status, amount, balance}.
  Future<Map<String, dynamic>?> rechargeRequest(String method, double? amount, String concept) async {
    try {
      final response = await _request(
        (options) => _dio.post<Map<String, dynamic>>(
          'recharge',
          options: options,
          data: {'payment_method': method, 'amount': amount, 'concept': concept},
        ),
        rethrowErrors: true,
      );
      return response?.data;
    } on DioException catch (e) {
      throw FluxerHubMessage(_message(e));
    }
  }

  /// Estado de una solicitud: pending, completed o rejected (y el saldo).
  Future<Map<String, dynamic>?> rechargeStatus(int id) async {
    final response = await _request((options) => _dio.get<Map<String, dynamic>>('recharge/$id', options: options));
    return response?.data;
  }

  static String? _message(DioException e) {
    final data = e.response?.data;
    return data is Map && data['message'] is String ? data['message'] as String : null;
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

/// Un error del Hub con el texto para el cliente (o null: sin conexión…).
class FluxerHubMessage implements Exception {
  const FluxerHubMessage(this.message);

  final String? message;
}
