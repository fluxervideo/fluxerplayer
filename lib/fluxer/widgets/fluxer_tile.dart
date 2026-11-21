// FluxerPlayer: Fila que se maneja bien con el mando de la tele.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moonfin_design/moonfin_design.dart';

import '../../ui/widgets/settings/preference_tiles.dart';
import '../../util/focus/dpad_keys.dart';

class FluxerTile extends StatelessWidget {
  const FluxerTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.autofocus = false,
    this.enabled = true,
    this.focusNode,
  });

  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool autofocus;
  final bool enabled;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final tap = enabled ? onTap : null;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (_, event) {
        if (tap == null || !event.logicalKey.isSelectKey) return KeyEventResult.ignored;
        if (event is KeyDownEvent) tap();
        return KeyEventResult.handled;
      },
      child: TvFocusHighlight(
        enabled: enabled,
        builder: (context, focused) {
          final highlighted = focused && settingsTileInvertsOnFocus;
          final ink = highlighted ? AppColors.black.withValues(alpha: 0.87) : settingsHeadlineColor();
          final soft = highlighted
              ? AppColors.black.withValues(alpha: 0.6)
              : AppColorScheme.onSurface.withValues(alpha: 0.7);
          return ListTile(
            focusNode: focusNode,
            autofocus: autofocus,
            enabled: enabled,
            focusColor: Colors.transparent,
            hoverColor: Colors.transparent,
            iconColor: soft,
            // Igual que las filas de Ajustes de Moonfin (icono en su recuadro).
            leading: leading == null
                ? null
                : leading is Icon
                    ? buildSettingsLeadingIconShell(
                        context,
                        icon: leading!,
                        focused: focused,
                        iconColor: highlighted
                            ? AppColors.black.withValues(alpha: 0.54)
                            : AppColorScheme.onSurface.withValues(alpha: 0.78),
                      )
                    : SizedBox(width: 44, height: 44, child: Center(child: leading)),
            title: DefaultTextStyle.merge(
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ink),
              child: title,
            ),
            subtitle: subtitle == null
                ? null
                : DefaultTextStyle.merge(style: TextStyle(fontSize: 12, color: soft), child: subtitle!),
            trailing: trailing == null && tap != null
                ? Icon(Icons.chevron_right, color: soft)
                : (trailing == null ? null : IconTheme.merge(data: IconThemeData(color: soft), child: trailing!)),
            onTap: tap,
          );
        },
      ),
    );
  }
}

/// En la tele, ↑/↓ salen de un campo de texto (si no, se queda atrapado el
/// foco dentro y no se llega a los botones de debajo).
class FluxerTvTextFieldEscape extends StatelessWidget {
  const FluxerTvTextFieldEscape({super.key, required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (!key.isUpKey && !key.isDownKey) return KeyEventResult.ignored;
        final primary = FocusManager.instance.primaryFocus;
        if (primary == null) return KeyEventResult.ignored;
        primary.focusInDirection(key.isUpKey ? TraversalDirection.up : TraversalDirection.down);
        return KeyEventResult.handled;
      },
      child: child,
    );
  }
}
