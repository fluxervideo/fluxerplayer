import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/fluxer/update/fluxer_update_gate.dart';

void main() {
  testWidgets('without the update service the gate shows the app as is', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FluxerUpdateGate(child: Text('app'))));
    await tester.pump();
    expect(find.text('app'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
  });
}
