import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_type.dart';
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
      // ignore: unawaited_futures
      Navigator.pushReplacementNamed(context, '/akis');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final authState = ref.watch(authControllerProvider);
    final isSignUp = authState.mode == AuthMode.signUp;

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          // Arka plan soft gradyan
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.5,
                  colors: [
                    c.accent.withValues(alpha: c.isDark ? 0.08 : 0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Marka Logosu & Başlık
                      Center(
                        child: Column(
                          children: [
                            Text(
                              'swanspor',
                              style: SwanType.wordmark(c.ink),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Spor Kulüpleri ve Sosyal Spor Ağı',
                              style: SwanType.bodySm(c.inkMuted, w: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Ana Kart
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: c.line.withValues(alpha: c.isDark ? 0.4 : 0.7),
                            width: 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: c.isDark ? 0.25 : 0.05),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Mod Seçici (Giriş Yap / Kayıt Ol)
                            Container(
                              height: 40,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: c.surfaceAlt,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: c.line.withValues(alpha: 0.5),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _tabButton(
                                      label: 'Giriş Yap',
                                      active: !isSignUp,
                                      c: c,
                                      onTap: () {
                                        if (isSignUp) {
                                          ref.read(authControllerProvider.notifier).toggleMode();
                                        }
                                      },
                                    ),
                                  ),
                                  Expanded(
                                    child: _tabButton(
                                      label: 'Kayıt Ol',
                                      active: isSignUp,
                                      c: c,
                                      onTap: () {
                                        if (!isSignUp) {
                                          ref.read(authControllerProvider.notifier).toggleMode();
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            if (isSignUp) ...[
                              _buildInputLabel('Ad Soyad', c),
                              const SizedBox(height: 8),
                              _buildTextField(
                                controller: _fullNameController,
                                hintText: 'Ad Soyad',
                                prefixIcon: Icons.person_outline_rounded,
                                c: c,
                              ),
                              const SizedBox(height: 16),
                            ],

                            _buildInputLabel('E-posta', c),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: _emailController,
                              hintText: 'ornek@kulup.org',
                              keyboardType: TextInputType.emailAddress,
                              prefixIcon: Icons.alternate_email_rounded,
                              c: c,
                            ),
                            const SizedBox(height: 16),

                            _buildInputLabel('Şifre', c),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: _passwordController,
                              hintText: '••••••••••',
                              obscureText: _obscurePassword,
                              prefixIcon: Icons.lock_outline_rounded,
                              onSubmitted: (_) => _submit(),
                              c: c,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  size: 20,
                                  color: c.inkMuted,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),

                            if (authState.errorMessage != null) ...[
                              const SizedBox(height: 14),
                              _buildMessage(authState.errorMessage!, c),
                            ],

                            const SizedBox(height: 22),

                            // Birincil Aksiyon Butonu
                            InkWell(
                              onTap: authState.isSubmitting ? null : _submit,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                height: 50,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: c.accentFill,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: authState.isSubmitting
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            isSignUp ? 'Hesap Oluştur' : 'Giriş Yap',
                                            style: SwanType.body(Colors.white, w: FontWeight.w700),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 18,
                                            color: Colors.white,
                                          ),
                                        ],
                                      ),
                              ),
                            ),

                            if (!isSignUp) ...[
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: authState.isSubmitting
                                      ? null
                                      : () => ref
                                          .read(authControllerProvider.notifier)
                                          .sendPasswordReset(_emailController.text),
                                  child: Text(
                                    'Şifremi unuttum',
                                    style: SwanType.caption(c.accent, w: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 14),

                            // Ayırıcı
                            Row(
                              children: [
                                Expanded(child: Divider(color: c.line)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    'veya',
                                    style: SwanType.caption(c.inkMuted),
                                  ),
                                ),
                                Expanded(child: Divider(color: c.line)),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Keşfet & Demo Butonları
                            OutlinedButton.icon(
                              onPressed: () {
                                // ignore: unawaited_futures
      Navigator.pushReplacementNamed(context, '/akis');
                              },
                              icon: Icon(Icons.explore_rounded, size: 18, color: c.ink),
                              label: Text(
                                'Giriş Yapmadan Keşfet',
                                style: SwanType.bodySm(c.ink, w: FontWeight.w600),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: c.line.withValues(alpha: 0.8)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 13),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () {
                                Navigator.pushNamed(context, '/demo-rol');
                              },
                              icon: Icon(Icons.theater_comedy_rounded, size: 17, color: c.accent),
                              label: Text(
                                'Demo Rolü ile Dene',
                                style: SwanType.caption(c.accent, w: FontWeight.w700),
                              ),
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

  Widget _tabButton({
    required String label,
    required bool active,
    required SwanPalette c,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? c.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: c.isDark ? 0.2 : 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: SwanType.bodySm(
            active ? c.ink : c.inkMuted,
            w: active ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label, SwanPalette c) {
    return Text(
      label,
      style: SwanType.caption(c.ink, w: FontWeight.w700),
    );
  }

  Widget _buildMessage(String message, SwanPalette c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: c.danger.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: c.danger,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: SwanType.caption(c.danger, w: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required SwanPalette c,
    bool obscureText = false,
    TextInputType? keyboardType,
    IconData? prefixIcon,
    Widget? suffixIcon,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      style: SwanType.bodySm(c.ink),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: SwanType.bodySm(c.inkMuted.withValues(alpha: 0.7)),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18, color: c.inkMuted) : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: c.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.line.withValues(alpha: 0.6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.line.withValues(alpha: 0.6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.accent, width: 1.5),
        ),
      ),
    );
  }
}
