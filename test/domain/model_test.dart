import 'package:flutter_test/flutter_test.dart';

import 'package:yawala_music/domain/model.dart';

void main() {
  group('Track', () {
    test('sample data is not empty', () {
      expect(Track.seedLibrary, isNotEmpty);
    });

    test('matches humanised labels', () {
      for (final item in Track.seedLibrary) {
        expect(item.matches(item.displayName.toLowerCase()), isTrue);
      }
    });
  });
}