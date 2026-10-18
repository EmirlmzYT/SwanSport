import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../app/shell/too_narrow_notice.dart';
import '../../app/theme/console_theme.dart';

class ConsoleLoginScreen extends ConsumerStatefulWidget {
  const ConsoleLoginScreen({super.key});
  @override
  ConsumerState<ConsoleLoginScreen> createState() => _ConsoleLoginScreenState();
}

class _ConsoleLoginScreenState extends ConsumerState<ConsoleLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _busy = true; _error = null; });
    try {
      await ref.read(accountSessionServiceProvider).signIn(
          email: _email.text, password: _password.text);
      // Navigation belongs to the router's session listener.
    } catch (_) {
      if (mounted) setState(() => _error =
          'Giriş yapılamadı. E-posta ve parolanı kontrol edip yeniden dene.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    if (MediaQuery.sizeOf(context).width < ConsoleDensity.minSupportedWidth) {
      return const TooNarrowNotice();
    }
    final config = ref.watch(platformConfigProvider).valueOrNull;
    final name = config?.appName?.trim();
    final appName = name == null || name.isEmpty ? 'SwanSport' : name;
    final isDark = t.brightness == Brightness.dark;

    return Scaffold(
      body: Row(
        children: [
          // Sol Vitrin: Koyu Lacivert & Turkuaz Komuta Sahnesi
          Expanded(
            flex: 48,
            child: Container(
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF050A14),
                    Color(0xFF0C182D),
                    Color(0xFF0A2630),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -90,
                    left: -70,
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            ConsoleTheme.commandAccent.withValues(alpha: .22),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -100,
                    right: -60,
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            ConsoleTheme.commandSecondary.withValues(alpha: .14),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(ConsoleDensity.xxl),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(ConsoleDensity.sm),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: .07),
                                    borderRadius: BorderRadius.circular(
                                      ConsoleDensity.radius + 2,
                                    ),
                                    border: Border.all(
                                      color: ConsoleTheme.commandAccent
                                          .withValues(alpha: .38),
                                    ),
                                  ),
                                  child: SwanNetworkLogo(
                                    url: config?.logoUrl,
                                    size: ConsoleDensity.loginBrandMarkSize,
                                    semanticLabel: appName,
                                    fallback: const Icon(
                                      Icons.shield_moon_rounded,
                                      color: SwanColors.darkPrimary,
                                      size: ConsoleDensity.loginBrandMarkSize,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: ConsoleDensity.md),
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: ConsoleDensity.md,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: ConsoleTheme.commandAccent
                                          .withValues(alpha: .14),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: ConsoleTheme.commandAccent
                                            .withValues(alpha: .35),
                                      ),
                                    ),
                                    child: Text(
                                      '360° YÖNETİM & KOMUTA MERKEZİ',
                                      overflow: TextOverflow.ellipsis,
                                      style: t.textTheme.labelSmall?.copyWith(
                                        color: ConsoleTheme.commandAccent,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: ConsoleDensity.xl),
                            Text(
                              '$appName Konsol',
                              style: t.textTheme.headlineMedium?.copyWith(
                                fontSize: 30,
                                color: SwanColors.darkText,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: ConsoleDensity.sm),
                            Text(
                              'Spor Kulüpleri ve Tesisler İçin Dijital Yönetim Masası',
                              style: t.textTheme.titleMedium?.copyWith(
                                color: SwanColors.darkText.withValues(alpha: .88),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: ConsoleDensity.xl),
                            for (final feature in const [
                              (
                                Icons.groups_rounded,
                                'Kadro & Yoklama Yönetimi',
                                '60 branşta sporcu sicili, uygunluk ve tesis planlama'
                              ),
                              (
                                Icons.account_balance_wallet_rounded,
                                'Şeffaf Mali Defter',
                                '#A3F91C muhasebeci gizlilik kalkanı ve çift gözlü onay'
                              ),
                              (
                                Icons.verified_user_rounded,
                                'Federasyon Onaylı Resmi Sicil',
                                'MHK hakem atama, disiplin kurulu ve canlı lig tescili'
                              ),
                            ])
                              Container(
                                margin: const EdgeInsets.only(
                                  bottom: ConsoleDensity.md,
                                ),
                                padding: const EdgeInsets.all(ConsoleDensity.md),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: .04),
                                  borderRadius: BorderRadius.circular(
                                    ConsoleDensity.radius,
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: .10),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: ConsoleTheme.commandAccent
                                            .withValues(alpha: .15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        feature.$1,
                                        color: SwanColors.darkPrimary,
                                        size: 21,
                                      ),
                                    ),
                                    const SizedBox(width: ConsoleDensity.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            feature.$2,
                                            style: t.textTheme.bodyMedium
                                                ?.copyWith(
                                              color: SwanColors.darkText,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            feature.$3,
                                            style:
                                                t.textTheme.bodySmall?.copyWith(
                                              color: ConsoleTheme.commandMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: ConsoleDensity.sm),
                            Row(
                              children: [
                                const Icon(
                                  Icons.lock_person_outlined,
                                  size: 16,
                                  color: ConsoleTheme.commandAccent,
                                ),
                                const SizedBox(width: ConsoleDensity.sm),
                                Expanded(
                                  child: Text(
                                    'Kulübün, ekibin ve günlük operasyonların tek bir masada.',
                                    style: t.textTheme.bodySmall?.copyWith(
                                      color: ConsoleTheme.commandMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Sağ Alan: Yetkili Giriş Kartı
          Expanded(
            flex: 52,
            child: Container(
              height: double.infinity,
              color: t.scaffoldBackgroundColor,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(ConsoleDensity.xxl),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: ConsoleDensity.loginCardWidth,
                    ),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(ConsoleDensity.xxl),
                        child: AutofillGroup(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: t.colorScheme.primary
                                            .withValues(alpha: .14),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: t.colorScheme.primary
                                              .withValues(alpha: .32),
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.space_dashboard_rounded,
                                        color: t.colorScheme.primary,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: ConsoleDensity.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Yönetim masasına giriş',
                                            style: t.textTheme.titleLarge,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Uygulamadaki hesabınla güvenle devam et.',
                                            style: t.textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: ConsoleDensity.xl),
                                TextFormField(
                                  controller: _email,
                                  autofocus: true,
                                  enabled: !_busy,
                                  keyboardType: TextInputType.emailAddress,
                                  autofillHints: const [AutofillHints.username],
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'E-posta',
                                    prefixIcon:
                                        Icon(Icons.mail_outline_rounded),
                                  ),
                                  validator: (v) =>
                                      v == null || !v.trim().contains('@')
                                          ? 'Geçerli bir e-posta gir'
                                          : null,
                                ),
                                const SizedBox(height: ConsoleDensity.lg),
                                TextFormField(
                                  controller: _password,
                                  obscureText: _obscure,
                                  enabled: !_busy,
                                  autofillHints: const [AutofillHints.password],
                                  textInputAction: TextInputAction.done,
                                  decoration: InputDecoration(
                                    labelText: 'Parola',
                                    prefixIcon:
                                        const Icon(Icons.lock_outline_rounded),
                                    suffixIcon: IconButton(
                                      tooltip: _obscure
                                          ? 'Parolayı göster'
                                          : 'Parolayı gizle',
                                      onPressed: _busy
                                          ? null
                                          : () => setState(
                                                () => _obscure = !_obscure,
                                              ),
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                                  onFieldSubmitted: (_) => _submit(),
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Parola gerekli'
                                      : null,
                                ),
                                if (_error != null) ...[
                                  const SizedBox(height: ConsoleDensity.lg),
                                  Semantics(
                                    liveRegion: true,
                                    child: Container(
                                      padding: const EdgeInsets.all(
                                        ConsoleDensity.md,
                                      ),
                                      decoration: BoxDecoration(
                                        color: t.colorScheme.errorContainer,
                                        borderRadius: BorderRadius.circular(
                                          ConsoleDensity.radius,
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.error_outline_rounded,
                                            color:
                                                t.colorScheme.onErrorContainer,
                                            size: 20,
                                          ),
                                          const SizedBox(
                                            width: ConsoleDensity.sm,
                                          ),
                                          Expanded(
                                            child: Text(
                                              _error!,
                                              style: t.textTheme.bodySmall
                                                  ?.copyWith(
                                                color: t.colorScheme
                                                    .onErrorContainer,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: ConsoleDensity.xl),
                                FilledButton(
                                  style: ButtonStyle(
                                    backgroundColor:
                                        WidgetStateProperty.resolveWith(
                                      (states) => states.contains(
                                        WidgetState.disabled,
                                      )
                                          ? t.colorScheme.onSurface
                                              .withValues(alpha: .12)
                                          : states.contains(WidgetState.hovered)
                                              ? SwanColors.primaryHover
                                              : (isDark
                                                  ? ConsoleTheme.commandAccent
                                                  : SwanColors.primary),
                                    ),
                                    foregroundColor: WidgetStatePropertyAll(
                                      isDark
                                          ? const Color(0xFF041318)
                                          : Colors.white,
                                    ),
                                  ),
                                  onPressed: _busy ? null : _submit,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: ConsoleDensity.md,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        if (_busy) ...[
                                          const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                          const SizedBox(
                                            width: ConsoleDensity.sm,
                                          ),
                                        ],
                                        Text(
                                          _busy
                                              ? 'Giriş yapılıyor…'
                                              : 'Giriş yap',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: ConsoleDensity.lg),
                                Container(
                                  padding: const EdgeInsets.all(
                                    ConsoleDensity.md,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        t.colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(
                                      ConsoleDensity.radius,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.shield_outlined,
                                        size: 16,
                                        color: t.colorScheme.primary,
                                      ),
                                      const SizedBox(width: ConsoleDensity.sm),
                                      Expanded(
                                        child: Text(
                                          'Yalnızca yetkilendirildiğin yönetim alanlarına erişebilirsin.',
                                          style: t.textTheme.bodySmall,
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
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
