// FluxerPlayer: opciones que Fluxer fija cuando se entra con una cuenta de
// Fluxer. En esas cuentas valen siempre lo que pone aquí y no se pueden
// cambiar en Ajustes; con cualquier otra cuenta, funcionan como en Moonfin.
//
// Enganches (`// FLUXER:`):
// - lib/preference/user_preferences.dart → get(): devuelve el valor fijado.
// - lib/ui/widgets/navigation_layout.dart → sanitizeNavbarPosition().
// - Ajustes: la opción sale como «fijada por Fluxer» (navigation_category_screen).
//
// Para fijar otra opción: añadir su clave y su valor a [_locked].

import '../preference/preference_constants.dart';
import 'hub/fluxer_servers.dart';

/// clave de la preferencia de Moonfin → valor que fija Fluxer.
final Map<String, Object> _locked = {
  // Navegación: siempre la barra lateral izquierda.
  'pref_navbar_position': NavbarPosition.left,
};

/// El valor fijado para [key] si la sesión activa es de Fluxer; si no, null.
Object? fluxerLockedValue(String key) {
  final value = _locked[key];
  if (value == null) return null;
  return FluxerServers.activeIsFluxer ? value : null;
}

/// ¿Está fijada esta opción ahora mismo (cuenta de Fluxer)?
bool fluxerIsLocked(String key) => fluxerLockedValue(key) != null;
