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
    return Scaffold(body: Row(children: [
      Expanded(flex: 45, child: Container(
        height: double.infinity,
        decoration: const BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [SwanColors.darkBackground, SwanColors.primaryPressed],
        )),
        child: Center(child: SingleChildScrollView(
          padding: const EdgeInsets.all(ConsoleDensity.xxl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.shield_moon_rounded, color: SwanColors.darkPrimary, size: 48),
            const SizedBox(height: ConsoleDensity.xl),
            Text('SwanSport Konsol', style: t.textTheme.headlineMedium?.copyWith(
                color: SwanColors.darkText, fontWeight: FontWeight.w700)),
            const SizedBox(height: ConsoleDensity.lg),
            Text('Spor Kulüpleri ve Tesisler İçin Dijital Yönetim Masası',
                style: t.textTheme.titleMedium?.copyWith(color: SwanColors.darkText)),
            const SizedBox(height: ConsoleDensity.xxl),
            for (final feature in const [
              (Icons.groups_rounded, 'Kadro & Yoklama Yönetimi'),
              (Icons.account_balance_wallet_rounded, 'Şeffaf Mali Defter'),
              (Icons.verified_user_rounded, 'Federasyon Onaylı Resmi Sicil'),
            ]) Padding(
              padding: const EdgeInsets.only(bottom: ConsoleDensity.xl),
              child: Row(children: [
                Icon(feature.$1, color: SwanColors.darkPrimary, size: 24),
                const SizedBox(width: ConsoleDensity.md),
                Expanded(child: Text(feature.$2, style: t.textTheme.bodyMedium
                    ?.copyWith(color: SwanColors.darkText))),
              ]),
            ),
            Text('Kulübün, ekibin ve günlük operasyonların tek bir masada.',
                style: t.textTheme.bodySmall?.copyWith(color: SwanColors.darkText)),
          ]),
        )),
      )),
      Expanded(flex: 55, child: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(ConsoleDensity.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: ConsoleDensity.loginCardWidth),
          child: Card(child: Padding(
            padding: const EdgeInsets.all(ConsoleDensity.xxl),
            child: AutofillGroup(child: Form(key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Yönetim masasına giriş', style: t.textTheme.titleLarge),
                const SizedBox(height: ConsoleDensity.sm),
                Text('Uygulamadaki hesabınla güvenle devam et.', style: t.textTheme.bodySmall),
                const SizedBox(height: ConsoleDensity.xl),
                TextFormField(
                  controller: _email, autofocus: true, enabled: !_busy,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.username],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'E-posta',
                      prefixIcon: Icon(Icons.mail_outline_rounded)),
                  validator: (v) => v == null || !v.trim().contains('@')
                      ? 'Geçerli bir e-posta gir' : null,
                ),
                const SizedBox(height: ConsoleDensity.lg),
                TextFormField(
                  controller: _password, obscureText: _obscure, enabled: !_busy,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(labelText: 'Parola',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Parolayı göster' : 'Parolayı gizle',
                      onPressed: _busy ? null : () => setState(() => _obscure = !_obscure),
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    )),
                  onFieldSubmitted: (_) => _submit(),
                  validator: (v) => v == null || v.isEmpty ? 'Parola gerekli' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: ConsoleDensity.lg),
                  Semantics(liveRegion: true, child: Container(
                    padding: const EdgeInsets.all(ConsoleDensity.md),
                    decoration: BoxDecoration(
                      color: t.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(ConsoleDensity.radius)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.error_outline_rounded, color: t.colorScheme.onErrorContainer, size: 20),
                      const SizedBox(width: ConsoleDensity.sm),
                      Expanded(child: Text(_error!, style: t.textTheme.bodySmall
                          ?.copyWith(color: t.colorScheme.onErrorContainer))),
                    ]),
                  )),
                ],
                const SizedBox(height: ConsoleDensity.xl),
                FilledButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) =>
                      states.contains(WidgetState.disabled) ? t.colorScheme.onSurface.withValues(alpha: .12)
                      : states.contains(WidgetState.hovered) ? SwanColors.primaryHover : SwanColors.primary)),
                  onPressed: _busy ? null : _submit,
                  child: Padding(padding: const EdgeInsets.symmetric(vertical: ConsoleDensity.md),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      if (_busy) ...[
                        const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(width: ConsoleDensity.sm),
                      ],
                      Text(_busy ? 'Giriş yapılıyor…' : 'Giriş yap'),
                    ])),
                ),
                const SizedBox(height: ConsoleDensity.lg),
                Text('Yalnızca yetkilendirildiğin yönetim alanlarına erişebilirsin.',
                    textAlign: TextAlign.center, style: t.textTheme.bodySmall),
              ]),
            )),
          )),
        ),
      ))),
    ]));
  }
}
