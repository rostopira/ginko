import 'package:models/keys.dart';
import 'package:test/test.dart';

void main() {
  group('Keys', () {
    test('Selection keys works', () {
      expect(Keys.selection('test'), 'selection-test');
    });
  });
}