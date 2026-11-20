import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:moonfin/auth/repositories/session_repository.dart';
import 'package:moonfin/fluxer/hub/fluxer_hub_client.dart';
import 'package:moonfin/fluxer/hub/fluxer_servers.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Session extends Fake implements SessionRepository {
  @override
  String? activeServerId;
  @override
  String? activeUserId;
}

void main() {
  late _Session session;
  final hub = FluxerHubClient.instance;

  Future<void> setUpWith(Map<String, String> secure) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues(secure);
    SharedPreferences.setMockInitialValues({});
    final store = PreferenceStore();
    await store.init();
    GetIt.instance.registerSingleton<UserPreferences>(UserPreferences(store));
    hub.forgetCachedTokens();
    session = _Session();
    GetIt.instance.registerSingleton<SessionRepository>(session);
  }

  void signIn(String server, String user) {
    session
      ..activeServerId = server
      ..activeUserId = user;
  }

  tearDown(() async {
    signIn('', '');
    session.activeServerId = null;
    session.activeUserId = null;
    await hub.clearToken();
    await GetIt.instance.reset();
  });

  test('each user reads their own token', () async {
    await setUpWith({});
    await FluxerServers.addUser('s', 'a');
    await FluxerServers.addUser('s', 'b');
    await hub.saveToken('token-a', serverId: 's', userId: 'a');

    signIn('s', 'a');
    expect(await hub.token(), 'token-a');
    signIn('s', 'b');
    expect(await hub.token(), isNull);

    await hub.saveToken('token-b', serverId: 's', userId: 'b');
    expect(await hub.token(), 'token-b');
    signIn('s', 'a');
    expect(await hub.token(), 'token-a');
  });

  test('the old shared token goes to the only Fluxer user', () async {
    await setUpWith({'fluxer_hub_app_token': 'old'});
    await FluxerServers.addUser('s1', 'only');
    signIn('s1', 'only');
    expect(await hub.token(), 'old');
  });

  test('with several Fluxer users the old shared token is not guessed', () async {
    await setUpWith({'fluxer_hub_app_token': 'old2'});
    await FluxerServers.addUser('s2', 'a');
    await FluxerServers.addUser('s2', 'b');
    signIn('s2', 'b');
    expect(await hub.token(), isNull);
  });
}
