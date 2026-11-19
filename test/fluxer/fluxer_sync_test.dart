import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/synced_fields.dart';
import 'package:moonfin/fluxer/fluxer_sync.dart';

void main() {
  test('every appearance key is still a field Moonfin syncs', () {
    final keys = {for (final f in syncedFields) f.serverKey};
    expect(keys.containsAll(fluxerSyncedKeys), isTrue,
        reason: 'missing: ${fluxerSyncedKeys.difference(keys)}');
  });

  test('outside a Fluxer session the profile goes up whole', () {
    final profile = {'visualTheme': 'x', 'homeRowsStyle': 'carousel'};
    expect(fluxerFilterProfile(profile), profile);
  });
}
