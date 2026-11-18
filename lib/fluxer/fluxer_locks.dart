// FluxerPlayer: opciones que Fluxer fija cuando se entra con una cuenta de
// Fluxer. En esas cuentas valen siempre lo que pone aquí y no se pueden
// cambiar en Ajustes; con cualquier otra cuenta, funcionan como en Moonfin.
//
// Enganches (`// FLUXER:`):
// - lib/preference/user_preferences.dart → get(): devuelve el valor fijado.
// - lib/ui/widgets/navigation_layout.dart → sanitizeNavbarPosition().
// - Ajustes: la opción sale como «fijada por Fluxer» (navigation_category_screen)
//   o no sale (quality_decoding_screen: tasa de bits, TV en vivo directo).
//
// Para fijar otra opción: añadir su clave y su valor a [_locked].

import '../preference/preference_constants.dart';
import '../preference/user_preferences.dart';
import 'hub/fluxer_servers.dart';

/// clave de la preferencia de Moonfin → valor que fija Fluxer.
final Map<String, Object> _locked = {
  // Navegación: siempre la barra lateral izquierda.
  'pref_navbar_position': NavbarPosition.left,
  // Calidad: tasa de bits máxima siempre la más alta (Moonfin trae 120 Mbps
  // por defecto). La opción no sale en Ajustes.
  'pref_max_bitrate': '200',
  // TV en vivo: reproducción directa desactivada (lo de Moonfin por defecto).
  // La opción no sale en Ajustes.
  'pref_live_direct': false,
  // Barra de medios de inicio: siempre activa, con el estilo por defecto de
  // cada aparato (grande en ordenador/tele, galería en el móvil) y con
  // «Tendencias de hoy» (fluxer_media_bar.dart). Su sección no sale en Ajustes:
  // lo que se ve lo manda la configuración del servidor (Home Screen Companion).
  'mediaBarEnabled': true,
  'mediaBarMode': UserPreferences.mediaBarMode.defaultValue,
};

/// El valor fijado para [key] si la sesión activa es de Fluxer; si no, null.
Object? fluxerLockedValue(String key) {
  final value = _locked[key];
  if (value == null) return null;
  return FluxerServers.activeIsFluxer ? value : null;
}

/// Secciones de Ajustes que no salen en cuentas de Fluxer (las manda el
/// servidor). Buscador de ajustes: por el prefijo de su id.
bool fluxerHidesSettingsSection(String slug) =>
    FluxerServers.activeIsFluxer && const {'media-bar'}.contains(slug);

/// ¿Está fijada esta opción ahora mismo (cuenta de Fluxer)?
bool fluxerIsLocked(String key) => fluxerLockedValue(key) != null;
