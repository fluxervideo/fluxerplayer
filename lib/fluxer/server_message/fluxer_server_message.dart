// FluxerPlayer: Avisos grandes y centrados.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moonfin_design/moonfin_design.dart';

import '../../ui/navigation/app_router.dart';
import '../fluxer_strings.dart';

OverlayEntry? _current;
VoidCallback? _closeCurrent;

/// Mensaje del servidor. Devuelve false si no hay dónde enseñarlo (la app
/// aún no tiene pantalla), para que se use la vía de siempre.
bool showFluxerServerMessage({
  required String text,
  String? header,
  String? timeoutMs,
}) {
  final ms = int.tryParse(timeoutMs?.trim() ?? '') ?? 0;
  final shown = showFluxerCard(
    title: header,
    text: text,
    duration: ms > 0 ? Duration(milliseconds: ms) : null,
    replaceCurrent: true,
  );
  return shown != null;
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
