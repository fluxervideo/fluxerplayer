// FluxerPlayer: Botón «Entrar con Fluxer» de la pantalla de servidores.

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:moonfin_design/moonfin_design.dart';

import '../../auth/repositories/server_repository.dart';
import '../../ui/navigation/destinations.dart';
import '../fluxer_routes.dart';
import '../fluxer_strings.dart';
import '../hub/fluxer_hub_client.dart';
import '../hub/fluxer_servers.dart';
import 'fluxer_login_service.dart';

class FluxerSignInCard extends StatefulWidget {
  const FluxerSignInCard({super.key, this.autofocus = false});

  final bool autofocus;

  @override
  State<FluxerSignInCard> createState() => _FluxerSignInCardState();
}

class _FluxerSignInCardState extends State<FluxerSignInCard> {
  String? _fluxerServerName;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _findFluxerServer();
  }

  /// El servidor guardado de Fluxer: el apuntado al entrar con Fluxer, o (si
  /// entró con una versión anterior) el que tenga la dirección que da el Hub.
  Future<void> _findFluxerServer() async {
    final ids = await FluxerServers.load();
    final servers = GetIt.instance<ServerRepository>().servers;
    var fluxer = servers.where((s) => ids.contains(s.id)).firstOrNull;
    if (fluxer == null && servers.isNotEmpty && await FluxerHubClient.instance.isLinked) {
      final me = await FluxerHubClient.instance.me();
      final host = Uri.tryParse(((me?['server'] as Map?)?['url'] as String?) ?? '')?.host;
      if (host != null && host.isNotEmpty) {
        fluxer = servers.where((s) => Uri.tryParse(s.address)?.host == host).firstOrNull;
        if (fluxer != null) await FluxerServers.add(fluxer.id);
      }
    }
    if (mounted && fluxer != null) setState(() => _fluxerServerName = fluxer!.name);
  }

  Future<void> _go() async {
    if (_busy) return;
    if (await FluxerHubClient.instance.isLinked) {
      setState(() => _busy = true);
      final service = FluxerLoginService();
      final session = await service.sessionFromHub();
      final result = session == null ? null : await service.complete(session).catchError((_) => null);
      if (!mounted) return;
      setState(() => _busy = false);
      if (result != null) {
        context.go(result.switched ? Destinations.home : '${Destinations.server}?serverId=${result.serverId}');
        return;
      }
    }
    if (mounted) context.go(fluxerLoginPath);
  }

  @override
  Widget build(BuildContext context) {
    final s = FluxerStrings.of(context);
    final name = _fluxerServerName;
    final title = name == null ? s.signInWithFluxer : s.continueWithFluxer;
    final subtitle = name == null ? s.signInWithFluxerSubtitle : s.continueWithFluxerSubtitle(name);

    return FilledButton(
      autofocus: widget.autofocus,
      onPressed: _busy ? null : _go,
      style: ButtonStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 18, vertical: 16)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        backgroundColor: WidgetStatePropertyAll(AppColorScheme.accent),
        foregroundColor: const WidgetStatePropertyAll(Colors.white),
        side: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.focused) || states.contains(WidgetState.hovered)
              ? const BorderSide(color: Colors.white, width: 3)
              : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Image.asset('assets/icons/app_icon.png'),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.arrow_forward_rounded),
        ],
      ),
    );
  }
}

/// «Añadir otro servidor», discreto, para cualquier servidor Emby.
class FluxerAddServerLink extends StatelessWidget {
  const FluxerAddServerLink({super.key, required this.onPressed, this.focusNode});

  final VoidCallback? onPressed;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final s = FluxerStrings.of(context);
    return TextButton.icon(
      focusNode: focusNode,
      onPressed: onPressed,
      icon: const Icon(Icons.add, size: 18),
      label: Text(s.addOtherServer),
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(AppColorScheme.onSurface.withValues(alpha: 0.75)),
        side: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.focused)
              ? BorderSide(color: AppColorScheme.accent, width: 2)
              : BorderSide.none,
        ),
      ),
    );
  }
}

/// «o con contraseña», entre el botón de Fluxer y el formulario.
class FluxerOrDivider extends StatelessWidget {
  const FluxerOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final color = AppColorScheme.onSurface.withValues(alpha: 0.4);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: color)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(FluxerStrings.of(context).orWithPassword, style: TextStyle(color: color, fontSize: 13)),
          ),
          Expanded(child: Divider(color: color)),
        ],
      ),
    );
  }
}

/// En la pantalla de contraseña: si el servidor es de Fluxer, el botón de
/// Fluxer arriba y «o con contraseña» debajo. Si no, nada.
class FluxerLoginShortcut extends StatelessWidget {
  const FluxerLoginShortcut({super.key, required this.serverId});

  final String serverId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Set<String>>(
      future: FluxerServers.load(),
      builder: (context, snapshot) {
        if (!(snapshot.data?.contains(serverId) ?? false)) return const SizedBox.shrink();
        return const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FluxerSignInCard(autofocus: true),
            FluxerOrDivider(),
          ],
        );
      },
    );
  }
}
