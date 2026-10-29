import 'package:flutter_test/flutter_test.dart';
import 'package:foodiehub/utils/password_policy.dart';

void main() {
  test('rejects passwords that do not meet every strength requirement', () {
    expect(PasswordPolicy.isStrong('Abcdef1!'), isTrue);
    expect(PasswordPolicy.isStrong('abcdef1!'), isFalse);
    expect(PasswordPolicy.isStrong('Abcdefgh!'), isFalse);
    expect(PasswordPolicy.isStrong('Abcdef12'), isFalse);
    expect(PasswordPolicy.isStrong('Ab1!'), isFalse);
  });

  test('scores password strength by the number of met requirements', () {
    expect(PasswordPolicy.strengthScore(''), 0);
    expect(PasswordPolicy.strengthScore('weak'), 1);
    expect(PasswordPolicy.strengthScore('Weakpass'), 3);
    expect(PasswordPolicy.strengthScore('StrongPass1!'), 5);
  });
}
