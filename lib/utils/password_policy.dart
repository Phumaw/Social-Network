class PasswordPolicy {
  static const String requirement =
      'อย่างน้อย 8 ตัวอักษร พร้อมตัวพิมพ์เล็ก ตัวพิมพ์ใหญ่ ตัวเลข และอักขระพิเศษ';

  static int strengthScore(String password) {
    return [
      password.length >= 8,
      RegExp(r'[a-z]').hasMatch(password),
      RegExp(r'[A-Z]').hasMatch(password),
      RegExp(r'\d').hasMatch(password),
      RegExp(r'[^A-Za-z0-9]').hasMatch(password),
    ].where((meetsRequirement) => meetsRequirement).length;
  }

  static bool isStrong(String password) {
    return strengthScore(password) == 5;
  }
}
