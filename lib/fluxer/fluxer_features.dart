// FluxerPlayer: Funciones de Moonfin que se muestran en FluxerPlayer.
abstract final class FluxerFeatures {
  /// Solo para clientes de Fluxer: se entra siempre con la cuenta de Fluxer
  /// («Entrar con Fluxer»: código, QR o web). Sin dirección de servidor a
  /// mano ni contraseña de Emby; las pantallas de servidores, contraseña y
  /// «Añadir usuario» de Moonfin llevan a la de Fluxer (fluxerAuthRedirect).
  static const fluxerOnly = true;

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

  /// Lector de libros y cómics, y las opciones de libros de Ajustes.
  static const books = false;

  /// Música: lo que Moonfin enseña solo si el servidor tiene música
  /// (enganche: musicOnAnySignedInServer: filas de audio, letras, ajustes de
  /// filas) y las opciones de música de Ajustes (estilo de la biblioteca,
  /// tiempo en el reproductor de música, salvapantallas con audio).
  static const music = false;

  /// Peticiones por Seerr.
  static const seerr = false;

  /// Descargas (y el modo sin conexión que enseña lo descargado): en Fluxer
  /// no se descarga nada. Enganche: PlatformDetection.supportsOfflineDownloads,
  /// del que dependen el botón de descargar, la sección «Descargas», las
  /// opciones de descarga de Almacenamiento (la caché de imágenes se queda) y
  /// el buscador de ajustes.
  static const downloads = false;

  /// Pantallas de administración del servidor Emby.
  static const serverAdmin = false;

  /// "Acerca de": donar a Moonfin, Discord, reportar un problema en el
  /// GitHub de Moonfin y su política de privacidad. (El código fuente y las
  /// licencias se quedan siempre: los exige la GPL.)
  static const moonfinCommunityLinks = false;

  /// "Acerca de": «Run setup again» (volver a pasar el asistente inicial).
  static const rerunSetup = false;

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

/// Modo solo Fluxer: las pantallas de entrar de Moonfin (elegir servidor,
/// contraseña, usuarios del servidor, Emby Connect, Plex) llevan a la de
/// Fluxer. Enganche: lib/ui/navigation/app_router.dart.
String? fluxerAuthRedirect(String path) {
  if (!FluxerFeatures.fluxerOnly) return null;
  const moonfinSignIn = {'/server-select', '/login', '/server', '/emby-connect', '/plex-sign-in'};
  return moonfinSignIn.contains(path) ? '/fluxer-login' : null;
}
