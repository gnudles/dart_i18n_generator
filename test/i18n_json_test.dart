import 'package:i18n_json/i18n_json.dart';
import 'package:test/test.dart';

void main() {
  test('testSdkVersionForNullSafety', () {
    expect(testSdkVersionForNullSafety("^2.12.0"), true);
    expect(testSdkVersionForNullSafety("^2.10.0"), false);
  });
}
