// FluxerPlayer: un usuario de Fluxer sin sesión de Fluxer en el aparato no
// puede seguir: «Vuelve a entrar con Fluxer» por encima de todo. Pasa al
// abrir la app o cambiar de usuario sin sesión, y cuando FluxerHub la rechaza
// (aparato desvinculado). Sin conexión con FluxerHub no se bloquea nada: solo
// cuenta lo guardado en el aparato y lo que FluxerHub conteste.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:playback_core/playback_core.dart';

import '../../auth/repositories/session_repository.dart';
import '../../auth/repositories/user_repository.dart';
import '../hub/fluxer_hub_client.dart';
import '../hub/fluxer_servers.dart';
import 'fluxer_login_screen.dart';

class FluxerLinkGate extends StatefulWidget {
  const FluxerLinkGate({super.key, required this.child});

  final Widget child;

  @override
  State<FluxerLinkGate> createState() => _FluxerLinkGateState();
}

class _FluxerLinkGateState extends State<FluxerLinkGate> {
  StreamSubscription<Object?>? _sessionChanges;
  StreamSubscription<Object?>? _userChanges;

  /// `<servidor>:<usuario>` que tiene que volver a entrar, o null.
  String? _blocked;
  String _userName = '';
  int _check = 0;

  @override
  void initState() {
    super.initState();
    final getIt = GetIt.instance;
    if (getIt.isRegistered<SessionRepository>()) {
      _sessionChanges = getIt<SessionRepository>().stateStream.listen((_) => _recheck());
    }
    if (getIt.isRegistered<UserRepository>()) {
      // El nombre del usuario puede llegar después de abrirse la sesión.
      _userChanges = getIt<UserRepository>().currentUserStream.listen((_) => _recheck());
    }
    FluxerHubClient.instance.linkChanges.addListener(_recheck);
    _recheck();
  }

  @override
  void dispose() {
    unawaited(_sessionChanges?.cancel());
    unawaited(_userChanges?.cancel());
    FluxerHubClient.instance.linkChanges.removeListener(_recheck);
    super.dispose();
  }

  Future<void> _recheck() async {
    final check = ++_check;
    String? blocked;
    var name = '';
    try {
      final getIt = GetIt.instance;
      if (getIt.isRegistered<SessionRepository>() && FluxerServers.activeIsFluxer) {
        final session = getIt<SessionRepository>();
        final serverId = session.activeServerId;
        final userId = session.activeUserId;
        if (serverId != null && userId != null && await FluxerHubClient.instance.token() == null) {
          blocked = '$serverId:$userId';
          if (getIt.isRegistered<UserRepository>()) name = getIt<UserRepository>().currentUser?.name ?? '';
        }
      }
    } catch (_) {
      blocked = null;
    }
    if (!mounted || check != _check) return;
    if (blocked != null && _blocked == null) _stopPlayback();
    if (blocked != _blocked || name != _userName) {
      setState(() {
        _blocked = blocked;
        _userName = name;
      });
    }
  }

  /// Si FluxerHub la rechaza mientras se ve algo, no sigue sonando detrás.
  static void _stopPlayback() {
    if (!GetIt.instance.isRegistered<PlaybackManager>()) return;
    unawaited(GetIt.instance<PlaybackManager>().stop(userInitiated: false).catchError((_) {}));
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _blocked;
    return Stack(
      children: [
        ExcludeFocus(excluding: blocked != null, child: widget.child),
        if (blocked != null)
          Positioned.fill(
            child: Material(
              child: FluxerLoginScreen(key: ValueKey(blocked), relinkUser: _userName),
            ),
          ),
      ],
    );
  }
}
