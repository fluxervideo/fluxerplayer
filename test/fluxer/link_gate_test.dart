import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:moonfin/auth/repositories/session_repository.dart';
import 'package:moonfin/fluxer/app_login/fluxer_link_gate.dart';
import 'package:moonfin/fluxer/app_login/fluxer_login_screen.dart';
import 'package:moonfin/fluxer/hub/fluxer_hub_client.dart';
import 'package:moonfin/fluxer/hub/fluxer_servers.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Session extends Fake implements SessionRepository {
  final _states = StreamController<SessionState>.broadcast();
  @override
  String? activeServerId;
  @override
  String? activeUserId;
  @override
  Stream<SessionState> get stateStream => _states.stream;
  void open(String server, String user) {
    activeServerId = server;
    activeUserId = user;
    _states.add(SessionState.ready);
  }
}

void main() {
  final hub = FluxerHubClient.instance;

  Future<_Session> setUp(WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final store = PreferenceStore();
    await store.init();
    GetIt.instance.registerSingleton<UserPreferences>(UserPreferences(store));
    hub.forgetCachedTokens();
    final session = _Session();
    GetIt.instance.registerSingleton<SessionRepository>(session);
    await FluxerServers.add('s');
    await FluxerServers.addUser('s', 'a');
    await FluxerServers.addUser('s', 'b');
    await hub.saveToken('token-a', serverId: 's', userId: 'a');
    return session;
  }

  tearDown(() => GetIt.instance.reset());

  testWidgets('a Fluxer user without a Fluxer session has to sign in again', (tester) async {
    final session = await tester.runAsync(() => setUp(tester));
    session!.open('s', 'a');
    await tester.pumpWidget(const MaterialApp(home: FluxerLinkGate(child: Text('home'))));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(find.byType(FluxerLoginScreen), findsNothing);

    session.open('s', 'b');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(find.byType(FluxerLoginScreen), findsOneWidget);

    await tester.runAsync(() => hub.saveToken('token-b', serverId: 's', userId: 'b'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(find.byType(FluxerLoginScreen), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
