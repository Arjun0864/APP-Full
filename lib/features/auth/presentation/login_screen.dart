import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/glass_card.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isSignup = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Field focus nodes for proper keyboard handling
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  // ── Validation helpers ────────────────────────────────────────────────────

  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Full name is required';
    if (v.trim().length < 2) return 'Name must be at least 2 characters';
    if (v.trim().length > 50) return 'Name must be under 50 characters';
    return null;
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email address is required';
    final email = v.trim().toLowerCase();
    // RFC 5322 simplified regex
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) return 'Enter a valid email address';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Password must be at least 8 characters';
    if (!v.contains(RegExp(r'[A-Z]'))) return 'Include at least one uppercase letter';
    if (!v.contains(RegExp(r'[a-z]'))) return 'Include at least one lowercase letter';
    if (!v.contains(RegExp(r'[0-9]'))) return 'Include at least one number';
    if (!v.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) {
      return 'Include at least one special character (!@#\$%^&*)';
    }
    return null;
  }

  String? _validateLoginPassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  String? _validateConfirmPassword(String? v) {
    if (v == null || v.isEmpty) return 'Please confirm your password';
    if (v != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  bool _navigatedToDashboard = false;

  Future<void> _submit() async {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;
    final auth = ref.read(authProvider.notifier);

    if (_isSignup) {
      await auth.signup(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
      );
    } else {
      final success = await auth.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (success && mounted && !_navigatedToDashboard) {
        _navigatedToDashboard = true;
        context.go('/dashboard');
      }
    }
  }

  void _toggleMode() {
    setState(() {
      _isSignup = !_isSignup;
      _formKey.currentState?.reset();
      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      _nameController.clear();
    });
    ref.read(authProvider.notifier).clearError();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.loading;

    // Listen for auth state changes and navigate
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.status == AuthStatus.authenticated && !_navigatedToDashboard) {
        _navigatedToDashboard = true;
        context.go('/dashboard');
      } else if (next.status != AuthStatus.authenticated) {
        // Allow navigation again on the next successful login attempt
        _navigatedToDashboard = false;
      }
    });

    // Show verification pending screen after signup OR when login blocked due to unverified email
    if (authState.status == AuthStatus.verificationPending) {
      return _buildVerificationPendingScreen();
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Container(
          decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
          child: Stack(
            children: [
              Positioned(
                top: -120,
                left: -80,
                child: _orb(280, AppColors.primary.withValues(alpha: 0.25)),
              ),
              Positioned(
                bottom: -100,
                right: -60,
                child: _orb(240, AppColors.accent.withValues(alpha: 0.2)),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 40),
                        _buildHeader(),
                        const SizedBox(height: 36),
                        _buildForm(isLoading),
                        const SizedBox(height: 16),
                        if (authState.error != null)
                          _buildError(authState.error!),
                        const SizedBox(height: 20),
                        _buildDivider(),
                        const SizedBox(height: 16),
                        _buildGoogleButton(isLoading),
                        const SizedBox(height: 12),
                        _buildAppleButton(isLoading),
                        const SizedBox(height: 28),
                        _buildToggle(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Verification Pending Screen ───────────────────────────────────────────

  Widget _buildVerificationPendingScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.mark_email_unread_outlined,
                      color: Colors.white, size: 48),
                ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.8, 0.8)),
                const SizedBox(height: 32),
                Text(
                  'Verify Your Email',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
                const SizedBox(height: 12),
                Text(
                  'We sent a verification link to\n${_emailController.text.trim()}',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 300.ms),
                const SizedBox(height: 8),
                Text(
                  'Click the link in the email to activate your account.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 400.ms),
                const SizedBox(height: 40),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: AppColors.primary, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Check your spam folder if you don\'t see the email.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 500.ms),
                const SizedBox(height: 32),
                // Already verified? Sign in button
                GradientButton(
                  text: 'I\'ve Verified — Sign In',
                  onPressed: () {
                    setState(() => _isSignup = false);
                    ref.read(authProvider.notifier).backToLogin();
                  },
                  width: double.infinity,
                  gradientColors: AppColors.accentGradient.colors,
                ).animate().fadeIn(delay: 600.ms),
                const SizedBox(height: 12),
                // Resend email button
                _ResendEmailButton(
                  email: _emailController.text.trim(),
                  password: _passwordController.text,
                ).animate().fadeIn(delay: 700.ms),
                const SizedBox(height: 16),
                // Back to signup
                TextButton(
                  onPressed: () {
                    setState(() => _isSignup = true);
                    ref.read(authProvider.notifier).backToLogin();
                  },
                  child: Text(
                    'Use a different email',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ).animate().fadeIn(delay: 800.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
        ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.8, 0.8)),
        const SizedBox(height: 24),
        Text(
          _isSignup ? 'Create Account' : 'Welcome Back',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ).animate().fadeIn(delay: 100.ms, duration: 500.ms).slideX(begin: -0.2),
        const SizedBox(height: 8),
        Text(
          _isSignup
              ? 'Start creating amazing AI videos'
              : 'Sign in to continue creating',
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
          ),
        ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
      ],
    );
  }

  // ── Form ──────────────────────────────────────────────────────────────────

  Widget _buildForm(bool isLoading) {
    return Column(
      children: [
        if (_isSignup) ...[
          _buildField(
            label: 'Full Name',
            hint: 'John Doe',
            controller: _nameController,
            focusNode: _nameFocus,
            nextFocus: _emailFocus,
            prefixIcon: Icons.person_outline,
            validator: _validateName,
            textCapitalization: TextCapitalization.words,
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
          const SizedBox(height: 16),
        ],
        _buildField(
          label: 'Email Address',
          hint: 'your@email.com',
          controller: _emailController,
          focusNode: _emailFocus,
          nextFocus: _passwordFocus,
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: _validateEmail,
        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
        const SizedBox(height: 16),
        _buildPasswordField(
          label: 'Password',
          hint: '••••••••',
          controller: _passwordController,
          focusNode: _passwordFocus,
          nextFocus: _isSignup ? _confirmFocus : null,
          obscure: _obscurePassword,
          onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
          validator: _isSignup ? _validatePassword : _validateLoginPassword,
        ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
        if (_isSignup) ...[
          const SizedBox(height: 16),
          _buildPasswordField(
            label: 'Confirm Password',
            hint: '••••••••',
            controller: _confirmPasswordController,
            focusNode: _confirmFocus,
            nextFocus: null,
            obscure: _obscureConfirmPassword,
            onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            validator: _validateConfirmPassword,
            textInputAction: TextInputAction.done,
          ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),
          const SizedBox(height: 12),
          _buildPasswordStrengthHint(),
        ],
        const SizedBox(height: 24),
        GradientButton(
          text: _isSignup ? 'Create Account' : 'Sign In',
          onPressed: isLoading ? null : _submit,
          isLoading: isLoading,
          width: double.infinity,
          gradientColors: AppColors.accentGradient.colors,
        ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),
      ],
    );
  }

  // ── Custom field builders ─────────────────────────────────────────────────

  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required FocusNode focusNode,
    FocusNode? nextFocus,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      textInputAction: nextFocus != null ? TextInputAction.next : TextInputAction.done,
      onFieldSubmitted: (_) {
        if (nextFocus != null) {
          FocusScope.of(context).requestFocus(nextFocus);
        } else {
          FocusScope.of(context).unfocus();
        }
      },
      validator: validator,
      style: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      decoration: _inputDecoration(label: label, hint: hint, prefixIcon: prefixIcon),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required FocusNode focusNode,
    FocusNode? nextFocus,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure,
      textInputAction: textInputAction,
      onFieldSubmitted: (_) {
        if (nextFocus != null) {
          FocusScope.of(context).requestFocus(nextFocus);
        } else {
          FocusScope.of(context).unfocus();
        }
      },
      validator: validator,
      style: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      decoration: _inputDecoration(
        label: label,
        hint: hint,
        prefixIcon: Icons.lock_outline,
        suffixIcon: GestureDetector(
          onTap: onToggle,
          child: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: AppColors.textMuted,
            size: 20,
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      labelStyle: TextStyle(
        color: AppColors.textMuted,
        fontSize: 14,
      ),
      floatingLabelStyle: TextStyle(
        color: AppColors.primaryLight,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: TextStyle(
        color: AppColors.textMuted,
        fontSize: 14,
      ),
      prefixIcon: Icon(prefixIcon, color: AppColors.textMuted, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.cardBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      errorStyle: const TextStyle(
        color: AppColors.error,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildPasswordStrengthHint() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password must contain:',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _strengthChip('8+ chars', _passwordController.text.length >= 8),
              _strengthChip('Uppercase', _passwordController.text.contains(RegExp(r'[A-Z]'))),
              _strengthChip('Lowercase', _passwordController.text.contains(RegExp(r'[a-z]'))),
              _strengthChip('Number', _passwordController.text.contains(RegExp(r'[0-9]'))),
              _strengthChip('Special char', _passwordController.text.contains(RegExp(r'[!@#\$%^&*]'))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _strengthChip(String label, bool met) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: met ? AppColors.success.withValues(alpha: 0.15) : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: met ? AppColors.success.withValues(alpha: 0.4) : AppColors.cardBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            met ? Icons.check : Icons.close,
            size: 10,
            color: met ? AppColors.success : AppColors.textMuted,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: met ? AppColors.success : AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderColor: AppColors.error.withValues(alpha: 0.5),
      backgroundColor: AppColors.error.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().shake();
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.cardBorder)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'or continue with',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
        Expanded(child: Divider(color: AppColors.cardBorder)),
      ],
    );
  }

  Widget _buildGoogleButton(bool isLoading) {
    return GestureDetector(
      onTap: isLoading
          ? null
          : () async {
              final success =
                  await ref.read(authProvider.notifier).loginWithGoogle();
              if (success && mounted && !_navigatedToDashboard) {
                _navigatedToDashboard = true;
                context.go('/dashboard');
              }
            },
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Center(
                child: Text('G',
                    style: TextStyle(
                        color: Color(0xFF4285F4),
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Continue with Google',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 600.ms);
  }

  Widget _buildAppleButton(bool isLoading) {
    return GestureDetector(
      onTap: isLoading
          ? null
          : () async {
              final success =
                  await ref.read(authProvider.notifier).loginWithApple();
              if (success && mounted && !_navigatedToDashboard) {
                _navigatedToDashboard = true;
                context.go('/dashboard');
              }
            },
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.apple, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Text(
              'Continue with Apple',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 650.ms);
  }

  Widget _buildToggle() {
    return Center(
      child: GestureDetector(
        onTap: _toggleMode,
        child: RichText(
          text: TextSpan(
            text: _isSignup ? 'Already have an account? ' : "Don't have an account? ",
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            children: [
              TextSpan(
                text: _isSignup ? 'Sign In' : 'Sign Up',
                style: TextStyle(
                  color: AppColors.primaryLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 700.ms);
  }

  Widget _orb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

// ── Resend Email Button ───────────────────────────────────────────────────────

class _ResendEmailButton extends ConsumerStatefulWidget {
  final String email;
  final String password;
  const _ResendEmailButton({required this.email, required this.password});

  @override
  ConsumerState<_ResendEmailButton> createState() => _ResendEmailButtonState();
}

class _ResendEmailButtonState extends ConsumerState<_ResendEmailButton> {
  bool _sending = false;
  bool _sent = false;

  Future<void> _resend() async {
    setState(() => _sending = true);
    final success = await ref.read(authProvider.notifier)
        .resendVerificationEmail(widget.email, widget.password);
    if (mounted) {
      setState(() {
        _sending = false;
        _sent = success;
      });
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Verification email sent! Check your inbox.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: (_sending || _sent) ? null : _resend,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_sending)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                ),
              )
            else
              Icon(
                _sent ? Icons.check_circle : Icons.refresh,
                color: _sent ? AppColors.success : AppColors.primaryLight,
                size: 18,
              ),
            const SizedBox(width: 8),
            Text(
              _sent ? 'Email sent!' : 'Resend verification email',
              style: TextStyle(
                color: _sent ? AppColors.success : AppColors.primaryLight,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
