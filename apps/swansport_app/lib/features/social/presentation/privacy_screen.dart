import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../../app/widgets/swan_page_header.dart';
import '../../auth/application/auth_controller.dart';

/// Profil Güvenlik Merkezi — rol tabanlı yetkiler, kimlik doğrulama, gizlilik ve hesap (Stitch Calm Athletic Modernism).
class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});

  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final blocks = ref.watch(myBlocksProvider);
    return Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                            SwanSpace.lg, SwanSpace.md, SwanSpace.lg, 132),
                        children: [
                          SwanPageHeader(
                              title: 'Gizlilik ve güvenlik',
                              onBack: () => Navigator.maybePop(context)),
                          const SizedBox(height: SwanSpace.lg),
                          Text('Etiketlenme', style: SwanType.h3(c.ink)),
                          Text(
                              'Seni kim gönderilerde etiketleyebilir. Engellediğin kişiler etiketleyemez.',
                              style: SwanType.bodySm(c.inkMuted)),
                          _MentionPolicyPicker(isDark: c.isDark),
                          const SizedBox(height: SwanSpace.lg),
                          Text('Engellenenler', style: SwanType.h3(c.ink)),
                          blocks.when(
                              loading: premiumLoading,
                              error: (e, _) => premiumError(context, '$e'),
                              data: (rows) => rows.isEmpty
                                  ? Text('Engellediğin kimse bulunmuyor.',
                                      style: SwanType.bodySm(c.inkMuted))
                                  : Column(children: [
                                      for (final row in rows)
                                        ListTile(
                                            title: Text(row.name),
                                            trailing: TextButton(
                                                onPressed: () async {
                                                  try {
                                                    await ref
                                                        .read(
                                                            moderationServiceProvider)
                                                        .unblock(row.id);
                                                    ref.invalidate(
                                                        myBlocksProvider);
                                                  } catch (e) {
                                                    if (context.mounted)
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(SnackBar(
                                                              content: Text(
                                                                  'Engel kaldırılamadı: $e')));
                                                  }
                                                },
                                                child: const Text(
                                                    'Engeli kaldır')))
                                    ])),
                          const Divider(),
                          ListTile(
                              title: const Text('Şifremi değiştir'),
                              leading: const Icon(Icons.password),
                              onTap: _changePassword),
                          ListTile(
                              title: const Text('Lisans ve kimlik doğrulama'),
                              leading: const Icon(Icons.badge_outlined),
                              onTap: () =>
                                  Navigator.pushNamed(context, '/dogrulama')),
                          ListTile(
                              title: const Text('Hesabımı sil'),
                              leading:
                                  Icon(Icons.delete_outline, color: c.danger),
                              onTap: _deleteAccount),
                        ])))),
        bottomNavigationBar: const SwanBottomNav());
  }

  Future<void> _changePassword() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.swan.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('Yeni Şifre', style: SwanType.h3(context.swan.ink)),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          autofocus: true,
          style: SwanType.bodySm(context.swan.ink),
          decoration: const InputDecoration(
            hintText: 'En az 6 karakter',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                Text('Vazgeç', style: SwanType.bodySm(context.swan.inkMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Kaydet',
                style:
                    SwanType.bodySm(context.swan.accent, w: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final done = await ref
        .read(authControllerProvider.notifier)
        .updatePassword(ctrl.text);
    if (!mounted) return;
    final msg = ref.read(authControllerProvider).errorMessage;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(done ? 'Şifren güncellendi' : (msg ?? 'Güncellenemedi')),
        backgroundColor: done ? context.swan.accent : SwanPalette.light.danger,
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final confirm = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.swan.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('Emin misin?', style: SwanType.h3(context.swan.ink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bu işlem geri alınamaz. Onaylamak için aşağıya “SİL” yaz.',
              style: SwanType.bodySm(context.swan.inkMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirm,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              style: SwanType.bodySm(context.swan.ink, w: FontWeight.w800),
              decoration: const InputDecoration(hintText: 'SİL'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Vazgeç',
                style:
                    SwanType.bodySm(context.swan.inkMuted, w: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Hesabımı sil',
                style: SwanType.bodySm(SwanPalette.light.danger,
                    w: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (confirm.text.trim().toUpperCase() != 'SİL') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Onay metni eşleşmedi'),
            backgroundColor: SwanPalette.light.warning,
          ),
        );
      }
      return;
    }

    try {
      await ref.read(moderationServiceProvider).deleteMyAccount();
      await ref.read(authControllerProvider.notifier).signOut();
      if (mounted) {
        unawaited(
            Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Silinemedi: $e'),
            backgroundColor: SwanPalette.light.danger,
          ),
        );
      }
    }
  }
}

/// Etiketlenme izni seçici.
class _MentionPolicyPicker extends ConsumerStatefulWidget {
  const _MentionPolicyPicker({required this.isDark});

  final bool isDark;

  @override
  ConsumerState<_MentionPolicyPicker> createState() =>
      _MentionPolicyPickerState();
}

class _MentionPolicyPickerState extends ConsumerState<_MentionPolicyPicker> {
  MentionPolicy? _value;
  String? _loadError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loadError = null);
    try {
      final value = await ref.read(socialShareServiceProvider).mentionPolicy();
      if (mounted) setState(() => _value = value);
    } catch (_) {
      if (mounted) setState(() => _loadError = 'Etiketlenme ayarı alınamadı.');
    }
  }

  Future<void> _set(MentionPolicy p) async {
    setState(() => _busy = true);
    try {
      await ref.read(socialShareServiceProvider).setPrivacy(mention: p);
      if (mounted) setState(() => _value = p);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    if (_loadError != null)
      return Column(children: [
        Text(_loadError!),
        TextButton(onPressed: _load, child: const Text('Yeniden dene'))
      ]);
    if (_value == null) return const LinearProgressIndicator();

    return Column(
      children: [
        for (final p in MentionPolicy.values)
          GestureDetector(
            onTap: _busy || _value == p ? null : () => _set(p),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _value == p ? c.accent : c.line,
                  width: _value == p ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _value == p
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 19,
                    color: _value == p ? c.accent : c.inkMuted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(mentionPolicyLabel(p),
                        style: SwanType.bodySm(c.ink)),
                  ),
                  if (_busy && _value != p)
                    const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
