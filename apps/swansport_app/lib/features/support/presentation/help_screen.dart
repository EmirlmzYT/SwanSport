import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/swan_bottom_nav.dart';

/// Yardım — SSS ve destek talebi.
///
/// **Önce cevap, sonra talep.** Ekran SSS ile açılıyor ve destek talebi
/// düğmesi en altta. Tersi olsaydı herkes doğrudan talep açar, cevabı zaten
/// yazılı olan sorular kuyruğu doldururdu.
///
/// SSS içeriği veritabanında (`faq_entries`): yeni bir soru eklemek için APK
/// yayınlamak gerekmiyor. Arama sunucuda `tr_contains` ile — "aidat" ve
/// "AİDAT" aynı sonucu veriyor.
class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key});

  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends ConsumerState<HelpScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Kullanıcının rollerinden SSS kitlesi. Veliye antrenör sorusu
  /// göstermek, yardımı okunmaz yapıyor.
  List<String> _audience(SwanAccess a) => [
        if (a.isClubStaff) 'club_staff',
        if (a.isAccountant) 'accountant',
        if (a.coachLevel > 0) 'coach',
        if (a.isVerifiedAthlete) 'athlete',
        if (a.isParent) 'parent',
      ];

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final access = ref.watch(swanAccessProvider);
    // Açık bayraklar: kapalı bir özelliğin yardımı listede çıkmıyor.
    final flags =
        ref.watch(featureFlagsProvider).valueOrNull ?? const FeatureFlags.none();
    final key =
        '$_query|${_audience(access).join(',')}|${flags.enabled.join(',')}';
    final faq = ref.watch(faqProvider(key));

    return Scaffold(
      extendBody: true,
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(SwanSpace.lg, SwanSpace.md,
                    SwanSpace.lg, SwanSpace.md),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(SwanRadius.sm),
                          border: Border.all(color: c.line)),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 15, color: c.ink),
                    ),
                  ),
                  const SizedBox(width: SwanSpace.md),
                  Text('Yardım', style: SwanType.h2(c.ink)),
                ]),
              ),

              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
                child: Container(
                  height: 44,
                  padding:
                      const EdgeInsets.symmetric(horizontal: SwanSpace.md),
                  decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(SwanRadius.md),
                      border: Border.all(color: c.line)),
                  child: Row(children: [
                    Icon(Icons.search_rounded, size: 18, color: c.inkMuted),
                    const SizedBox(width: SwanSpace.sm),
                    Expanded(
                      child: TextField(
                        controller: _search,
                        style: SwanType.bodySm(c.ink),
                        textInputAction: TextInputAction.search,
                        onChanged: (v) =>
                            setState(() => _query = v.trim()),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'Sorununu yaz — aidat, bildirim, kort…',
                          hintStyle: SwanType.bodySm(c.inkMuted),
                        ),
                      ),
                    ),
                    if (_query.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                        child: Icon(Icons.close_rounded,
                            size: 17, color: c.inkMuted),
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: SwanSpace.md),

              Expanded(
                child: faq.when(
                  loading: premiumLoading,
                  error: (e, _) => premiumError(context, '$e'),
                  data: (list) => _list(context, list),
                ),
              ),
            ]),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _list(BuildContext context, List<FaqEntry> list) {
    final c = context.swan;

    // Kategoriye göre grupla; arama varken gruplama gürültü, düz liste.
    final grouped = <String, List<FaqEntry>>{};
    for (final f in list) {
      grouped.putIfAbsent(f.category, () => []).add(f);
    }

    return ListView(
      padding:
          const EdgeInsets.fromLTRB(SwanSpace.lg, 0, SwanSpace.lg, 132),
      children: [
        if (list.isEmpty)
          premiumEmpty(
            context,
            icon: Icons.help_outline_rounded,
            title: _query.isEmpty
                ? 'Yardım içeriği yok'
                : 'Bu aramaya uygun cevap yok',
            subtitle: _query.isEmpty
                ? 'Sıkça sorulan sorular henüz eklenmemiş.'
                : 'Başka bir kelime dene ya da aşağıdan destek talebi aç.',
          )
        else if (_query.isNotEmpty)
          for (final f in list) _FaqTile(entry: f)
        else
          for (final entry in grouped.entries) ...[
            Padding(
              padding: const EdgeInsets.only(
                  top: SwanSpace.md, bottom: SwanSpace.sm),
              child: Text(entry.key,
                  style: SwanType.caption(c.inkMuted, w: FontWeight.w800)),
            ),
            for (final f in entry.value) _FaqTile(entry: f),
          ],

        const SizedBox(height: SwanSpace.xl),

        // Talep açma en altta ve bilerek: cevabı zaten yazılı sorular
        // kuyruğu doldurmasın.
        Container(
          padding: const EdgeInsets.all(SwanSpace.lg),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(SwanRadius.md),
            border: Border.all(color: c.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cevabını bulamadın mı?',
                  style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'Destek talebi aç, sana buradan yanıt yazalım. Yazdığın '
                'metinden şifre, kart ve IBAN gibi bilgiler otomatik '
                'ayıklanıyor.',
                style: SwanType.caption(c.inkMuted),
              ),
              const SizedBox(height: SwanSpace.md),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/destek'),
                    child: Container(
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.accentFill,
                        borderRadius: BorderRadius.circular(SwanRadius.sm),
                      ),
                      child: Text('Destek taleplerim',
                          style: SwanType.bodySm(Colors.white,
                              w: FontWeight.w800)),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

/// Katlanabilir soru. Varsayılan kapalı — on soruyu açık göstermek, aradığı
/// soruyu bulmak isteyeni kaydırmaya mahkûm ediyordu.
class _FaqTile extends StatefulWidget {
  const _FaqTile({required this.entry});

  final FaqEntry entry;

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final f = widget.entry;

    return Container(
      margin: const EdgeInsets.only(bottom: SwanSpace.sm),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: c.line),
      ),
      child: Column(children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.all(SwanSpace.lg),
            child: Row(children: [
              Expanded(
                child: Text(f.question,
                    style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
              ),
              const SizedBox(width: SwanSpace.sm),
              Icon(
                  _open
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: c.inkMuted),
            ]),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                SwanSpace.lg, 0, SwanSpace.lg, SwanSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.answer,
                    style: SwanType.bodySm(c.inkMuted).copyWith(height: 1.5)),
                if (f.route != null) ...[
                  const SizedBox(height: SwanSpace.md),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, f.route!),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('İlgili ekrana git',
                          style:
                              SwanType.caption(c.accent, w: FontWeight.w800)),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded,
                          size: 14, color: c.accent),
                    ]),
                  ),
                ],
              ],
            ),
          ),
      ]),
    );
  }
}
