// FluxerPlayer: Mensajes del servidor (arriba a la derecha) y avisos centrados.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moonfin_design/moonfin_design.dart';

import '../../ui/navigation/app_router.dart';
import '../fluxer_strings.dart';

OverlayEntry? _current;
VoidCallback? _closeCurrent;

OverlayEntry? _toast;

/// Sin TimeoutMs, el aviso se va solo a los 10 s: no coge el foco, así que en
/// la tele no habría cómo cerrarlo.
const _toastDefault = Duration(seconds: 10);

/// Mensaje del servidor: aviso pequeño arriba a la derecha, sin oscurecer ni
/// quitar el foco (no interrumpe el vídeo ni el mando). Devuelve false si no
/// hay dónde enseñarlo (la app aún no tiene pantalla), para que se use la vía
/// de siempre.
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
  if (_toast?.mounted == true) _toast!.remove();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _FluxerToast(
      header: header?.trim() ?? '',
      text: text.trim(),
      duration: ms > 0 ? Duration(milliseconds: ms) : _toastDefault,
      onDismissed: () {
        if (entry.mounted) entry.remove();
        if (identical(_toast, entry)) _toast = null;
      },
    ),
  );
  _toast = entry;
  overlay.insert(entry);
  return true;
}

/// Enseña una tarjeta y espera a que se cierre: true si pulsó la acción.
/// Null (sin esperar) si no hay pantalla donde enseñarla.
Future<bool>? showFluxerCard({
  String? title,
  required String text,
  Duration? duration,
  String? actionLabel,
  IconData icon = Icons.campaign_outlined,
  bool replaceCurrent = false,
}) {
  final context = appRouter.routerDelegate.navigatorKey.currentContext;
  if (context == null || !context.mounted) return null;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return null;

  if (replaceCurrent) _closeCurrent?.call();

  final result = Completer<bool>();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _FluxerCard(
      header: title?.trim() ?? '',
      text: text.trim(),
      duration: duration,
      actionLabel: actionLabel,
      icon: icon,
      register: (close) {
        if (identical(_current, entry)) _closeCurrent = close;
      },
      onDismissed: (acted) {
        if (entry.mounted) entry.remove();
        if (identical(_current, entry)) {
          _current = null;
          _closeCurrent = null;
        }
        if (!result.isCompleted) result.complete(acted);
      },
    ),
  );
  _current = entry;
  overlay.insert(entry);
  return result.future;
}

class _FluxerCard extends StatefulWidget {
  const _FluxerCard({
    required this.header,
    required this.text,
    required this.duration,
    required this.actionLabel,
    required this.icon,
    required this.register,
    required this.onDismissed,
  });

  final String header;
  final String text;
  final Duration? duration;
  final String? actionLabel;
  final IconData icon;
  final void Function(VoidCallback close) register;
  final void Function(bool acted) onDismissed;

  @override
  State<_FluxerCard> createState() => _FluxerCardState();
}

class _FluxerCardState extends State<_FluxerCard> with TickerProviderStateMixin {
  late final AnimationController _appear = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  AnimationController? _countdown;
  final _primaryFocus = FocusNode();
  FocusNode? _previousFocus;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    widget.register(() => _close(false));
    _previousFocus = FocusManager.instance.primaryFocus;
    _appear.forward();
    final duration = widget.duration;
    if (duration != null) {
      _countdown = AnimationController(vsync: this, duration: duration)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) _close(false);
        })
        ..forward();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _primaryFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _appear.dispose();
    _countdown?.dispose();
    _primaryFocus.dispose();
    super.dispose();
  }

  Future<void> _close(bool acted) async {
    if (_closing) return;
    _closing = true;
    _countdown?.stop();
    if (mounted) await _appear.reverse();
    final previous = _previousFocus;
    widget.onDismissed(acted);
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
      _close(false);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  ButtonStyle _style(bool big) => ButtonStyle(
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 28, vertical: 14),
    ),
    side: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.focused)
          ? BorderSide(color: AppColorScheme.onSurface, width: 3)
          : BorderSide.none,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final s = FluxerStrings.of(context);
    final size = MediaQuery.sizeOf(context);
    final big = size.shortestSide >= 600; // tele / ordenador
    final title = widget.header.isNotEmpty ? widget.header : s.serverMessageTitle;
    final hasAction = widget.actionLabel != null;

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
                                  Icon(widget.icon, color: AppColorScheme.accent, size: big ? 34 : 28),
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
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            if (hasAction)
                              OutlinedButton(
                                onPressed: () => _close(false),
                                style: _style(big),
                                child: Text(s.later, style: TextStyle(fontSize: big ? 18 : 16)),
                              ),
                            FilledButton(
                              focusNode: _primaryFocus,
                              onPressed: () => _close(hasAction),
                              style: _style(big),
                              child: Text(
                                widget.actionLabel ?? s.gotIt,
                                style: TextStyle(fontSize: big ? 18 : 16),
                              ),
                            ),
                          ],
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

class _FluxerToast extends StatefulWidget {
  const _FluxerToast({required this.header, required this.text, required this.duration, required this.onDismissed});

  final String header;
  final String text;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_FluxerToast> createState() => _FluxerToastState();
}

class _FluxerToastState extends State<_FluxerToast> with TickerProviderStateMixin {
  late final AnimationController _appear = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..forward();
  late final AnimationController _countdown = AnimationController(vsync: this, duration: widget.duration)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) _close();
    })
    ..forward();
  // La X, con ratón o dedo: no coge el foco del mando.
  final _closeFocus = FocusNode(skipTraversal: true, canRequestFocus: false);
  bool _closing = false;

  @override
  void dispose() {
    _appear.dispose();
    _countdown.dispose();
    _closeFocus.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    _countdown.stop();
    if (mounted) await _appear.reverse();
    widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final s = FluxerStrings.of(context);
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final big = size.shortestSide >= 600; // tele / ordenador
    // «Mensaje» a secas (lo que pone Emby por defecto) → «Mensaje de Fluxer».
    final generic = const {'', 'mensaje', 'message'}.contains(widget.header.toLowerCase());
    final title = generic ? s.serverMessageTitle : widget.header;
    final width = big ? 440.0 : size.width - 24;
    final curve = CurvedAnimation(parent: _appear, curve: Curves.easeOutCubic);

    return Positioned(
      top: padding.top + (big ? 24 : 12),
      right: padding.right + (big ? 24 : 12),
      width: width,
      child: FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: Tween(begin: const Offset(0.08, 0), end: Offset.zero).animate(curve),
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF15191F).withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColorScheme.accent.withValues(alpha: 0.35)),
                boxShadow: const [BoxShadow(blurRadius: 24, color: Colors.black45)],
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Image.asset('assets/icons/app_icon.png', width: big ? 40 : 34, height: big ? 40 : 34),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.white, fontSize: big ? 17 : 15, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.text,
                              maxLines: 6,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: big ? 15 : 14,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _close,
                        focusNode: _closeFocus,
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: AnimatedBuilder(
                        animation: _countdown,
                        builder: (_, _) => LinearProgressIndicator(
                          value: 1 - _countdown.value,
                          minHeight: 4,
                          color: AppColorScheme.accent,
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
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
    );
  }
}
