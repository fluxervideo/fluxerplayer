// FluxerPlayer: abajo en la barra lateral, la versión de la app y, si hay una
// nueva (aunque se haya cancelado al abrir), un aviso para actualizar.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:moonfin_design/moonfin_design.dart';
import 'package:server_core/server_core.dart';

import '../../data/services/app_update_service.dart';
import '../../ui/widgets/app_update_dialog.dart';
import '../../util/app_beta.dart';
import '../fluxer_strings.dart';
import '../update/fluxer_update_gate.dart';

class FluxerSidebarVersion extends StatelessWidget {
  const FluxerSidebarVersion({super.key, required this.expanded});

  /// Barra abierta: con la barra cerrada solo queda el icono si hay versión nueva.
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DesktopUpdateInfo?>(
      valueListenable: fluxerKnownUpdate,
      builder: (context, update, _) {
        if (update != null) {
          return _UpdateButton(update: update, expanded: expanded);
        }
        if (!expanded) return const SizedBox.shrink();
        String version;
        try {
          version = AppBeta.label(GetIt.instance<DeviceInfo>().appVersion);
        } catch (_) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: Text(
            'FluxerPlayer $version',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
          ),
        );
      },
    );
  }
}

class _UpdateButton extends StatefulWidget {
  const _UpdateButton({required this.update, required this.expanded});

  final DesktopUpdateInfo update;
  final bool expanded;

  @override
  State<_UpdateButton> createState() => _UpdateButtonState();
}

class _UpdateButtonState extends State<_UpdateButton> {
  bool _focused = false;
  bool _hovered = false;

  void _open() => unawaited(fluxerStartUpdate(context, widget.update));

  @override
  Widget build(BuildContext context) {
    final s = FluxerStrings.of(context);
    final active = _focused || _hovered;
    final accent = AppColorScheme.accent;
    final version = widget.update.version.replaceFirst(RegExp('^[vV]'), '');
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          _open();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _open,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: EdgeInsets.symmetric(horizontal: widget.expanded ? 10 : 6, vertical: 4),
            padding: EdgeInsets.symmetric(horizontal: widget.expanded ? 12 : 8, vertical: 10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: active ? 0.35 : 0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: active ? Colors.white : accent.withValues(alpha: 0.5), width: active ? 2 : 1),
            ),
            child: widget.expanded
                ? Row(
                    children: [
                      Icon(Icons.system_update_alt_rounded, size: 20, color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              s.sidebarUpdateTitle(version),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            Text(
                              s.sidebarUpdateAction,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.75)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : const Center(child: Icon(Icons.system_update_alt_rounded, size: 20, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}
