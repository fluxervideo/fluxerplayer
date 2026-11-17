// FluxerPlayer: rutas propias. Se enganchan en lib/ui/navigation/app_router.dart
// (líneas marcadas `// FLUXER:`).

import 'package:go_router/go_router.dart';

import 'app_login/fluxer_login_screen.dart';

/// Pantalla "Entrar con Fluxer" (código de un solo uso aceptado en el Hub).
const String fluxerLoginPath = '/fluxer-login';

final GoRoute fluxerLoginRoute = GoRoute(
  path: fluxerLoginPath,
  builder: (context, state) => const FluxerLoginScreen(),
);
