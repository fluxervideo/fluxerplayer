// FluxerPlayer: textos propios (español / inglés), fuera de los .arb oficiales
// para no tocar las traducciones de Moonfin.

import 'package:flutter/widgets.dart';

class FluxerStrings {
  FluxerStrings._(this._es);

  final bool _es;

  static FluxerStrings of(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    return FluxerStrings._(locale?.languageCode == 'es');
  }

  String _t(String es, String en) => _es ? es : en;

  String get signInWithFluxer => _t('Entrar con Fluxer', 'Sign in with Fluxer');
  String get signInWithFluxerSubtitle => _t(
        'Sin escribir servidor, usuario ni contraseña',
        'No server, username or password to type',
      );
  String get stepOpen => _t('En tu móvil u ordenador, entra en', 'On your phone or computer, go to');
  String get stepCode => _t('Escribe este código', 'Enter this code');
  String get stepAccept => _t(
        'Elige tu cuenta y pulsa «Dar acceso a la app»',
        'Choose your account and tap “Give the app access”',
      );
  String get orScan => _t('O escanea con el móvil', 'Or scan with your phone');
  String get openFluxerAccount =>
      _t('Entrar con mi cuenta de Fluxer', 'Sign in with my Fluxer account');
  String get waiting => _t('Esperando a que lo aceptes…', 'Waiting for you to accept…');
  String get gettingCode => _t('Pidiendo un código…', 'Getting a code…');
  String get connecting => _t('Conectando con tu servidor…', 'Connecting to your server…');
  String get newCode => _t('Pedir otro código', 'Get a new code');
  String get back => _t('Volver', 'Back');
  String get hubUnreachable => _t(
        'No se ha podido contactar con Fluxer. Revisa tu conexión.',
        'Could not reach Fluxer. Check your connection.',
      );
  String get stillTrying =>
      _t('Sin conexión con Fluxer, reintentando…', 'No connection to Fluxer, retrying…');
  String get later => _t('Más tarde', 'Later');
  String get renew => _t('Renovar', 'Renew');
  String get planTitle => _t('Tu plan de Fluxer', 'Your Fluxer plan');
  String planNotActive(String label) => _t(
        'Tu plan está «$label». Renuévalo para seguir viendo Fluxer.',
        'Your plan is “$label”. Renew it to keep watching Fluxer.',
      );
  String planEndsSoon(DateTime endsAt, int days) {
    final date = '${endsAt.day.toString().padLeft(2, '0')}/${endsAt.month.toString().padLeft(2, '0')}';
    if (days <= 1) {
      return _t('Tu plan caduca hoy o mañana ($date). Renuévalo para no quedarte sin Fluxer.',
          'Your plan ends today or tomorrow ($date). Renew it to keep watching.');
    }
    return _t('Tu plan caduca en $days días ($date). Renuévalo para no quedarte sin Fluxer.',
        'Your plan ends in $days days ($date). Renew it to keep watching.');
  }

  String get reportProblem => _t('Reportar un problema', 'Report a problem');
  String get reportWhatHappens => _t('¿Qué pasa?', 'What happens?');
  String get reportCommentHint =>
      _t('Cuéntanos algo más (opcional)', 'Tell us more (optional)');
  String get reportSent => _t('Enviado. Lo revisaremos pronto, gracias.', 'Sent. We will look into it soon, thanks.');
  String get reportFailed =>
      _t('No se ha podido enviar. Inténtalo en un momento.', 'Could not send it. Please try again shortly.');
  String get reportNeedsFluxerLogin => _t(
        'Para reportar desde la app, entra con «Entrar con Fluxer». También puedes escribirnos desde tu cuenta.',
        'To report from the app, use “Sign in with Fluxer”. You can also write to us from your account.',
      );
  String get openSupport => _t('Abrir soporte', 'Open support');
  String get send => _t('Enviar', 'Send');
  String symptom(String key) => switch (key) {
        'wont_start' => _t('No arranca', "Won't start"),
        'buffering' => _t('Se queda cargando', 'Keeps loading'),
        'cuts' => _t('Se corta o se para', 'Cuts out or stops'),
        'bad_quality' => _t('Se ve mal o pixelado', 'Looks bad or pixelated'),
        'audio' => _t('Problemas con el sonido o los subtítulos', 'Sound or subtitle problems'),
        _ => _t('Otra cosa', 'Something else'),
      };
  String versionWithBase(String version, String moonfin) =>
      _t('$version · basada en Moonfin $moonfin', '$version · based on Moonfin $moonfin');
  String get serverMessageTitle => _t('Mensaje de Fluxer', 'Message from Fluxer');
  String get gotIt => _t('Entendido', 'Got it');
  String serverUnreachable(String name) => _t(
        'Acceso aceptado, pero no se ha podido conectar con $name. Inténtalo de nuevo.',
        'Access granted, but $name could not be reached. Please try again.',
      );
}
