// FluxerPlayer: qué funciones de Moonfin se ven en la app.
//
// El código de Moonfin NO se borra (así las actualizaciones no dan
// conflictos): solo se ocultan sus puntos de entrada. Cada enganche en un
// fichero oficial lleva `// FLUXER:` y consulta esta clase.
//
// Para volver a enseñar algo: poner su valor a true.
// Decidido con el usuario el 2026-11-17.
abstract final class FluxerFeatures {
  /// Plex, Jellyfin, Silo y Emby Connect: solo Emby de Fluxer.
  static const otherServerTypes = false;

  /// Buscar servidores en la red local.
  static const serverDiscovery = false;

  /// Certificados de cliente y permitir certificados autofirmados.
  static const clientCertificates = false;

  /// Juegos, emuladores (RomM) y el minijuego After Hours.
  static const games = false;

  /// Logros, amigos y chat.
  static const achievements = false;

  /// Lector de libros y cómics.
  static const books = false;

  /// Peticiones por Seerr.
  static const seerr = false;

  /// Pantallas de administración del servidor Emby.
  static const serverAdmin = false;

  /// "Acerca de": donar a Moonfin, Discord, reportar un problema en el
  /// GitHub de Moonfin y su política de privacidad. (El código fuente y las
  /// licencias se quedan siempre: los exige la GPL.)
  static const moonfinCommunityLinks = false;

  /// Notificaciones push de Moonfin (Firebase de Moonfin, para su plugin de
  /// servidor y Seerr). Apagadas: no se registran los aparatos en el Firebase
  /// de Moonfin ni se pide permiso de notificaciones.
  static const moonfinPush = false;
}

/// Red de seguridad del router (lib/ui/navigation/app_router.dart): si algo
/// intenta abrir una pantalla de una función oculta (un enlace, un atajo,
/// una fila de inicio), se vuelve al inicio.
bool fluxerBlockedPath(String path) {
  bool under(String prefix) => path == prefix || path.startsWith('$prefix/');
  if (!FluxerFeatures.games &&
      (under('/games') || under('/game') || under('/game-player') || under('/romm-account'))) {
    return true;
  }
  if (!FluxerFeatures.books && (under('/books') || under('/player/book'))) return true;
  if (!FluxerFeatures.seerr && under('/seerr')) return true;
  return false;
}
