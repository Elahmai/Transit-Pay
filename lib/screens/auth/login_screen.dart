import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../utils/theme.dart';

// ─── Login / Sign-Up Screen ───────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _authService = AuthService();
  bool _loading = false, _obscure = true, _isSignUp = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      if (_isSignUp) {
        setState(() => _loading = false);
        Navigator.pushNamed(context, AppRoutes.roleSelect,
            arguments: {
              'email': _emailCtrl.text.trim(),
              'password': _passwordCtrl.text,
            });
      } else {
        final user = await _authService.signInWithEmail(
            email: _emailCtrl.text.trim(), password: _passwordCtrl.text);
        if (!mounted) return;
        if (user == null) {
          _showError('Account not found. Please sign up first.');
          return;
        }
        Navigator.pushNamedAndRemoveUntil(
          context,
          user.isDriver ? AppRoutes.driverHome : AppRoutes.passengerHome,
          (_) => false,
        );
      }
    } catch (e) {
      _showError(_friendly(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    if (_emailCtrl.text.trim().isEmpty) {
      _showError('Enter your email above first.');
      return;
    }
    try {
      await _authService.sendPasswordReset(_emailCtrl.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Password reset link sent. Check your inbox.'),
        backgroundColor: AppColors.secondary,
      ));
    } catch (e) {
      _showError(_friendly(e.toString()));
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.error));

  String _friendly(String raw) {
    if (raw.contains('user-not-found') ||
        raw.contains('wrong-password') ||
        raw.contains('invalid-credential')) {
      return 'Incorrect email or password.';
    }
    if (raw.contains('email-already-in-use')) return 'An account with this email already exists.';
    if (raw.contains('weak-password')) return 'Password must be at least 6 characters.';
    if (raw.contains('invalid-email')) return 'Enter a valid email address.';
    if (raw.contains('network-request-failed')) return 'No internet connection.';
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 32),
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.directions_bus_filled,
                      color: AppColors.primary, size: 32),
                ),
                const SizedBox(height: 24),
                Text(
                  _isSignUp ? 'Create Account' : 'Welcome Back',
                  style: const TextStyle(
                      fontSize: 30, fontWeight: FontWeight.w700, color: AppColors.dark),
                ),
                const SizedBox(height: 6),
                Text(
                  _isSignUp
                      ? 'Sign up to start riding with Transit Pay'
                      : 'Sign in to your Transit Pay account',
                  style: const TextStyle(color: AppColors.gray500, fontSize: 15),
                ),
                const SizedBox(height: 36),

                // Email
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email_outlined),
                      hintText: 'you@example.com'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email is required';
                    if (!RegExp(r'^[\w.]+@[\w]+\.[a-z]{2,}$').hasMatch(v.trim())) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Password
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: AppColors.gray500),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (_isSignUp && v.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),

                if (!_isSignUp) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _forgotPassword,
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero, minimumSize: const Size(0, 36)),
                      child: const Text('Forgot password?',
                          style: TextStyle(color: AppColors.primary, fontSize: 14)),
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(_isSignUp ? 'Continue' : 'Sign In'),
                ),
                const SizedBox(height: 20),

                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(
                      _isSignUp
                          ? 'Already have an account? '
                          : "Don't have an account? ",
                      style: const TextStyle(color: AppColors.gray500, fontSize: 14)),
                  GestureDetector(
                    onTap: () => setState(() => _isSignUp = !_isSignUp),
                    child: Text(
                        _isSignUp ? 'Sign In' : 'Sign Up',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      );
}

// ─── Role & Profile Setup (Sign-up step 2) ────────────────────────
class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});
  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _authService = AuthService();
  String _role = 'passenger';
  bool _loading = false;
  late Map<String, dynamic> _args;
  bool _argsLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsLoaded) {
      _args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      _argsLoaded = true;
    }
  }

  @override
  void dispose() { _nameCtrl.dispose(); _phoneCtrl.dispose(); super.dispose(); }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final user = await _authService.signUpWithEmail(
        email: _args['email'],
        password: _args['password'],
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        role: _role,
      );
      if (!mounted) return;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Sign up failed.'), backgroundColor: AppColors.error));
        return;
      }
      Navigator.pushNamedAndRemoveUntil(
        context,
        _role == 'driver' ? AppRoutes.driverHome : AppRoutes.passengerHome,
        (_) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(title: const Text('Complete Profile')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 8),
              const Text('Almost there!',
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.dark)),
              const SizedBox(height: 6),
              const Text('Tell us a bit about yourself to finish setting up.',
                  style: TextStyle(color: AppColors.gray500, fontSize: 15)),
              const SizedBox(height: 32),

              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline)),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please enter your name'
                    : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                    labelText: 'Safaricom Number (for M-Pesa)',
                    prefixText: '+254  ',
                    prefixIcon: Icon(Icons.phone_outlined),
                    hintText: '7XX XXX XXX'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Phone is required';
                  if (v.trim().length < 9) return 'Enter a valid Kenyan number';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              const Text('I am a:',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: AppColors.dark, fontSize: 14)),
              const SizedBox(height: 10),
              Row(children: [
                _roleCard('passenger', 'Passenger', Icons.person_outline),
                const SizedBox(width: 12),
                _roleCard('driver', 'Driver / Owner', Icons.directions_bus_outlined),
              ]),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _loading ? null : _createAccount,
                child: _loading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Create Account'),
              ),
            ]),
          ),
        ),
      );

  Widget _roleCard(String value, String label, IconData icon) => Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _role = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _role == value ? AppColors.primaryLight : AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _role == value ? AppColors.primary : AppColors.gray300,
                  width: 1.5),
            ),
            child: Column(children: [
              Icon(icon,
                  color: _role == value ? AppColors.primary : AppColors.gray500,
                  size: 28),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: _role == value ? AppColors.primary : AppColors.gray700)),
            ]),
          ),
        ),
      );
}
