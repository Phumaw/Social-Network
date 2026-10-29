import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/password_policy.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _codeSent = false;
  bool _loading = false;
  bool _obscurePassword = true;

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      _showMessage('กรุณากรอกอีเมลให้ถูกต้อง', isError: true);
      return;
    }
    setState(() => _loading = true);
    final result = await _authService.requestPasswordReset(email);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _codeSent = result['success'] == true;
    });
    _showMessage(
      result['message']?.toString() ?? 'ส่งรหัสยืนยันไม่สำเร็จ',
      isError: result['success'] != true,
    );
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _showMessage('กรุณากรอกรหัสยืนยัน 6 หลักจากอีเมล', isError: true);
      return;
    }
    if (!PasswordPolicy.isStrong(password)) {
      _showMessage(
        'รหัสผ่านใหม่ไม่เป็นไปตามข้อกำหนดความปลอดภัย',
        isError: true,
      );
      return;
    }

    setState(() => _loading = true);
    final result = await _authService.resetPassword(
      email: email,
      code: code,
      password: password,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    _showMessage(
      result['message']?.toString() ?? 'เปลี่ยนรหัสผ่านไม่สำเร็จ',
      isError: result['success'] != true,
    );
    if (result['success'] == true) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.pop(context, true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.authTheme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: AppTheme.authBackground,
        appBar: AppBar(
          title: const Text('ลืมรหัสผ่าน'),
          backgroundColor: AppTheme.authBackground,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.mark_email_read_outlined,
                      color: AppTheme.accentColor,
                      size: 56,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _codeSent ? 'ตั้งรหัสผ่านใหม่' : 'กู้คืนบัญชีของคุณ',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.authText,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _codeSent
                          ? 'กรอกรหัส 6 หลักที่ส่งไปยัง ${_emailController.text.trim()} และตั้งรหัสผ่านใหม่'
                          : 'กรอกอีเมลที่ใช้สมัครสมาชิก เราจะส่งรหัสยืนยันสำหรับเปลี่ยนรหัสผ่านให้',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.authMuted),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _emailController,
                      enabled: !_codeSent && !_loading,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'อีเมลที่สมัคร',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    if (_codeSent) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          labelText: 'รหัสยืนยัน 6 หลัก',
                          prefixIcon: Icon(Icons.password_outlined),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'รหัสผ่านใหม่',
                          helperText: PasswordPolicy.requirement,
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'แสดงรหัสผ่านใหม่'
                                : 'ซ่อนรหัสผ่านใหม่',
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: _loading
                          ? null
                          : _codeSent
                          ? _resetPassword
                          : _sendCode,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.accentColor,
                        foregroundColor: const Color(0xFF071321),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: const Color(0xFF071321),
                              ),
                            )
                          : Text(
                              _codeSent ? 'เปลี่ยนรหัสผ่าน' : 'ส่งรหัสยืนยัน',
                            ),
                    ),
                    if (_codeSent) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loading ? null : _sendCode,
                        child: const Text('ส่งรหัสยืนยันอีกครั้ง'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
