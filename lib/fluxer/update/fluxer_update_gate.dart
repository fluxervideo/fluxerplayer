// FluxerPlayer: al abrir la app, si hay versión nueva, pantalla completa con
// «Actualizar» o «Cancelar» por encima de todo (no se ve lo de detrás).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:moonfin_design/moonfin_design.dart';

import '../../data/services/app_update_service.dart';
import '../../ui/navigation/app_router.dart';
import '../../ui/widgets/app_update_dialog.dart';
import '../../util/platform_detection.dart';
import '../fluxer_strings.dart';

/// La versión nueva encontrada al abrir la app (aunque se haya cancelado):
/// «Acerca de» ofrece entonces «Actualizar a la versión X».
final fluxerKnownUpdate = ValueNotifier<DesktopUpdateInfo?>(null);

class FluxerUpdateGate extends StatefulWidget {
  const FluxerUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  State<FluxerUpdateGate> createState() => _FluxerUpdateGateState();
}

class _FluxerUpdateGateState extends State<FluxerUpdateGate> {
  DesktopUpdateInfo? _update;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_check()));
  }

  Future<void> _check() async {
    try {
      if (!GetIt.instance.isRegistered<AppUpdateService>()) return;
      final update = await GetIt.instance<AppUpdateService>()
          .fluxerCheckOnLaunch();
      fluxerKnownUpdate.value = update;
      if (mounted && update != null) setState(() => _update = update);
    } catch (_) {}
  }

  void _cancel() => setState(() => _update = null);

  void _accept() {
    final update = _update;
    setState(() => _update = null);
    if (update == null) return;
    // La descarga usa los diálogos de la app, que necesitan el navegador.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = appRouter.routerDelegate.navigatorKey.currentContext;
      if (context != null && context.mounted) {
        unawaited(fluxerStartUpdate(context, update));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final update = _update;
    return Stack(
      children: [
        ExcludeFocus(excluding: update != null, child: widget.child),
        if (update != null)
          Positioned.fill(
            child: _UpdateScreen(
              version: update.version.replaceFirst(RegExp('^[vV]'), ''),
              onAccept: _accept,
              onCancel: _cancel,
            ),
          ),
      ],
    );
  }
}

class _UpdateScreen extends StatelessWidget {
  const _UpdateScreen({
    required this.version,
    required this.onAccept,
    required this.onCancel,
  });

  final String version;
  final VoidCallback onAccept;
  final VoidCallback onCancel;

  static bool _isBack(KeyEvent event) =>
      event.logicalKey == LogicalKeyboardKey.goBack ||
      event.logicalKey == LogicalKeyboardKey.escape ||
      event.logicalKey == LogicalKeyboardKey.browserBack;

  @override
  Widget build(BuildContext context) {
    final s = FluxerStrings.of(context);
    final mobile = PlatformDetection.useMobileUi;
    final muted = AppColorScheme.onSurface.withValues(alpha: 0.7);
    return Material(
      color: AppColorScheme.background,
      child: FocusScope(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && _isBack(event)) {
            onCancel();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Image.asset(
                        'assets/images/logo_and_text.png',
                        height: mobile ? 56 : 72,
                      ),
                    ),
                    const SizedBox(height: 36),
                    Icon(
                      Icons.system_update_alt_rounded,
                      size: 56,
                      color: AppColorScheme.accent,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      s.updateScreenTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: mobile ? 24 : 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      s.updateScreenBody(version),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: muted),
                    ),
                    const SizedBox(height: 32),
                    _OkKey(
                      onOk: onAccept,
                      child: FilledButton.icon(
                        autofocus: true,
                        onPressed: onAccept,
                        icon: const Icon(Icons.download_rounded),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            s.updateNow,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        style: ButtonStyle(
                          side: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.focused)
                                ? const BorderSide(
                                    color: Colors.white,
                                    width: 3,
                                  )
                                : BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _OkKey(
                      onOk: onCancel,
                      child: OutlinedButton(
                        onPressed: onCancel,
                        style: ButtonStyle(
                          side: WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.focused) ||
                                states.contains(WidgetState.hovered)) {
                              return BorderSide(
                                color: AppColorScheme.accent,
                                width: 2,
                              );
                            }
                            return BorderSide(
                              color: AppColorScheme.onSurface.withValues(
                                alpha: 0.25,
                              ),
                            );
                          }),
                          foregroundColor: WidgetStateProperty.resolveWith((
                            states,
                          ) {
                            if (states.contains(WidgetState.focused) ||
                                states.contains(WidgetState.hovered)) {
                              return AppColorScheme.accent;
                            }
                            return AppColorScheme.onSurface.withValues(
                              alpha: 0.85,
                            );
                          }),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            s.cancel,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// OK del mando (y Intro) sobre el botón de dentro, sin depender de los
/// atajos de la app: igual que las filas de los diálogos del reproductor.
class _OkKey extends StatelessWidget {
  const _OkKey({required this.onOk, required this.child});

  final VoidCallback onOk;
  final Widget child;

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onKeyEvent: (_, event) {
      if (event is KeyDownEvent &&
          (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter ||
              event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
        onOk();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: child,
  );
}
