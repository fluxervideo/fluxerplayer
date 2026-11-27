// FluxerPlayer: «Instalar actualizaciones automáticamente».

import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';

import '../../preference/user_preferences.dart';

class FluxerAutoUpdate {
  FluxerAutoUpdate._();

  static final _pref = Preference<bool>(key: 'fluxer_auto_update', defaultValue: false);

  static UserPreferences? get _prefs =>
      GetIt.instance.isRegistered<UserPreferences>() ? GetIt.instance<UserPreferences>() : null;

  static bool get enabled => _prefs?.get(_pref) ?? false;

  static Future<void> setEnabled(bool value) async => _prefs?.set(_pref, value);
}
