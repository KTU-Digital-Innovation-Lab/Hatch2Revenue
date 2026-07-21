import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/farm_profile_provider.dart';
import '../../services/sync_service.dart';
import '../../utils/app_colors.dart';

enum AuthMode { signIn, signUp, confirmSignup, forgot, resetCode }

/// Full-screen sign in / sign up flow for cloud sync.
/// Everything happens in-app: account confirmation and password reset
/// use 8-digit codes from the Hatch2Revenue email, no browser needed.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.initialMode = AuthMode.signIn});

  final AuthMode initialMode;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late AuthMode _mode = widget.initialMode;
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _code.dispose();
    super.dispose();
  }

  void _switch(AuthMode mode, {String? notice}) {
    setState(() {
      _mode = mode;
      _error = null;
      _notice = notice;
      _code.clear();
      if (mode == AuthMode.signIn) {
        _password.clear();
        _confirmPassword.clear();
      }
    });
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('Invalid login credentials')) {
      return 'Wrong email or password.';
    }
    if (s.contains('otp_expired') || s.contains('Token has expired')) {
      return 'That code has expired — request a new one.';
    }
    if (s.contains('invalid') && s.contains('otp')) {
      return 'That code is not correct. Check the email and try again.';
    }
    if (s.contains('already registered')) {
      return 'An account with this email already exists — sign in instead.';
    }
    if (s.contains('SocketException') || s.contains('Failed host lookup')) {
      return 'No internet connection — try again when you are online.';
    }
    return s.replaceFirst('Exception: ', '').replaceFirst('AuthException: ', '');
  }

  Future<void> _run(Future<void> Function() op) async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await op();
    } catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _validEmail() => RegExp(r'^\S+@\S+\.\S+$').hasMatch(_email.text.trim());

  Future<void> _submit() async {
    final sync = context.read<SyncService>();
    switch (_mode) {
      case AuthMode.signIn:
        if (!_validEmail()) return setState(() => _error = 'Enter a valid email.');
        await _run(() async {
          await sync.signIn(_email.text.trim(), _password.text);
          if (mounted) Navigator.pop(context, true);
        });
      case AuthMode.signUp:
        if (_fullName.text.trim().isEmpty) {
          return setState(() => _error = 'Enter your full name.');
        }
        if (!_validEmail()) return setState(() => _error = 'Enter a valid email.');
        if (_password.text.length < 8) {
          return setState(() => _error = 'Password must be at least 8 characters.');
        }
        if (_password.text != _confirmPassword.text) {
          return setState(() => _error = 'Passwords do not match.');
        }
        // Seed the local farm profile with the owner's details.
        final profileProvider = context.read<FarmProfileProvider>();
        final existing = profileProvider.profile;
        profileProvider.save(existing.copyWith(
          ownerName: existing.ownerName.isEmpty
              ? _fullName.text.trim()
              : existing.ownerName,
          phone: existing.phone.isEmpty ? _phone.text.trim() : existing.phone,
          email: existing.email.isEmpty ? _email.text.trim() : existing.email,
        ));
        await _run(() async {
          final needsConfirm = await sync.signUp(
            _email.text.trim(),
            _password.text,
            fullName: _fullName.text.trim(),
            phone: _phone.text.trim(),
          );
          if (!mounted) return;
          if (needsConfirm) {
            _switch(AuthMode.confirmSignup,
                notice: 'We emailed an 8-digit code to ${_email.text.trim()}.');
          } else {
            Navigator.pop(context, true);
          }
        });
      case AuthMode.confirmSignup:
        await _run(() async {
          await sync.verifySignupCode(_email.text.trim(), _code.text.trim());
          if (mounted) Navigator.pop(context, true);
        });
      case AuthMode.forgot:
        if (!_validEmail()) return setState(() => _error = 'Enter a valid email.');
        await _run(() async {
          await sync.requestPasswordReset(_email.text.trim());
          if (mounted) {
            _switch(AuthMode.resetCode,
                notice:
                    'We emailed an 8-digit code to ${_email.text.trim()}. '
                    'Enter it below with your new password.');
          }
        });
      case AuthMode.resetCode:
        if (_password.text.length < 8) {
          return setState(() => _error = 'Password must be at least 8 characters.');
        }
        if (_password.text != _confirmPassword.text) {
          return setState(() => _error = 'Passwords do not match.');
        }
        await _run(() async {
          await sync.resetPasswordWithCode(
            _email.text.trim(),
            _code.text.trim(),
            _password.text,
          );
          if (mounted) Navigator.pop(context, true);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _header(),
                  const SizedBox(height: 28),
                  _card(),
                  const SizedBox(height: 16),
                  _footerLinks(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: AppColors.amber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(12),
          child: Image.asset('assets/chicken.png', fit: BoxFit.contain),
        ),
        const SizedBox(height: 14),
        Text(
          'Hatch2Revenue',
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'SMART POULTRY MANAGEMENT · OFFLINE FIRST',
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 10,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _card() {
    final (title, subtitle) = switch (_mode) {
      AuthMode.signIn => ('Welcome back', 'Sign in to sync your farm records'),
      AuthMode.signUp => (
          'Create your account',
          'Keep a safe online copy of your records'
        ),
      AuthMode.confirmSignup => (
          'Check your email',
          'Enter the 8-digit code to confirm your account'
        ),
      AuthMode.forgot => (
          'Forgot your password?',
          'We will email you a reset code'
        ),
      AuthMode.resetCode => (
          'Set a new password',
          'Use the 8-digit code from the email'
        ),
    };

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 18),
          if (_notice != null) _banner(_notice!, AppColors.green),
          if (_error != null) _banner(_error!, AppColors.red),
          ..._fields(),
          const SizedBox(height: 18),
          SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: _busy ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      switch (_mode) {
                        AuthMode.signIn => 'Sign In',
                        AuthMode.signUp => 'Create Account',
                        AuthMode.confirmSignup => 'Verify Code',
                        AuthMode.forgot => 'Send Reset Code',
                        AuthMode.resetCode => 'Reset Password',
                      },
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _fields() {
    final emailField = _input(
      controller: _email,
      label: 'Email Address',
      keyboard: TextInputType.emailAddress,
    );
    final passwordField = _input(
      controller: _password,
      label: _mode == AuthMode.resetCode ? 'New Password' : 'Password',
      obscure: _obscure,
      suffix: IconButton(
        icon: Icon(
          _obscure ? Icons.visibility_off : Icons.visibility,
          size: 18,
          color: AppColors.textSecondary,
        ),
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
    );
    final confirmField = _input(
      controller: _confirmPassword,
      label: 'Confirm Password',
      obscure: true,
    );
    final codeField = _input(
      controller: _code,
      label: '8-Digit Code',
      keyboard: TextInputType.number,
      center: true,
    );

    switch (_mode) {
      case AuthMode.signIn:
        return [
          emailField,
          const SizedBox(height: 12),
          passwordField,
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _busy ? null : () => _switch(AuthMode.forgot),
              child: Text(
                'Forgot password?',
                style: GoogleFonts.inter(
                  color: AppColors.amber,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ];
      case AuthMode.signUp:
        return [
          _input(
            controller: _fullName,
            label: 'Full Name',
            keyboard: TextInputType.name,
          ),
          const SizedBox(height: 12),
          _input(
            controller: _phone,
            label: 'Phone Number (optional)',
            keyboard: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          emailField,
          const SizedBox(height: 12),
          passwordField,
          const SizedBox(height: 12),
          confirmField,
        ];
      case AuthMode.confirmSignup:
        return [
          codeField,
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                        await context
                            .read<SyncService>()
                            .resendSignupCode(_email.text.trim());
                        if (mounted) {
                          setState(() => _notice = 'A new code is on its way.');
                        }
                      }),
              child: Text(
                'Resend code',
                style: GoogleFonts.inter(
                  color: AppColors.amber,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ];
      case AuthMode.forgot:
        return [emailField];
      case AuthMode.resetCode:
        return [
          codeField,
          const SizedBox(height: 12),
          passwordField,
          const SizedBox(height: 12),
          confirmField,
        ];
    }
  }

  Widget _footerLinks() {
    final (question, action, target) = switch (_mode) {
      AuthMode.signIn => (
          "Don't have an account?",
          'Create Account',
          AuthMode.signUp
        ),
      AuthMode.signUp => ('Already have an account?', 'Sign In', AuthMode.signIn),
      _ => ('Changed your mind?', 'Back to Sign In', AuthMode.signIn),
    };
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          question,
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
        TextButton(
          onPressed: _busy ? null : () => _switch(target),
          child: Text(
            action,
            style: GoogleFonts.inter(
              color: AppColors.amber,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _banner(String message, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        message,
        style: GoogleFonts.inter(color: color, fontSize: 11),
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboard,
    bool obscure = false,
    bool center = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: center
          ? GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: 22,
              letterSpacing: 8,
            )
          : TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.amber),
        ),
      ),
    );
  }
}
