import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('an unlocked preference read as nullable keeps its saved value', () async {
    SharedPreferences.setMockInitialValues({});
    final store = PreferenceStore();
    await store.init();
    final prefs = UserPreferences(store);
    await prefs.set(UserPreferences.seasonalSurprise, UserPreferences.seasonalLeaves);

    String? read(String? value) => value;
    expect(read(prefs.get(UserPreferences.seasonalSurprise)), UserPreferences.seasonalLeaves);
    expect(
      UserPreferences.normalizeSeasonalSurprise(prefs.get(UserPreferences.seasonalSurprise)),
      UserPreferences.seasonalLeaves,
    );
  });
}
