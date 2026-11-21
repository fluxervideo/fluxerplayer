// FluxerPlayer: Rutas propias.

import 'package:go_router/go_router.dart';

import 'app_login/fluxer_profiles_screen.dart';

/// Entrada: usuarios guardados o "Entrar con Fluxer" (código aceptado en el Hub).
/// Con `?add=1`, el código directamente («Añadir usuario»).
const String fluxerLoginPath = '/fluxer-login';

final GoRoute fluxerLoginRoute = GoRoute(
  path: fluxerLoginPath,
  builder: (context, state) => FluxerStartScreen(adding: state.uri.queryParameters['add'] == '1'),
);
