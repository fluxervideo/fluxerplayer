// FluxerPlayer: Textos propios (español / inglés).

import 'package:flutter/widgets.dart';

class FluxerStrings {
  FluxerStrings._(this._es);

  final bool _es;

  static FluxerStrings of(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    return FluxerStrings._(locale?.languageCode == 'es');
  }

  static FluxerStrings forLanguage(String languageCode) => FluxerStrings._(languageCode.startsWith('es'));

  String _t(String es, String en) => _es ? es : en;

  String get signInWithFluxer => _t('Entrar con Fluxer', 'Sign in with Fluxer');
  String get signInWithFluxerSubtitle => _t(
        'Con tu cuenta de Fluxer: un código o la web, sin contraseñas',
        'With your Fluxer account: a code or the web, no passwords',
      );
  String get continueWithFluxer => _t('Continuar con Fluxer', 'Continue with Fluxer');
  String continueWithFluxerSubtitle(String server) =>
      _t('$server · con tu cuenta de Fluxer', '$server · with your Fluxer account');
  String get addOtherServer => _t('Añadir otro servidor', 'Add another server');
  String get orWithPassword => _t('o con contraseña', 'or with a password');
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
        'lang_missing' => _t('Falta el audio o los subtítulos en mi idioma', 'Audio or subtitles in my language are missing'),
        'wrong_item' => _t('No es el capítulo o la película que dice', 'It is not the episode or movie it says'),
        _ => _t('Otra cosa', 'Something else'),
      };
  /// Comentario para el Hub de las opciones que no tiene (en español).
  static String? reportCommentFor(String key) => switch (key) {
        'lang_missing' => 'Falta el audio o los subtítulos en mi idioma',
        'wrong_item' => 'No es el capítulo o la película que dice',
        _ => null,
      };
  String get reportOtherTitle => _t('Cuéntanos qué pasa', 'Tell us what happens');
  String get reportOtherHint => _t('Escribe aquí el problema', 'Describe the problem here');
  String sidebarUpdateTitle(String version) => _t('Versión $version disponible', 'Version $version available');
  String get sidebarUpdateAction => _t('Pulsa para actualizar', 'Press to update');
  String basedOnMoonfin(String moonfin) => _t('Basada en Moonfin $moonfin', 'Based on Moonfin $moonfin');
  String updateToVersion(String version) => _t('Actualizar a la versión $version', 'Update to version $version');
  String get updateToVersionSubtitle => _t('Descargar e instalar la versión nueva', 'Download and install the new version');
  String get checkUpdatesSubtitle => _t('Comprobar si hay una versión nueva', 'Check whether a new version is out');
  String versionWithBase(String version, String moonfin) =>
      _t('$version · basada en Moonfin $moonfin', '$version · based on Moonfin $moonfin');
  // Mi cuenta Fluxer
  String get fluxerAccount => _t('Mi cuenta Fluxer', 'My Fluxer account');
  String get fluxerAccountSubtitle =>
      _t('Plan, saldo, invitar y diagnóstico', 'Plan, balance, invite and diagnostics');
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
  String balanceLine(double v) => _t('Saldo: ${v.toStringAsFixed(2)} €', 'Balance: €${v.toStringAsFixed(2)}');
  String get availableBalance => _t('Saldo disponible', 'Available balance');
  String money(double v) => _t('${v.toStringAsFixed(2).replaceAll('.', ',')} €', '€${v.toStringAsFixed(2)}');
  String balance(double v) => _t('saldo ${v.toStringAsFixed(2)} €', 'balance €${v.toStringAsFixed(2)}');
  String get renewInBrowser => _t('Abre los planes en el navegador', 'Opens the plans in your browser');
  String get renewOnPhone => _t('Escanea el código con el móvil para renovar', 'Scan the code with your phone to renew');
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
        'Mandaremos el registro de la app a Fluxer para ver qué ha pasado.',
        'We will send the app log to Fluxer to see what happened.',
      );
  String get attachDiagnostic => _t('Adjuntar el diagnóstico de la app', 'Attach the app diagnostics');
  String get fluxerSessionSection => _t('Sesión', 'Session');
  String get fluxerLogout => _t('Cerrar sesión en este aparato', 'Sign out of this device');
  String get fluxerLogoutHelp => _t(
        'Sale de tu cuenta y desvincula la app. Para volver a entrar tendrás que aceptar un código nuevo en tu cuenta de Fluxer. Úsalo si el aparato no es tuyo o lo vas a dejar.',
        'Signs you out and unlinks the app. To get back in you will need to accept a new code in your Fluxer account. Use it if the device is not yours or you are leaving it.',
      );

  // Incidencias del servidor
  String serverIncident(String name) => _t(
        'Estamos teniendo problemas con $name. Ya lo estamos arreglando: si algo no carga, inténtalo en un rato.',
        'We are having problems with $name. We are already fixing it: if something does not load, try again shortly.',
      );
  String get serverIncidentTitle => _t('Incidencia en tu servidor', 'Problem with your server');

  String get setByFluxer => _t('la fija Fluxer', 'set by Fluxer');
  String get continueWithMyAccount =>
      _t('Continuar con mi cuenta de Fluxer', 'Continue with my Fluxer account');
  String get orOtherAccount =>
      _t('o entra con otra cuenta con este código:', 'or sign in with another account using this code:');
  String get sessionFailed => _t(
        'No se ha podido abrir la sesión. Inténtalo de nuevo.',
        'Could not open the session. Please try again.',
      );
  String get hubSessionFailed => _t(
        'No se ha podido entrar con tu cuenta. Usa el código para volver a vincular la app.',
        'Could not sign in with your account. Use the code to link the app again.',
      );
  String inviteCode(String code) => _t('Tu código de invitación: $code', 'Your invite code: $code');
  String get inviteTapToCopy => _t('Pulsa para copiar el enlace.', 'Tap to copy the link.');
  String get inviteTapForQr => _t('Pulsa para ver el código QR.', 'Tap to see the QR code.');
  String get inviteCopied => _t('Enlace de invitación copiado', 'Invite link copied');
  String get portalLinkHint => _t(
        'Entrarás ya con tu cuenta. El código vale 10 minutos.',
        'You will be signed in already. The code is valid for 10 minutes.',
      );
  String get renewInBrowserSignedIn =>
      _t('Abre tu cuenta de Fluxer, ya con la sesión iniciada', 'Opens your Fluxer account, already signed in');
  String get yourSubscription => _t('TU SUSCRIPCIÓN', 'YOUR SUBSCRIPTION');
  String get subscriptionActive => _t('Activa', 'Active');
  String subscriptionEndsInDays(int days) => days <= 0
      ? _t('Caduca hoy', 'Ends today')
      : days == 1
          ? _t('Caduca mañana', 'Ends tomorrow')
          : _t('Caduca en $days días', 'Ends in $days days');
  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String renewsOn(DateTime d) => _t('Se renueva el ${_date(d)}', 'Renews on ${_date(d)}');
  String endsOn(DateTime d) => _t('Caduca el ${_date(d)}', 'Ends on ${_date(d)}');
  String get autoRenewYes => _t('Renovación automática', 'Auto-renew on');
  String get autoRenewNo => _t('Sin renovación automática', 'Auto-renew off');
  String get myAccount => _t('Mi cuenta', 'My account');
  String get choosePlan => _t('Elegir plan', 'Choose a plan');
  String get changePlan => _t('Cambiar plan', 'Change plan');
  String renewalPrice(double v) => _t('Renovación: ${money(v)}', 'Renewal: ${money(v)}');
  String topUpBefore(DateTime d, double missing) => _t(
        'Recarga ${money(missing)} antes del ${_date(d)}',
        'Top up ${money(missing)} before ${_date(d)}',
      );
  String get trialNotice => _t(
        'Estás en la prueba gratis. Para seguir cuando acabe, recarga saldo y elige un plan.',
        'You are on the free trial. To keep watching after it ends, top up your balance and choose a plan.',
      );
  String get noPlanNotice => _t(
        'No tienes un plan activo. Recarga saldo y elige un plan para seguir viendo.',
        'You have no active plan. Top up your balance and choose a plan to keep watching.',
      );
  // Pantalla de entrar
  String get loginTitle => _t('Inicia sesión en Fluxer', 'Sign in to Fluxer');
  String get loginSubtitle => _t('Elige una opción para entrar', 'Choose how to sign in');
  String get relinkTitle => _t('Vuelve a entrar con Fluxer', 'Sign in with Fluxer again');
  String relinkSubtitle(String user) => _t(
        'Para seguir como $user, entra otra vez con tu cuenta de Fluxer',
        'To keep watching as $user, sign in with your Fluxer account again',
      );
  String get relinkSwitchUser => _t('Cambiar de usuario', 'Switch user');
  String get relinkSignOut => _t('Cerrar sesión', 'Sign out');
  String get autoLoginTitle => _t('Al abrir la app', 'When the app opens');
  String get autoLoginLastUser => _t('Entrar con el último usuario', 'Continue as the last user');
  String autoLoginUser(String name) => _t('Entrar como $name', 'Continue as $name');
  String get autoLoginThisUser => _t('Entrar con este usuario', 'Continue as this user');
  String get autoLoginAsk => _t('Preguntar quién va a ver', 'Ask who is watching');
  String get whoIsWatching => _t('¿Quién va a ver?', 'Who is watching?');
  String get addUser => _t('Añadir usuario', 'Add user');
  String get removeUser => _t('Quitar este usuario', 'Remove this user');
  String removeUserConfirm(String name) => _t(
        '$name dejará de estar en este aparato. Para volver tendrá que entrar con su cuenta de Fluxer.',
        '$name will be removed from this device. Signing in with their Fluxer account brings them back.',
      );
  String get remove => _t('Quitar', 'Remove');
  String enterAs(String name) => _t('Entrar como $name', 'Continue as $name');
  String get or => _t('o', 'or');
  String get optionThisDevice => _t('En este aparato', 'On this device');
  String get optionThisDeviceHelp => _t(
        'Se abrirá la web de Fluxer en tu navegador. Entra con tu cuenta y pulsa «Dar acceso a la app».',
        'The Fluxer website will open in your browser. Sign in and tap “Give the app access”.',
      );
  String get optionWithPhone => _t('Con tu móvil', 'With your phone');
  String get optionWithPhoneTv => _t('Entra con tu móvil', 'Sign in with your phone');
  String get optionOtherDevice => _t('Desde otro aparato', 'From another device');
  String get scanQr => _t('o escanea con la cámara', 'or scan with the camera');
  String get codeCopied => _t('Código copiado', 'Code copied');
  String get tapToCopy => _t('Toca para copiar', 'Tap to copy');
  String get openLinkFailed => _t('No se ha podido abrir el navegador', 'Could not open the browser');
  String get serverMessageTitle => _t('Mensaje de Fluxer', 'Message from Fluxer');
  String get gotIt => _t('Entendido', 'Got it');
  String serverUnreachable(String name) => _t(
        'Acceso aceptado, pero no se ha podido conectar con $name. Inténtalo de nuevo.',
        'Access granted, but $name could not be reached. Please try again.',
      );

  // Test de velocidad (Mi cuenta Fluxer).
  String get speedTest => _t('Test de velocidad', 'Speed test');
  String get speedTestSection => _t('Conexión', 'Connection');
  String get speedTestSubtitle => _t(
        'Comprueba si a este aparato le llega bien lo que ves',
        'Check whether this device gets what you watch smoothly',
      );
  String get speedTestIntro => _t(
        'Elige algo que hayas visto: se descarga un trozo de ese mismo archivo desde tu servidor y te decimos si a este aparato le llega de sobra, justo o no le llega. Tarda unos 15 segundos.',
        'Pick something you watched: a piece of that same file is downloaded from your server and we tell you whether this device gets it with room to spare, just enough or not enough. Takes about 15 seconds.',
      );
  String speedTestPick(int days) => _t('Lo que has visto estos $days días', 'What you watched in the last $days days');
  String get speedTestSample => _t('Probar con el vídeo de prueba', 'Test with the sample video');
  String get speedTestUnavailable =>
      _t('El test de velocidad no está disponible ahora mismo.', 'The speed test is not available right now.');
  String get speedTestLatency => _t('Midiendo la respuesta del servidor…', 'Measuring server response…');
  String get speedTestDownloading => _t('Descargando de tu servidor…', 'Downloading from your server…');
  String get speedTestSending => _t('Calculando el resultado…', 'Working out the result…');
  String get speedTestDontLeave => _t('No salgas de esta pantalla', 'Stay on this screen');
  String get speedTestAgain => _t('Hacer otra prueba', 'Run another test');
  String get speedTestFailed => _t('No se ha podido medir', 'Could not measure');
  String get speedTestDone => _t('Prueba hecha', 'Test done');
  String get verdictPlenty => _t('Te llega de sobra', 'Plenty of speed');
  String get verdictPlentyHelp => _t(
        'Este aparato recibe el vídeo con margen: se debería ver sin cortes.',
        'This device receives the video with room to spare: it should play without stalls.',
      );
  String get verdictTight => _t('Te llega justo', 'Just enough');
  String get verdictTightHelp => _t(
        'Puede pararse a ratos en las escenas con más movimiento. Si puedes, conecta el aparato por cable o acércalo al router.',
        'It may stall now and then in busy scenes. If you can, use a cable or move closer to the router.',
      );
  String get verdictInsufficient => _t('No te llega', 'Not enough');
  String get verdictInsufficientHelp => _t(
        'Tu conexión en este aparato no llega a lo que pide este archivo: se parará a menudo. Prueba por cable, acércate al router o revisa tu conexión. Si sigue igual, escríbenos desde Soporte.',
        'Your connection on this device is below what this file needs: it will stall often. Try a cable, move closer to the router or check your connection. If it persists, contact Support.',
      );
  String get speedAverage => _t('Velocidad media', 'Average speed');
  String speedNeeded(String? quality) =>
      quality == null ? _t('Lo que pide el archivo', 'What the file needs') : _t('Lo que pide el archivo ($quality)', 'What the file needs ($quality)');
  String get speedMinMax => _t('Mínima / máxima', 'Min / max');
  String get speedLatency => _t('Respuesta del servidor', 'Server response');
  String get speedServer => _t('Lo que da tu servidor ahora', 'What your server gives now');

  // Recargar saldo (fluxer_recharge_screen.dart), con los textos del portal.
  String get recharge => _t('Recargar saldo', 'Top up balance');
  String get paymentsSection => _t('Saldo', 'Balance');
  String get rechargeSubtitle => _t('PayPal o Bizum, con un código en el concepto', 'PayPal or Bizum, with a code in the reference');
  String get rechargeUnavailable =>
      _t('No se puede recargar desde la app ahora mismo. Inténtalo en un rato.', 'Topping up from the app is not available right now. Try again later.');
  String get rechargeIntro => _t(
        'Elige cómo vas a pagar y te daremos los datos y un código, que tendrás que poner como concepto o asunto del pago. El pago lo haces tú desde la app de tu banco (Bizum) o desde PayPal; en cuanto llegue con ese código, el saldo se suma solo.',
        'Choose how you will pay and we will give you the details and a code to put as the payment reference. You make the payment yourself from your bank app (Bizum) or PayPal; as soon as it arrives with that code, the balance is added automatically.',
      );
  String get rechargeNoMethods => _t('No hay ningún método de pago disponible ahora mismo.', 'No payment method is available right now.');
  String get rechargeHowMuch => _t('¿Cuánto quieres recargar?', 'How much do you want to top up?');
  String get otherAmount => _t('Otra cantidad', 'Other amount');
  String get amountEuros => _t('Importe', 'Amount');
  String sendTo(String? method) => _t('Envía a${method == null ? '' : ' ($method)'}:', 'Send to${method == null ? '' : ' ($method)'}:');
  String sendAmountTo(double amount, String? method) => _t(
        'Envía ${amount.toStringAsFixed(2)} € a${method == null ? '' : ' ($method)'}:',
        'Send €${amount.toStringAsFixed(2)} to${method == null ? '' : ' ($method)'}:',
      );
  String get putThisConcept =>
      _t('Pon este número como concepto o asunto del pago:', 'Put this number as the payment reference:');
  String get conceptWhy => _t('Así sabremos que el ingreso es tuyo.', 'That is how we know the payment is yours.');
  String get rechargePaid => _t('He pagado o voy a pagar ahora', 'I have paid or am paying now');
  String get rechargeSelfPay => _t(
        'La app no cobra nada: el pago lo haces tú desde PayPal o tu banco.',
        'The app does not charge anything: you pay from PayPal or your bank.',
      );
  String get rechargeWaiting => _t('Esperando a que llegue tu pago…', 'Waiting for your payment…');
  String get rechargeWaitingHelp => _t(
        'Si pones bien el código, suele llegar en un momento. Lo comprobamos solos: puedes dejar esta pantalla abierta o salir, el saldo se sumará igual.',
        'With the right code it usually arrives in a moment. We check by ourselves: you can keep this screen open or leave, the balance will be added anyway.',
      );
  String get rechargeLate => _t(
        'Aún no nos ha llegado tu pago. Si ya lo has hecho, escríbenos por Telegram y lo miramos.',
        'Your payment has not arrived yet. If you have already paid, message us on Telegram and we will check.',
      );
  String get rechargeRejected => _t(
        'No hemos podido confirmar esta recarga. Escríbenos por Telegram y lo miramos.',
        'We could not confirm this top-up. Message us on Telegram and we will check.',
      );
  String get supportTelegram => _t('Soporte por Telegram', 'Telegram support');
  String get supportTelegramHelp => _t('Se abre el chat con Fluxer', 'Opens the chat with Fluxer');
  String get supportTelegramTv => _t('Escanea el QR con el móvil', 'Scan the QR with your phone');
  String get rechargeLeave => _t('Salir', 'Leave');
  String get rechargeLeaveHelp => _t('El saldo se sumará igual cuando llegue', 'The balance will be added when it arrives');
  String get rechargeDone => _t('¡Recarga recibida!', 'Top-up received!');
  String rechargeDoneAmount(double v) =>
      _t('¡Recibidos ${v.toStringAsFixed(2)} €!', '€${v.toStringAsFixed(2)} received!');
  String get rechargeDoneHelp => _t(
        'Ya está en tu saldo. Si tu plan se renueva solo, se cobrará de ahí.',
        'It is in your balance. If your plan renews automatically, it will be charged from there.',
      );
  String get retry => _t('Reintentar', 'Retry');

  // Actualizar desde la app en Android (update/fluxer_android_update.dart).
  String updateDownloading(String version) => _t('Descargando FluxerPlayer $version', 'Downloading FluxerPlayer $version');
  String get updatePreparing => _t('Preparando la descarga…', 'Preparing the download…');
  String get updateInstalling => _t('Preparando la instalación…', 'Preparing the installation…');
  String get updateInstallHint => _t(
        'Al terminar, si Android lo pide, pulsa «Actualizar». La primera vez te pedirá permitir que FluxerPlayer instale apps. La app se cerrará para actualizarse.',
        'When it finishes, tap “Update” if Android asks. The first time it will ask you to allow FluxerPlayer to install apps. The app will close to update.',
      );
  String get updateFailed => _t(
        'No se ha podido descargar o abrir la actualización. Inténtalo de nuevo en un rato.',
        'Could not download or open the update. Please try again later.',
      );
  String get cancel => _t('Cancelar', 'Cancel');

  // Pantalla de actualizar al abrir la app (update/fluxer_update_gate.dart).
  String get updateScreenTitle => _t('Hay una versión nueva', 'A new version is available');
  String updateScreenBody(String version) => _t(
        'FluxerPlayer $version ya está disponible. Actualiza para tener las últimas mejoras.',
        'FluxerPlayer $version is available. Update to get the latest improvements.',
      );
  String get updateNow => _t('Actualizar', 'Update');
  String get autoUpdate => _t('Instalar actualizaciones automáticamente', 'Install updates automatically');
  String get autoUpdateSubtitle => _t(
        'Al abrir la app, si hay versión nueva se instala sin preguntar',
        'When the app opens, a new version installs without asking',
      );
  String get betaUpdates => _t('Recibir versiones beta', 'Get beta versions');
  String get betaUpdatesSubtitle => _t(
        'Novedades antes que nadie; pueden tener fallos',
        'New features first; they may have bugs',
      );
}
