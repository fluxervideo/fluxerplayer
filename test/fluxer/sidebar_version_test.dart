import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/app_update_service.dart';
import 'package:moonfin/fluxer/update/fluxer_update_gate.dart';
import 'package:moonfin/fluxer/widgets/fluxer_sidebar_version.dart';

void main() {
  tearDown(() => fluxerKnownUpdate.value = null);

  Widget app(bool expanded) => MaterialApp(
    home: Scaffold(body: SizedBox(width: 260, child: FluxerSidebarVersion(expanded: expanded))),
  );

  testWidgets('shows the update notice when a new version is known', (tester) async {
    await tester.pumpWidget(app(true));
    expect(find.byIcon(Icons.system_update_alt_rounded), findsNothing);
    fluxerKnownUpdate.value = DesktopUpdateInfo(
      version: 'v1.0.12',
      downloadUri: Uri.parse('https://example.com/a.apk'),
      releaseNotesUrl: 'https://example.com',
    );
    await tester.pump();
    expect(find.textContaining('1.0.12'), findsOneWidget);
    expect(find.textContaining('v1.0.12'), findsNothing);
  });

  testWidgets('collapsed sidebar keeps only the icon', (tester) async {
    fluxerKnownUpdate.value = DesktopUpdateInfo(
      version: '1.0.12',
      downloadUri: Uri.parse('https://example.com/a.apk'),
      releaseNotesUrl: 'https://example.com',
    );
    await tester.pumpWidget(app(false));
    expect(find.byIcon(Icons.system_update_alt_rounded), findsOneWidget);
    expect(find.textContaining('1.0.12'), findsNothing);
  });
}
