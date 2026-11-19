// FluxerPlayer: con el plugin de Moonfin en el servidor, en cuentas de Fluxer
// solo se sincroniza la apariencia. Lo demás lo fija FluxerPlayer o se queda
// en el aparato.

import 'hub/fluxer_servers.dart';

/// Claves del perfil de Moonfin que se leen y se suben.
const fluxerSyncedKeys = <String>{
  'visualTheme',
  'customThemeId',
  'oledMode',
  'focusColor',
  'navbarColor',
  'navbarOpacity',
  'seasonalSurprise',
  'seasonalDensity',
  'seasonalFollower',
};

/// ¿Solo la apariencia? (sesión activa de Fluxer).
bool get fluxerAppearanceOnlySync => FluxerServers.activeIsFluxer;

/// El perfil que se sube, solo con la apariencia. El plugin mezcla lo que
/// recibe con lo guardado, así que el resto del perfil no se toca.
Map<String, dynamic> fluxerFilterProfile(Map<String, dynamic> profile) =>
    fluxerAppearanceOnlySync
        ? {for (final e in profile.entries) if (fluxerSyncedKeys.contains(e.key)) e.key: e.value}
        : profile;
