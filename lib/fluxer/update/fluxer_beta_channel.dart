// FluxerPlayer: «Recibir versiones beta» y comparación de versiones
// (1.2.0-beta.1 < 1.2.0-beta.2 < 1.2.0).

import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';

import '../../preference/user_preferences.dart';

class FluxerBetaChannel {
  FluxerBetaChannel._();

  static final _pref = Preference<bool>(key: 'fluxer_beta_updates', defaultValue: false);

  static UserPreferences? get _prefs =>
      GetIt.instance.isRegistered<UserPreferences>() ? GetIt.instance<UserPreferences>() : null;

  static bool get enabled => _prefs?.get(_pref) ?? false;

  static Future<void> setEnabled(bool value) async => _prefs?.set(_pref, value);
}

/// Negativo si [a] es anterior a [b], 0 si son iguales, positivo si es
/// posterior. Acepta «v» delante y descarta «+compilación».
int fluxerCompareVersions(String a, String b) {
  final (coreA, preA) = _split(a);
  final (coreB, preB) = _split(b);
  for (var i = 0; i < 3; i++) {
    final d = coreA[i].compareTo(coreB[i]);
    if (d != 0) return d;
  }
  // Sin sufijo es la estable: va después de cualquier beta suya.
  if (preA.isEmpty || preB.isEmpty) {
    return (preA.isEmpty ? 1 : 0) - (preB.isEmpty ? 1 : 0);
  }
  final n = preA.length < preB.length ? preA.length : preB.length;
  for (var i = 0; i < n; i++) {
    final x = preA[i];
    final y = preB[i];
    final xi = int.tryParse(x);
    final yi = int.tryParse(y);
    final d = xi != null && yi != null
        ? xi.compareTo(yi)
        : xi != null
            ? -1
            : yi != null
                ? 1
                : x.compareTo(y);
    if (d != 0) return d;
  }
  return preA.length.compareTo(preB.length);
}

(List<int>, List<String>) _split(String raw) {
  var v = raw.trim();
  if (v.startsWith('v') || v.startsWith('V')) v = v.substring(1);
  v = v.split('+').first;
  final dash = v.indexOf('-');
  final core = dash < 0 ? v : v.substring(0, dash);
  final pre = dash < 0 ? '' : v.substring(dash + 1);
  final nums = core
      .split('.')
      .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList();
  while (nums.length < 3) {
    nums.add(0);
  }
  return (nums, pre.isEmpty ? const <String>[] : pre.split('.'));
}
