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
  String get serverMessageTitle => _t('Mensaje de Fluxer', 'Message from Fluxer');
  String get gotIt => _t('Entendido', 'Got it');
  String serverUnreachable(String name) => _t(
        'Acceso aceptado, pero no se ha podido conectar con $name. Inténtalo de nuevo.',
        'Access granted, but $name could not be reached. Please try again.',
      );
}
