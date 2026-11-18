// FluxerPlayer: Entrar con un código aceptado en la cuenta de Fluxer.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:server_core/server_core.dart';

import '../../auth/models/user.dart';
import '../../auth/repositories/server_repository.dart';
import '../../auth/repositories/session_repository.dart';
import '../../auth/store/authentication_store.dart';
import '../fluxer_config.dart';
import '../hub/fluxer_hub_client.dart';
import '../hub/fluxer_servers.dart';
import '../../preference/user_preferences.dart';
import '../../ui/widgets/navigation_layout.dart';
import '../home/fluxer_home_layout.dart';

/// Código que enseña la app mientras espera.
class FluxerLoginCode {
  final String code;
  final String secret;
  final String approveUrl;
  final Duration interval;
  final DateTime expiresAt;

  const FluxerLoginCode({
    required this.code,
    required this.secret,
    required this.approveUrl,
    required this.interval,
    required this.expiresAt,
  });
}

/// Sesión de Emby que entrega FluxerHub una sola vez, ya aceptada.
class FluxerLoginSession {
  final String serverUrl;
  final String serverName;
  final String userId;
  final String userName;
  final String accessToken;

  /// Token propio de la app en FluxerHub (solo /api/app/*).
  final String? hubToken;

  const FluxerLoginSession({
    required this.serverUrl,
    required this.serverName,
    required this.userId,
    required this.userName,
    required this.accessToken,
    this.hubToken,
  });
}

enum FluxerLoginStatus { pending, approved, expired }

class FluxerLoginPoll {
  final FluxerLoginStatus status;
  final FluxerLoginSession? session;

  const FluxerLoginPoll(this.status, [this.session]);
}

/// Resultado de guardar la sesión en la app.
class FluxerLoginResult {
  final String serverId;
  final bool switched;

  const FluxerLoginResult({required this.serverId, required this.switched});
}

class FluxerLoginService {
  FluxerLoginService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: '$fluxerHubUrl/api/',
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 15),
                headers: const {'Accept': 'application/json'},
              ),
            );

  final Dio _dio;

  /// Pide un código nuevo. Manda los mismos datos de aparato que la app
  /// manda a Emby (y limpiados igual), para que Emby vea un solo dispositivo.
  Future<FluxerLoginCode> start() async {
    final device = GetIt.instance<DeviceInfo>();
    final response = await _dio.post<Map<String, dynamic>>(
      'app-login/start',
      data: {
        'device_id': _sanitize(device.id),
        'device_name': _clamp(_sanitize(device.name), 80),
        'client_name': _clamp(_sanitize(device.appName), 60),
        'app_version': _clamp(_sanitize(device.appVersion), 30),
      },
    );
    final data = response.data ?? const <String, dynamic>{};
    final seconds = (data['interval'] as num?)?.toInt() ?? 5;
    return FluxerLoginCode(
      code: data['code'] as String,
      secret: data['secret'] as String,
      approveUrl: data['approve_url'] as String,
      interval: Duration(seconds: seconds < 2 ? 2 : seconds),
      expiresAt:
          DateTime.tryParse(data['expires_at'] as String? ?? '') ??
              DateTime.now().add(const Duration(minutes: 10)),
    );
  }

  /// ¿Ya lo ha aceptado el cliente? La sesión llega una sola vez.
  Future<FluxerLoginPoll> poll(String secret) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'app-login/status',
      data: {'secret': secret},
    );
    final data = response.data ?? const <String, dynamic>{};
    switch (data['status']) {
      case 'approved':
        return FluxerLoginPoll(
          FluxerLoginStatus.approved,
          FluxerLoginSession(
            serverUrl: data['server_url'] as String,
            serverName: data['server_name'] as String? ?? '',
            userId: data['user_id'] as String,
            userName: data['user_name'] as String? ?? '',
            accessToken: data['access_token'] as String,
            hubToken: data['hub_token'] as String?,
          ),
        );
      case 'pending':
        return const FluxerLoginPoll(FluxerLoginStatus.pending);
      default:
        return const FluxerLoginPoll(FluxerLoginStatus.expired);
    }
  }

  /// Sesión de Emby nueva sin contraseña desde FluxerHub (app ya vinculada).
  /// Null si no puede (sin vincular, cuenta inactiva, sin conexión).
  Future<FluxerLoginSession?> sessionFromHub() async {
    final data = await FluxerHubClient.instance.session();
    if (data == null || data['access_token'] == null) return null;
    return FluxerLoginSession(
      serverUrl: data['server_url'] as String,
      serverName: data['server_name'] as String? ?? '',
      userId: data['user_id'] as String,
      userName: data['user_name'] as String? ?? '',
      accessToken: data['access_token'] as String,
    );
  }

  /// Guarda servidor + usuario y abre la sesión (igual que Emby Connect).
  /// Devuelve null si no se puede conectar con el servidor.
  Future<FluxerLoginResult?> complete(FluxerLoginSession session) async {
    final getIt = GetIt.instance;
    final server = await getIt<ServerRepository>().addServer(session.serverUrl);
    if (server == null) return null;

    await FluxerServers.add(server.id);
    await FluxerServers.addUser(server.id, session.userId);

    final hubToken = session.hubToken;
    if (hubToken != null && hubToken.isNotEmpty) {
      await FluxerHubClient.instance.saveToken(hubToken);
    }

    await getIt<AuthenticationStore>().putUser(
      PrivateUser(
        id: session.userId,
        name: session.userName,
        serverId: server.id,
        accessToken: session.accessToken,
        lastUsed: DateTime.now(),
      ),
    );

    final switched = await getIt<SessionRepository>().switchCurrentSession(
      serverId: server.id,
      userId: session.userId,
      username: session.userName,
    );
    // Las opciones que fija Fluxer (p. ej. la barra lateral) cambian al
    // entrar en una cuenta de Fluxer: la barra se coloca ya, sin reiniciar.
    NavigationLayout.positionNotifier.value =
        NavigationLayout.sanitizeNavbarPosition(getIt<UserPreferences>().get(UserPreferences.navbarPosition));

    // Las filas de inicio que manda Emby para esta cuenta.
    unawaited(FluxerHomeLayout.refresh());

    return FluxerLoginResult(serverId: server.id, switched: switched);
  }

  // Igual que buildServerAuthorizationHeader (packages/server_core,
  // auth_header.dart): Emby recibe estos valores ya limpiados.
  static String _sanitize(String value) {
    final asciiOnly = value.replaceAll(RegExp(r'[^\x20-\x7E]'), ' ');
    final noQuotes = asciiOnly
        .replaceAll('"', '')
        .replaceAll('\\', '')
        .replaceAll(',', ' ')
        .replaceAll(RegExp(r'[\r\n\t]'), ' ');
    final collapsed = noQuotes.replaceAll(RegExp(r'\s+'), ' ').trim();
    return collapsed.isEmpty ? 'Unknown' : collapsed;
  }

  static String _clamp(String value, int max) =>
      value.length <= max ? value : value.substring(0, max);
}
