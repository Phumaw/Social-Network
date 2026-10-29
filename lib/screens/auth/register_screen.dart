import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../utils/password_policy.dart';

class RegisterScreen extends StatefulWidget {
  final AuthService? authService;

  const RegisterScreen({Key? key, this.authService}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  late final _authService = widget.authService ?? AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  int get _passwordStrength =>
      PasswordPolicy.strengthScore(_passwordController.text);

  Color get _passwordStrengthColor {
    if (_passwordStrength == 0) return AppTheme.borderColor;
    return Color.lerp(
      Colors.red.shade700,
      Colors.green.shade700,
      (_passwordStrength - 1) / 4,
    )!;
  }

  String get _passwordStrengthLabel {
    if (_passwordStrength == 0) return 'กรอกรหัสผ่านเพื่อวัดความรัดกุม';
    if (_passwordStrength <= 2) return 'รหัสผ่านรัดกุมน้อย';
    if (_passwordStrength <= 4) return 'รหัสผ่านรัดกุมปานกลาง';
    return 'รหัสผ่านรัดกุมมาก';
  }

  void _handleRegister() async {
    final username = _usernameController.text.trim().toLowerCase();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (username.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอกชื่อผู้ใช้ อีเมล และรหัสผ่านให้ครบถ้วน'),
        ),
      );
      return;
    }

    if (!RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(username)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ชื่อผู้ใช้ต้องมี 3-24 ตัวอักษร ใช้ a-z, 0-9 หรือ _'),
        ),
      );
      return;
    }

    if (!PasswordPolicy.isStrong(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('รหัสผ่านไม่เป็นไปตามข้อกำหนดความปลอดภัย'),
        ),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('รหัสผ่านและการยืนยันรหัสผ่านไม่ตรงกัน')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await _authService.register(
      username: username,
      email: email,
      password: password,
      address: '',
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('สมัครสมาชิกสำเร็จ กรุณาเข้าสู่ระบบ'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? 'เกิดข้อผิดพลาดในการลงทะเบียน',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.authTheme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: AppTheme.authBackground,
        appBar: AppBar(
          title: const Text(
            'สมัครสมาชิก',
            style: TextStyle(
              color: AppTheme.authText,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: AppTheme.authBackground,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppTheme.authText),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      const SocialNetworkMark(size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        'สร้างบัญชี Social Network',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.authText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'กรอกข้อมูลด้านล่างเพื่อเริ่มต้นใช้งาน',
                        style: TextStyle(color: AppTheme.authMuted),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _usernameController,
                        textCapitalization: TextCapitalization.none,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'ชื่อผู้ใช้',
                          hintText: 'ชื่อผู้ใช้ (a-z, 0-9, _)',
                          prefixIcon: Icon(Icons.alternate_email),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'อีเมล',
                          hintText: 'name@example.com',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        autofillHints: const [AutofillHints.newPassword],
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'รหัสผ่าน',
                          hintText: 'รหัสผ่าน',
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'แสดงรหัสผ่าน'
                                : 'ซ่อนรหัสผ่าน',
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Semantics(
                        label: _passwordStrengthLabel,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LinearProgressIndicator(
                              key: const Key('password-strength-bar'),
                              value: _passwordStrength / 5,
                              minHeight: 6,
                              color: _passwordStrengthColor,
                              backgroundColor: AppTheme.borderColor,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _passwordStrengthLabel,
                              style: TextStyle(
                                color: _passwordStrength == 0
                                    ? AppTheme.authMuted
                                    : _passwordStrengthColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: 'ยืนยันรหัสผ่าน',
                          hintText: 'ยืนยันรหัสผ่านอีกครั้ง',
                          suffixIcon: IconButton(
                            tooltip: _obscureConfirmPassword
                                ? 'แสดงรหัสผ่านที่ยืนยัน'
                                : 'ซ่อนรหัสผ่านที่ยืนยัน',
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () => setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentColor,
                            foregroundColor: const Color(0xFF071321),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: const Color(0xFF071321),
                                  ),
                                )
                              : const Text(
                                  'สมัครสมาชิก',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
