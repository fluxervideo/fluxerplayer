import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/fluxer/update/fluxer_beta_channel.dart';

void main() {
  test('orden de versiones con -beta.N', () {
    final ordered = ['1.1.1', '1.2.0-beta.1', '1.2.0-beta.2', 'v1.2.0-beta.10', '1.2.0', '1.2.1-beta.1', '1.10.0'];
    for (var i = 0; i < ordered.length - 1; i++) {
      expect(fluxerCompareVersions(ordered[i], ordered[i + 1]), lessThan(0), reason: '${ordered[i]} < ${ordered[i + 1]}');
      expect(fluxerCompareVersions(ordered[i + 1], ordered[i]), greaterThan(0));
    }
    expect(fluxerCompareVersions('v1.2.0', '1.2.0+77'), 0);
  });
}
