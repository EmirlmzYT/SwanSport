import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/swan_bottom_nav.dart';

/// Sporcunun antrenman geçmişi ve bireysel antrenman başlatma.
///
/// BİREYSEL ANTRENMAN YALNIZCA SPORCUNUN KENDİSİNE GÖRÜNÜYOR — antrenör,
/// kulüp yöneticisi ve veli görmüyor. Bunu bu ekran değil RLS sağlıyor
/// (0071, `kind = 'personal'` dalı); buradaki "Bireysel" rozeti sporcuya
/// bunu **hatırlatmak** için, gizlemek için değil.
class MyTrainingScreen extends ConsumerWidget {
  const MyTrainingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.swan;
    final history = ref.watch(myTrainingHistoryProvider);
    final live = ref.watch(myLiveSessionProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(myTrainingHistoryProvider);
                ref.invalidate(myLiveSessionProvider);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    SwanSpace.lg, SwanSpace.md, SwanSpace.lg, 120),
                children: [
                  Row(children: [
                    GestureDetector(
                      onTap: () => Navigator.maybePop(context),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(SwanRadius.sm),
                          border: Border.all(color: c.line),
                        ),
                        child: Icon(Icons.arrow_back_ios_new_rounded,
                            size: 15, color: c.ink),
                      ),
                    ),
                    const SizedBox(width: SwanSpace.md),
                    Text('Antrenmanlarım', style: SwanType.h2(c.ink)),
                  ]),
                  const SizedBox(height: SwanSpace.lg),

                  // Canlı oturum varsa en üstte — sahada aranacak ilk şey bu.
                  live.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (s) => s == null
                        ? const SizedBox.shrink()
                        : _liveCard(context, c, s),
                  ),

                  _actions(context, ref, c),
                  const SizedBox(height: SwanSpace.xl),

                  Text('Geçmiş', style: SwanType.h3(c.ink)),
                  const SizedBox(height: SwanSpace.sm),
                  history.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) =>
                        Text('$e', style: SwanType.bodySm(c.danger)),
                    data: (list) => list.isEmpty
                        ? Text(
                            'Henüz antrenman kaydın yok. Antrenörün bir oturum '
                            'başlattığında ya da kendi başına antrenman '
                            'yaptığında burada görünecek.',
                            style: SwanType.bodySm(c.inkMuted))
                        : Column(children: [
                            for (final h in list) _row(context, c, h),
                          ]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _liveCard(BuildContext context, SwanPalette c, TrainingSession s) =>
      Container(
        margin: const EdgeInsets.only(bottom: SwanSpace.lg),
        padding: const EdgeInsets.all(SwanSpace.lg),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(SwanRadius.lg),
          border: Border.all(color: c.accent),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Şu an canlı', style: SwanType.caption(c.accent)),
          const SizedBox(height: SwanSpace.xs),
          Text(s.protocolName, style: SwanType.h3(c.ink)),
          Text('${s.phase.label} · Set ${s.currentSet}/${s.setCount}',
              style: SwanType.bodySm(c.inkMuted)),
          const SizedBox(height: SwanSpace.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pushNamed(
                  context, '/antrenman-oturumu',
                  arguments: {'id': s.id}),
              style: FilledButton.styleFrom(backgroundColor: c.accent),
              child: const Text('Oturuma dön'),
            ),
          ),
        ]),
      );

  Widget _actions(BuildContext context, WidgetRef ref, SwanPalette c) =>
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _joinDialog(context, ref),
            icon: const Icon(Icons.login_rounded, size: 18),
            label: Text('Kodla katıl', style: SwanType.bodySm(c.ink)),
          ),
        ),
        const SizedBox(width: SwanSpace.sm),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _startPersonal(context, ref),
            icon: const Icon(Icons.self_improvement_rounded, size: 18),
            label: Text('Kendi başıma', style: SwanType.bodySm(c.ink)),
          ),
        ),
      ]);

  /// Katılım kodu ile giriş.
  ///
  /// Kamera okuyucu yok — kod her yerde ve web'de çalışıyor. Kod doğru olsa
  /// bile başka kulübün oturumuna girilemiyor; kapsamı sunucu kesiyor.
  void _joinDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    String? error;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Oturuma katıl'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Antrenörün ekranındaki 6 haneli kodu yaz.'),
            const SizedBox(height: SwanSpace.md),
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: 'ABC123'),
            ),
            if (error != null) ...[
              const SizedBox(height: SwanSpace.sm),
              Text(error!, style: TextStyle(color: ctx.swan.danger)),
            ],
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Vazgeç')),
            FilledButton(
              onPressed: () async {
                try {
                  final id = await ref
                      .read(trainingSessionServiceProvider)
                      .joinByCode(ctrl.text);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ref.invalidate(myLiveSessionProvider);
                    Navigator.pushNamed(context, '/antrenman-oturumu',
                        arguments: {'id': id});
                  }
                } catch (e) {
                  setState(() => error = _clean('$e'));
                }
              },
              child: const Text('Katıl'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startPersonal(BuildContext context, WidgetRef ref) async {
    final protocols = await ref.read(trainingProtocolsProvider.future);
    if (!context.mounted) return;
    if (protocols.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kullanılabilir şablon yok')));
      return;
    }

    final picked = await showModalBottomSheet<TrainingProtocol>(
      context: context,
      builder: (ctx) {
        final c = ctx.swan;
        return SafeArea(
          child: ListView(shrinkWrap: true, children: [
            Padding(
              padding: const EdgeInsets.all(SwanSpace.lg),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bireysel antrenman', style: SwanType.h3(c.ink)),
                    const SizedBox(height: SwanSpace.xs),
                    Text('Bu kayıt yalnızca senin geçmişinde görünür.',
                        style: SwanType.caption(c.inkMuted)),
                  ]),
            ),
            for (final p in protocols)
              ListTile(
                title: Text(p.name, style: SwanType.body(c.ink)),
                subtitle: Text(
                    '${p.config.setCount} set × ${p.config.unitsPerSet}',
                    style: SwanType.caption(c.inkMuted)),
                onTap: () => Navigator.pop(ctx, p),
              ),
            const SizedBox(height: SwanSpace.md),
          ]),
        );
      },
    );
    if (picked == null || !context.mounted) return;

    try {
      final id = await ref
          .read(trainingSessionServiceProvider)
          .startPersonalSession(protocolId: picked.id);
      if (context.mounted) {
        ref.invalidate(myTrainingHistoryProvider);
        Navigator.pushNamed(context, '/antrenman-oturumu',
            arguments: {'id': id});
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_clean('$e'))));
      }
    }
  }

  Widget _row(BuildContext context, SwanPalette c, TrainingHistoryEntry h) =>
      GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/antrenman-oturumu',
            arguments: {'id': h.sessionId}),
        child: Container(
          margin: const EdgeInsets.only(bottom: SwanSpace.sm),
          padding: const EdgeInsets.all(SwanSpace.md),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(SwanRadius.md),
            border: Border.all(color: c.line),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(h.protocolName, style: SwanType.body(c.ink)),
                    const SizedBox(height: 2),
                    Text(
                      '${_date(h.startedAt)}  ·  ${h.kindLabel}'
                      '  ·  ${h.setsDone}/${h.setCount} set',
                      style: SwanType.caption(c.inkMuted),
                    ),
                  ]),
            ),
            Text(
              h.totalScore == null ? '—' : _num(h.totalScore!),
              style: SwanType.h3(h.totalScore == null ? c.inkMuted : c.ink),
            ),
          ]),
        ),
      );

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  static String _num(num v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  /// Postgres hata metnindeki teknik önekleri temizle — kullanıcıya
  /// `PostgrestException(message: ...)` göstermenin anlamı yok.
  static String _clean(String raw) {
    final m = RegExp(r'message:\s*([^,)]+)').firstMatch(raw);
    return m?.group(1)?.trim() ?? raw;
  }
}
