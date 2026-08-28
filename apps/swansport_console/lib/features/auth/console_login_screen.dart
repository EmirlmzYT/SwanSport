import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/theme/console_theme.dart';

/// Konsol girişi.
///
/// Yalnızca giriş var, kayıt yok: konsola gelen kişinin hesabı zaten
/// uygulamada açılmış oluyor. Kayıt akışını burada ikinci kez sunmak, hangi
/// hesabın nereye ait olduğunu bulandırırdı.
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
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      // Yönlendirmeyi router'ın oturum dinleyicisi yapar.
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Giriş yapılamadı: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_moon_rounded,
                        color: t.colorScheme.primary, size: 26),
                    const SizedBox(width: ConsoleDensity.sm),
                    Text('SwanSport Konsol', style: t.textTheme.titleLarge),
                  ],
                ),
                const SizedBox(height: ConsoleDensity.sm),
                Text(
                  'Kulüp ve platform yönetimi. Uygulamadaki hesabınla giriş yap.',
                  style: t.textTheme.bodySmall,
                ),
                const SizedBox(height: ConsoleDensity.xl),
                TextFormField(
                  controller: _email,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-posta'),
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Geçerli bir e-posta gir'
                      : null,
                ),
                const SizedBox(height: ConsoleDensity.md),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Parola'),
                  onFieldSubmitted: (_) => _busy ? null : _submit(),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Parola gerekli' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: ConsoleDensity.md),
                  Text(_error!,
                      style: t.textTheme.bodySmall
                          ?.copyWith(color: t.colorScheme.error)),
                ],
                const SizedBox(height: ConsoleDensity.xl),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy ? 'Giriş yapılıyor…' : 'Giriş yap'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
