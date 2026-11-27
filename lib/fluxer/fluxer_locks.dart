// FluxerPlayer: Opciones fijadas en cuentas de Fluxer.

import 'package:flutter/widgets.dart';

import '../preference/preference_constants.dart';
import '../preference/user_preferences.dart';
import 'home/fluxer_home_layout.dart';
import 'fluxer_strings.dart';
import 'hub/fluxer_servers.dart';
import 'hub/fluxer_settings_pane.dart';

/// clave de la preferencia de Moonfin → valor que fija Fluxer.
final Map<String, Object> _locked = {
  // Navegación: siempre la barra lateral izquierda.
  'pref_navbar_position': NavbarPosition.left,
  // Calidad: tasa de bits máxima siempre la más alta (Moonfin trae 120 Mbps
  // por defecto). La opción no sale en Ajustes.
  'pref_max_bitrate': '200',
  // Resolución máxima: automática (en Fluxer no se transcodifica). La opción
  // no sale en Ajustes.
  'pref_max_video_resolution': MaxVideoResolution.auto,
  // TV en vivo: reproducción directa desactivada (lo de Moonfin por defecto).
  // La opción no sale en Ajustes.
  'pref_live_direct': false,
  // Barra de medios de inicio: siempre activa, con el estilo por defecto de
  // cada aparato (grande en ordenador/tele, galería en el móvil) y con
  // «Tendencias de hoy» (fluxer_media_bar.dart). Su sección no sale en Ajustes:
  // lo que se ve lo manda la configuración del servidor (Home Screen Companion).
  // Sincronización con el plugin de Moonfin siempre activa, pero solo de la
  // apariencia (fluxer_sync.dart): lo demás lo fija FluxerPlayer o se queda en
  // el aparato, y no se mezcla con el Moonfin oficial del mismo usuario.
  'pref_plugin_sync_enabled': true,
  // Filas de inicio: sin unir las de «Lo último en…» por tipo (cambiaría lo
  // que manda Emby). Las demás opciones de filas no salen en Ajustes.
  'pref_merge_recent_rows_by_type': false,
  'mediaBarEnabled': true,
  // Siempre la imagen grande (en el móvil Moonfin pone por defecto «galería»,
  // con carátulas): igual en el móvil que en el ordenador y la tele.
  'mediaBarMode': UserPreferences.mediaBarModeMoonfin,
  // Filas de inicio en carrusel (con panel de detalles) en todos los aparatos.
  'pref_home_rows_style': HomeRowsStyle.carousel,
  // Valoraciones adicionales (IMDb, TMDb… vía MDBList, clave en el plugin):
  // siempre en la ficha. Solo ahí, para no gastar el cupo diario.
  'enableAdditionalRatings': true,
};

/// El valor fijado para [key] si la sesión activa es de Fluxer; si no, null.
Object? fluxerLockedValue(String key) {
  // Filas de inicio: las que manda Emby (fluxer_home_layout.dart).
  if (key == 'home_sections_config') return FluxerHomeLayout.lockedJson;
  final value = _locked[key];
  if (value == null) return null;
  return FluxerServers.activeIsFluxer ? value : null;
}

/// Secciones de Ajustes que no salen en cuentas de Fluxer (las manda el
/// servidor). Buscador de ajustes: por el prefijo de su id.
bool fluxerHidesSettingsSection(String slug) =>
    FluxerServers.activeIsFluxer && const {'media-bar', 'plugin-sync', 'settings-sync', 'home-sections', 'row-options-rows'}.contains(slug);

/// ¿Está fijada esta opción ahora mismo (cuenta de Fluxer)?
bool fluxerIsLocked(String key) => fluxerLockedValue(key) != null;

/// Panel de la derecha de Ajustes en tele y ordenador, en vez de la vista
/// previa: en «Mi cuenta Fluxer», la suscripción. Null: la vista previa.
Widget? fluxerSettingsPane(BuildContext context, String? categoryTitle) =>
    categoryTitle != null && categoryTitle == FluxerStrings.of(context).fluxerAccount
        ? const FluxerSettingsPane()
        : null;
