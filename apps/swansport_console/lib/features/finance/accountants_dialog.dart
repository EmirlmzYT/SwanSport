import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/theme/console_theme.dart';
import '../../app/widgets/status_pill.dart';
import 'money.dart';

/// Kulübün defterine kimin eriştiğini gösterir ve yönetir.
///
/// Bu ekran olmadan erişim verilebiliyor ama görülemiyordu: kulüp kimin
/// parasını gördüğünü bilmiyordu ve verdiği erişimi geri alamıyordu.
///
/// Yalnızca **kulüp yöneticisi** açabilir — sunucu da aynı şartı uyguluyor,
/// burada gizlemek tek başına koruma değil.
Future<void> showAccountantsDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (_) => const _AccountantsDialog(),
  );
}

class _AccountantsDialog extends ConsumerWidget {
  const _AccountantsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final accountants = ref.watch(clubAccountantsProvider);
    final invites = ref.watch(pendingAccountantInvitesProvider);

    return AlertDialog(
      title: const Text('Defter erişimi'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Buradaki kişiler kulübün gelir–gider defterini ve kasa '
                'bakiyelerini görür. Sporcu adlarını, sağlık ve performans '
                'verisini görmezler.',
                style: t.textTheme.bodySmall,
              ),
              const SizedBox(height: ConsoleDensity.xl),

              Text('ERİŞİMİ OLANLAR', style: t.textTheme.labelSmall),
              const SizedBox(height: ConsoleDensity.sm),
              accountants.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: ConsoleDensity.lg),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
                error: (e, _) => Text('Liste alınamadı: $e',
                    style: t.textTheme.bodySmall
                        ?.copyWith(color: t.colorScheme.error)),
                data: (list) => list.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: ConsoleDensity.md),
                        child: Text('Kimseye erişim verilmemiş.',
                            style: t.textTheme.bodySmall),
                      )
                    : Column(
                        children: [
                          for (final a in list) _Row(accountant: a),
                        ],
                      ),
              ),

              const SizedBox(height: ConsoleDensity.xl),
              Text('BEKLEYEN DAVETLER', style: t.textTheme.labelSmall),
              const SizedBox(height: ConsoleDensity.sm),
              invites.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (list) => list.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: ConsoleDensity.md),
                        child: Text('Bekleyen davet yok.',
                            style: t.textTheme.bodySmall),
                      )
                    : Column(
                        children: [for (final i in list) _InviteRow(invite: i)],
                      ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Kapat'),
        ),
        FilledButton.icon(
          onPressed: () => _invite(context, ref),
          icon: const Icon(Icons.person_add_rounded, size: 17),
          label: const Text('Muhasebeci davet et'),
        ),
      ],
    );
  }

  Future<void> _invite(BuildContext context, WidgetRef ref) async {
    final emailCtrl = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Muhasebeci davet et'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: emailCtrl,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Muhasebecinin e-postası',
                  hintText: 'ornek@muhasebe.com',
                ),
              ),
              const SizedBox(height: ConsoleDensity.md),
              Text(
                'E-posta yazarsan kodu yalnızca o hesap kullanabilir. Boş '
                'bırakırsan kodu eline geçiren herkes kullanabilir — mali '
                'erişim için yazmanı öneririm.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Kod üret')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final club = await ref.read(activeClubProvider.future);
      if (club == null) return;

      final code = await ref
          .read(expenseServiceProvider)
          .createAccountantInvite(club.id, email: emailCtrl.text);

      ref.invalidate(pendingAccountantInvitesProvider);

      if (context.mounted) {
        await _showCode(context, code, emailCtrl.text.trim());
      }
    } catch (e) {
      // Sunucu kulüp yöneticisi olmayanı reddediyor; mesajı olduğu gibi göster.
      messenger.showSnackBar(SnackBar(content: Text('Davet üretilemedi: $e')));
    }
  }

  Future<void> _showCode(
      BuildContext context, String code, String email) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final t = Theme.of(ctx);
        return AlertDialog(
          title: const Text('Davet kodu hazır'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(ConsoleDensity.lg),
                  decoration: BoxDecoration(
                    color: t.colorScheme.primary.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(ConsoleDensity.radius),
                    border: Border.all(
                        color: t.colorScheme.primary.withValues(alpha: .3)),
                  ),
                  child: SelectableText(
                    code,
                    textAlign: TextAlign.center,
                    style: t.textTheme.titleLarge?.copyWith(
                      letterSpacing: 4,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(height: ConsoleDensity.lg),
                Text(
                  email.isEmpty
                      ? 'Kod 48 saat geçerli, tek kullanımlık. Kodu eline '
                          'geçiren herkes kullanabilir.'
                      : '$email adresine ilet. Kod 48 saat geçerli ve '
                          'yalnızca o hesap kullanabilir.',
                  style: t.textTheme.bodySmall,
                ),
                const SizedBox(height: ConsoleDensity.sm),
                Text(
                  'Muhasebeci uygulamada Doğrulama ekranından bu kodu girer.',
                  style: t.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                Navigator.pop(ctx);
              },
              child: const Text('Kopyala ve kapat'),
            ),
          ],
        );
      },
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row({required this.accountant});

  final AccountantRef accountant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ConsoleDensity.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(accountant.name, style: t.textTheme.bodyMedium),
                Text(
                  [
                    if (accountant.username != null) '@${accountant.username}',
                    if (accountant.since != null)
                      '${fmtDate(accountant.since!)} tarihinden beri',
                  ].join(' · '),
                  style: t.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          StatusPill(
            label: accountant.isActive ? 'Erişimi var' : 'Kaldırıldı',
            tone: accountant.isActive ? PillTone.good : PillTone.muted,
          ),
          const SizedBox(width: ConsoleDensity.md),
          if (accountant.isActive)
            TextButton(
              onPressed: () => _revoke(context, ref),
              style:
                  TextButton.styleFrom(foregroundColor: t.colorScheme.error),
              child: const Text('Erişimi kaldır'),
            )
          else
            TextButton(
              onPressed: () => _restore(context, ref),
              child: const Text('Geri ver'),
            ),
        ],
      ),
    );
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Erişim kaldırılsın mı?'),
        content: Text(
          '${accountant.name} artık kulübün defterini, kasa bakiyelerini ve '
          'mali raporlarını göremeyecek.\n\n'
          'Kayıt silinmiyor; istersen sonra geri verebilirsin.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Kaldır'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final club = await ref.read(activeClubProvider.future);
      if (club == null) return;
      await ref
          .read(expenseServiceProvider)
          .revokeAccountant(club.id, accountant.profileId);
      ref.invalidate(clubAccountantsProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Kaldırılamadı: $e')));
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final club = await ref.read(activeClubProvider.future);
      if (club == null) return;
      await ref
          .read(expenseServiceProvider)
          .restoreAccountant(club.id, accountant.profileId);
      ref.invalidate(clubAccountantsProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Geri verilemedi: $e')));
    }
  }
}

class _InviteRow extends StatelessWidget {
  const _InviteRow({required this.invite});

  final PendingInvite invite;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final hours = invite.remaining.inHours;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ConsoleDensity.sm),
      child: Row(
        children: [
          SelectableText(
            invite.code,
            style: t.textTheme.bodyMedium?.copyWith(
              letterSpacing: 2,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: ConsoleDensity.md),
          Expanded(
            child: Text(
              invite.targetEmail ?? 'Herkese açık kod',
              overflow: TextOverflow.ellipsis,
              style: t.textTheme.bodySmall,
            ),
          ),
          StatusPill(
            label: hours < 1 ? '1 saatten az' : '$hours saat kaldı',
            tone: hours < 6 ? PillTone.warning : PillTone.info,
          ),
          const SizedBox(width: ConsoleDensity.sm),
          IconButton(
            tooltip: 'Kodu kopyala',
            icon: const Icon(Icons.copy_rounded, size: 16),
            onPressed: () =>
                Clipboard.setData(ClipboardData(text: invite.code)),
          ),
        ],
      ),
    );
  }
}
