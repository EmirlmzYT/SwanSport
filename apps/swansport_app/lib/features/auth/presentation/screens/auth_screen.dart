import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../application/auth_controller.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final controller = ref.read(authControllerProvider.notifier);
    final success = await controller.submit(
      email: _emailController.text,
      password: _passwordController.text,
      fullName: _fullNameController.text,
    );

    if (!mounted) return;
    if (success) {
      // Ana sayfa herkes için aynı: sosyal akış.
      // ignore: unawaited_futures
      Navigator.pushReplacementNamed(context, '/akis');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authControllerProvider);
    final isSignUp = authState.mode == AuthMode.signUp;

    return Scaffold(
      backgroundColor:
          isDark ? SwanColors.darkBackground : SwanColors.background,
      body: Stack(
        children: [
          // Subtle radial depth background
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.4,
                  colors: [
                    const Color(
                      0xFF008C95,
                    ).withValues(alpha: isDark ? 0.08 : 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo mark
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: SwanColors.primary,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: SwanColors.primary.withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'S',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 26,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Editorial heading
                      const Text(
                        'Hoş Geldiniz,',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: SwanColors.textSecondary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'SwanSport',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.2,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isSignUp
                            ? 'Yeni hesap oluştur.'
                            : 'Profesyonel spor yönetim platformu.',
                        style: const TextStyle(
                          fontSize: 13,
                          color: SwanColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Login Card
                      _buildCard(
                        isDark: isDark,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isSignUp) ...[
                              _buildInputLabel('Ad Soyad'),
                              const SizedBox(height: 8),
                              _buildTextField(
                                isDark: isDark,
                                controller: _fullNameController,
                                hintText: 'Ahmet Koç',
                                prefixIcon: Icons.person_outline_rounded,
                              ),
                              const SizedBox(height: 16),
                            ],
                            _buildInputLabel('E-posta'),
                            const SizedBox(height: 8),
                            _buildTextField(
                              isDark: isDark,
                              controller: _emailController,
                              hintText: 'ornek@kulup.org',
                              keyboardType: TextInputType.emailAddress,
                              prefixIcon: Icons.alternate_email_rounded,
                            ),
                            const SizedBox(height: 16),
                            _buildInputLabel('Şifre'),
                            const SizedBox(height: 8),
                            _buildTextField(
                              isDark: isDark,
                              controller: _passwordController,
                              hintText: '••••••••••',
                              obscureText: _obscurePassword,
                              prefixIcon: Icons.lock_outline_rounded,
                              onSubmitted: (_) => _submit(),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  size: 20,
                                  color: SwanColors.textSecondary,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),

                            // Error message
                            if (authState.errorMessage != null) ...[
                              const SizedBox(height: 14),
                              _buildMessage(authState.errorMessage!),
                            ],

                            const SizedBox(height: 20),

                            // Primary CTA
                            SwanButton.primary(
                              label: isSignUp ? 'Kayıt Ol' : 'Giriş Yap',
                              width: double.infinity,
                              height: 52,
                              icon: Icons.arrow_forward_rounded,
                              isLoading: authState.isSubmitting,
                              onPressed:
                                  authState.isSubmitting ? null : _submit,
                            ),
                            const SizedBox(height: 6),
                            if (!isSignUp)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: authState.isSubmitting
                                      ? null
                                      : () => ref
                                          .read(authControllerProvider.notifier)
                                          .sendPasswordReset(
                                              _emailController.text),
                                  child: const Text(
                                    'Şifremi unuttum',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: SwanColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 6),

                            // Divider
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: isDark
                                        ? const Color(0xFF2E3440)
                                        : SwanColors.outline,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Text(
                                    'veya',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? SwanColors.darkText
                                              .withValues(alpha: 0.4)
                                          : SwanColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: isDark
                                        ? const Color(0xFF2E3440)
                                        : SwanColors.outline,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Mode toggle (sign in <-> sign up)
                            SwanButton.secondary(
                              label: isSignUp
                                  ? 'Zaten hesabın var mı? Giriş yap'
                                  : 'Hesabın yok mu? Kayıt ol',
                              width: double.infinity,
                              icon: isSignUp
                                  ? Icons.login_rounded
                                  : Icons.person_add_alt_rounded,
                              onPressed: authState.isSubmitting
                                  ? null
                                  : () => ref
                                      .read(authControllerProvider.notifier)
                                      .toggleMode(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required bool isDark, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? SwanColors.darkSurface : SwanColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3440) : const Color(0xFFEAEFF2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.1,
      ),
    );
  }

  Widget _buildMessage(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: SwanColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: SwanColors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: SwanColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: SwanColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required bool isDark,
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    TextInputType? keyboardType,
    IconData? prefixIcon,
    Widget? suffixIcon,
    ValueChanged<String>? onSubmitted,
  }) {
    final fillColor =
        isDark ? SwanColors.darkSurfaceVariant : SwanColors.surfaceVariant;
    final borderColor = isDark ? const Color(0xFF2E3440) : SwanColors.outline;

    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: isDark
              ? SwanColors.darkText.withValues(alpha: 0.35)
              : SwanColors.textSecondary.withValues(alpha: 0.7),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 18, color: SwanColors.textSecondary)
            : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: fillColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SwanColors.primary, width: 1.5),
        ),
      ),
    );
  }
}
