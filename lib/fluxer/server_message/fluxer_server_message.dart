// FluxerPlayer: mensajes del servidor (Emby "Enviar mensaje", también desde
// FluxerHub) grandes, centrados y durante el tiempo pedido.
//
// Moonfin los enseñaba como notificación del sistema o un aviso pequeño de
// duración fija, ignorando TimeoutMs (en una tele casi no se veían). Aquí:
// - Tarjeta grande en el centro, por encima de todo (también del vídeo).
// - Dura exactamente TimeoutMs, con una barra que se va vaciando. Sin
//   TimeoutMs (o 0), se queda hasta que el cliente pulse «Entendido».
// - «Entendido» se puede pulsar con el mando (tiene el foco), y Atrás/Esc
//   también lo cierra. Al cerrarse, el foco vuelve a donde estaba.
// - Un mensaje nuevo sustituye al que se esté enseñando.
//
// Enganche: lib/auth/repositories/session_repository.dart (`// FLUXER:`).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moonfin_design/moonfin_design.dart';

import '../../ui/navigation/app_router.dart';
import '../fluxer_strings.dart';

OverlayEntry? _current;

/// Enseña el mensaje. Devuelve false si no hay dónde (app sin pantalla aún),
/// para que se use la vía de siempre.
bool showFluxerServerMessage({
  required String text,
  String? header,
  String? timeoutMs,
}) {
  final context = appRouter.routerDelegate.navigatorKey.currentContext;
  if (context == null || !context.mounted) return false;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return false;

  final ms = int.tryParse(timeoutMs?.trim() ?? '') ?? 0;
  final duration = ms > 0 ? Duration(milliseconds: ms) : null;

  _dismissCurrent();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _ServerMessageCard(
      header: header?.trim() ?? '',
      text: text.trim(),
      duration: duration,
      onDismissed: () {
        if (entry.mounted) entry.remove();
        if (identical(_current, entry)) _current = null;
      },
    ),
  );
  _current = entry;
  overlay.insert(entry);
  return true;
}

void _dismissCurrent() {
  final entry = _current;
  _current = null;
  if (entry != null && entry.mounted) entry.remove();
}

class _ServerMessageCard extends StatefulWidget {
  const _ServerMessageCard({
    required this.header,
    required this.text,
    required this.duration,
    required this.onDismissed,
  });

  final String header;
  final String text;
  final Duration? duration;
  final VoidCallback onDismissed;

  @override
  State<_ServerMessageCard> createState() => _ServerMessageCardState();
}

class _ServerMessageCardState extends State<_ServerMessageCard>
    with TickerProviderStateMixin {
  late final AnimationController _appear = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  AnimationController? _countdown;
  final _buttonFocus = FocusNode();
  FocusNode? _previousFocus;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _previousFocus = FocusManager.instance.primaryFocus;
    _appear.forward();
    final duration = widget.duration;
    if (duration != null) {
      _countdown = AnimationController(vsync: this, duration: duration)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) _close();
        })
        ..forward();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _buttonFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _appear.dispose();
    _countdown?.dispose();
    _buttonFocus.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    _countdown?.stop();
    if (mounted) await _appear.reverse();
    final previous = _previousFocus;
    widget.onDismissed();
    if (previous != null && previous.context != null && previous.canRequestFocus) {
      previous.requestFocus();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      _close();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final s = FluxerStrings.of(context);
    final size = MediaQuery.sizeOf(context);
    final big = size.shortestSide >= 600; // tele / ordenador
    final title = widget.header.isNotEmpty ? widget.header : s.serverMessageTitle;

    return FadeTransition(
      opacity: CurvedAnimation(parent: _appear, curve: Curves.easeOut),
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        child: Focus(
          onKeyEvent: _onKey,
          child: Center(
            child: ScaleTransition(
              scale: Tween(begin: 0.94, end: 1.0).animate(
                CurvedAnimation(parent: _appear, curve: Curves.easeOutBack),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: big ? 760 : size.width - 32,
                  maxHeight: size.height * 0.8,
                ),
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColorScheme.accent.withValues(alpha: 0.6), width: 2),
                    boxShadow: const [BoxShadow(blurRadius: 40, color: Colors.black54)],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Flexible(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(28, big ? 28 : 22, 28, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.campaign_outlined, color: AppColorScheme.accent, size: big ? 34 : 28),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: TextStyle(
                                        fontSize: big ? 26 : 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppColorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                widget.text,
                                style: TextStyle(
                                  fontSize: big ? 22 : 17,
                                  height: 1.4,
                                  color: AppColorScheme.onSurface.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 12, 28, 20),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            focusNode: _buttonFocus,
                            onPressed: _close,
                            style: ButtonStyle(
                              padding: const WidgetStatePropertyAll(
                                EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                              ),
                              side: WidgetStateProperty.resolveWith(
                                (states) => states.contains(WidgetState.focused)
                                    ? BorderSide(color: AppColorScheme.onSurface, width: 3)
                                    : BorderSide.none,
                              ),
                            ),
                            child: Text(s.gotIt, style: TextStyle(fontSize: big ? 18 : 16)),
                          ),
                        ),
                      ),
                      if (_countdown != null)
                        AnimatedBuilder(
                          animation: _countdown!,
                          builder: (_, _) => LinearProgressIndicator(
                            value: 1 - _countdown!.value,
                            minHeight: 4,
                            color: AppColorScheme.accent,
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
