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
  // Mi cuenta Fluxer
  String get fluxerAccount => _t('Mi cuenta Fluxer', 'My Fluxer account');
  String get fluxerAccountSubtitle =>
      _t('Plan, renovar, invitar y diagnóstico', 'Plan, renew, invite and diagnostics');
  String get fluxerAccountUnlinked => _t(
        'Esta app no está vinculada a tu cuenta de Fluxer. Vincúlala con «Entrar con Fluxer» para ver tu plan, renovarlo y recibir avisos.',
        'This app is not linked to your Fluxer account. Link it with “Sign in with Fluxer” to see and renew your plan and get notices.',
      );
  String get fluxerPlanSection => _t('Tu plan', 'Your plan');
  String get noPlan => _t('Sin plan', 'No plan');
  String planEndsOn(DateTime d) => _t(
        'hasta el ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}',
        'until ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}',
      );
  String get autoRenewOn => _t('renovación automática', 'auto-renew');
  String balance(double v) => _t('saldo ${v.toStringAsFixed(2)} €', 'balance €${v.toStringAsFixed(2)}');
  String get renewInBrowser => _t('Abre los planes en el navegador', 'Opens the plans in your browser');
  String get renewOnPhone => _t('Escanea un código con el móvil para renovar', 'Scan a code with your phone to renew');
  String get scanWithPhone => _t('Escanéalo con la cámara del móvil:', 'Scan it with your phone camera:');
  String get inviteSection => _t('Invita y gana', 'Invite and earn');
  String get inviteTitle => _t('Tu enlace de invitación', 'Your invite link');
  String inviteHelp(num? reward) => reward != null && reward > 0
      ? _t('Por cada amigo que se apunte ganas ${reward.toStringAsFixed(2)} € de saldo.',
          'Earn €${reward.toStringAsFixed(2)} credit for every friend who joins.')
      : _t('Compártelo con tus amigos.', 'Share it with your friends.');
  String get copyInviteLink => _t('Copiar el enlace', 'Copy the link');
  String get copied => _t('Copiado', 'Copied');
  String get diagnosticSection => _t('Diagnóstico', 'Diagnostics');
  String get recordDiagnostic => _t('Grabar diagnóstico', 'Record diagnostics');
  String get recordDiagnosticHelp => _t(
        'Actívalo, reproduce el fallo y luego envíanoslo. Gasta algo más de memoria: apágalo cuando acabes.',
        'Turn it on, reproduce the problem, then send it to us. Uses a bit more memory: turn it off afterwards.',
      );
  String get sendDiagnostic => _t('Enviar diagnóstico a Fluxer', 'Send diagnostics to Fluxer');
  String get sendDiagnosticSubtitle =>
      _t('Nos ayuda a encontrar el fallo', 'Helps us find the problem');
  String get sendDiagnosticHelp => _t(
        'Mandaremos el registro de la app a Fluxer. Cuéntanos qué pasaba:',
        'We will send the app log to Fluxer. Tell us what was happening:',
      );
  String get attachDiagnostic => _t('Adjuntar el diagnóstico de la app', 'Attach the app diagnostics');
  String get fluxerSessionSection => _t('Sesión', 'Session');
  String get fluxerLogout => _t('Desvincular de Fluxer', 'Unlink from Fluxer');
  String get fluxerLogoutHelp => _t(
        'La app deja de recibir avisos de tu cuenta. Puedes seguir viendo Fluxer y volver a vincularla cuando quieras.',
        'The app stops getting notices from your account. You can keep watching and link it again any time.',
      );

  // Incidencias del servidor
  String serverIncident(String name) => _t(
        'Estamos teniendo problemas con $name. Ya lo estamos arreglando: si algo no carga, inténtalo en un rato.',
        'We are having problems with $name. We are already fixing it: if something does not load, try again shortly.',
      );
  String get serverIncidentTitle => _t('Incidencia en tu servidor', 'Problem with your server');

  String get serverMessageTitle => _t('Mensaje de Fluxer', 'Message from Fluxer');
  String get gotIt => _t('Entendido', 'Got it');
  String serverUnreachable(String name) => _t(
        'Acceso aceptado, pero no se ha podido conectar con $name. Inténtalo de nuevo.',
        'Access granted, but $name could not be reached. Please try again.',
      );
}
