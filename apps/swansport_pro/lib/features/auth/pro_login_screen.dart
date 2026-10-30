import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/pro_theme.dart';
import 'pro_auth_controller.dart';

class ProLoginScreen extends ConsumerStatefulWidget {
  const ProLoginScreen({super.key});

  @override
  ConsumerState<ProLoginScreen> createState() => _ProLoginScreenState();
}

class _ProLoginScreenState extends ConsumerState<ProLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    ref.read(proAuthControllerProvider.notifier).signIn(
          _emailController.text,
          _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(proAuthControllerProvider);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.8, -0.8),
            radius: 1.5,
            colors: [Color(0xFF12314A), ProTheme.background],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= 900;
              return SingleChildScrollView(
                padding: EdgeInsets.all(desktop ? 32 : 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - (desktop ? 64 : 40),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: desktop
                          ? Row(
                              children: [
                                const Expanded(child: _LoginHero()),
                                const SizedBox(width: 72),
                                SizedBox(
                                  width: 440,
                                  child: _buildLoginCard(authState),
                                ),
                              ],
                            )
                          : _buildLoginCard(authState),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard(ProAuthState authState) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ProTheme.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ProTheme.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 40,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [ProTheme.primary, ProTheme.secondary],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.sports_rounded,
                  color: Color(0xFF03201D),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SwanSport Pro',
                      style: TextStyle(
                        color: ProTheme.ink,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                      ),
                    ),
                    Text(
                      'Profesyonel operasyon merkezi',
                      style: TextStyle(color: ProTheme.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          const Text(
            'Tekrar hoş geldin',
            style: TextStyle(
              color: ProTheme.ink,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Yetkili çalışma alanlarına devam etmek için hesabınla giriş yap.',
            style: TextStyle(color: ProTheme.muted, height: 1.45),
          ),
          const SizedBox(height: 24),
          if (authState.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.10),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.45),
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFFCA5A5),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      authState.errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFFFECACA),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enabled: !authState.isSubmitting,
            style: const TextStyle(color: ProTheme.ink),
            decoration: const InputDecoration(
              labelText: 'E-posta',
              prefixIcon: Icon(Icons.alternate_email_rounded),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            enabled: !authState.isSubmitting,
            style: const TextStyle(color: ProTheme.ink),
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Şifre',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: Semantics(
                label: _obscurePassword ? 'Şifreyi göster' : 'Şifreyi gizle',
                button: true,
                child: IconButton(
                  constraints:
                      const BoxConstraints(minWidth: 48, minHeight: 48),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            onPressed: authState.isSubmitting ? null : _submit,
            child: authState.isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF03201D),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          'Giriş Yap',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 19),
                    ],
                  ),
          ),
          const SizedBox(height: 18),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_rounded, size: 14, color: ProTheme.muted),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Erişim kapsamın sunucuda güvenle doğrulanır',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ProTheme.muted, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: ProTheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: ProTheme.primary.withValues(alpha: 0.24),
              ),
            ),
            child: const Text(
              'SPOR OPERASYONLARI · TEK MERKEZ',
              style: TextStyle(
                color: ProTheme.primary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 26),
          const Text(
            'Sahadan yönetime\naynı ritimde çalış.',
            style: TextStyle(
              color: ProTheme.ink,
              fontSize: 44,
              height: 1.08,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.7,
            ),
          ),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: const Text(
              'Kulüp, antrenör, federasyon, hakem ve finans ekipleri için gerçek zamanlı ve yetki kontrollü operasyon alanı.',
              style: TextStyle(
                color: ProTheme.muted,
                fontSize: 16,
                height: 1.55,
              ),
            ),
          ),
          const SizedBox(height: 34),
          const Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _HeroFeature(
                  icon: Icons.groups_2_outlined, label: 'Ekip yönetimi'),
              _HeroFeature(
                  icon: Icons.sports_score_outlined, label: 'Canlı müsabaka'),
              _HeroFeature(
                  icon: Icons.query_stats_outlined, label: 'Mali kontrol'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroFeature extends StatelessWidget {
  const _HeroFeature({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: ProTheme.surface.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ProTheme.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: ProTheme.secondary, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: ProTheme.ink,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
