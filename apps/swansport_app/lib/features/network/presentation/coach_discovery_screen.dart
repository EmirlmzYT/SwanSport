import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../../app/widgets/swan_chip.dart';

/// Antrenör keşfi.
///
/// Yalnızca **doğrulanmış** ve **görünmeyi kabul etmiş** antrenörler
/// listeleniyor. İkisi ayrı: doğrulanmış olmak, talep almak istemekle aynı
/// şey değil — kulübünde dolu çalışan bir antrenörü istemediği taleplere
/// açmak ona zarar verir.
///
/// **Puan ve yorum yok.** Doğrulanabilir bir hizmet kaydı olmadan yıldız
/// toplamak manipülasyona açık; kimin gerçekten ders aldığını bilmeden
/// verilen puan, puan olmaktan çıkıyor.
///
/// İletişim mevcut DM üzerinden — ödeme, sözleşme ve randevu yok.
class CoachDiscoveryScreen extends ConsumerStatefulWidget {
  const CoachDiscoveryScreen({super.key});

  @override
  ConsumerState<CoachDiscoveryScreen> createState() =>
      _CoachDiscoveryScreenState();
}

class _CoachDiscoveryScreenState extends ConsumerState<CoachDiscoveryScreen> {
  final _search = TextEditingController();
  String? _query;
  String? _sport;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final sports = ref.watch(sportsProvider).valueOrNull ?? const [];
    final results = ref.watch(
        coachSearchProvider((query: _query, sport: _sport, city: null)));

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
                padding: const EdgeInsets.fromLTRB(
                    SwanSpace.lg, SwanSpace.md, SwanSpace.lg, SwanSpace.md),
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
                  Text('Antrenör bul', style: SwanType.h2(c.ink)),
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
                        onSubmitted: (v) =>
                            setState(() => _query = v.trim().isEmpty ? null : v.trim()),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'İsim ara',
                          hintStyle: SwanType.bodySm(c.inkMuted),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),

              const SizedBox(height: SwanSpace.sm),
              if (sports.isNotEmpty)
                SwanChipBar(children: [
                  for (final s in sports.take(12))
                    SwanChip(
                      label: s.name,
                      selected: _sport == s.code,
                      onTap: () => setState(
                          () => _sport = _sport == s.code ? null : s.code),
                    ),
                ]),
              const SizedBox(height: SwanSpace.md),

              Expanded(
                child: results.when(
                  loading: premiumLoading,
                  error: (e, _) => premiumError(context, '$e'),
                  data: (list) => list.isEmpty
                      ? premiumEmpty(
                          context,
                          icon: Icons.sports_rounded,
                          title: 'Antrenör bulunamadı',
                          subtitle: _sport == null && _query == null
                              ? 'Henüz keşfedilmeyi açan antrenör yok.'
                              : 'Aramayı veya branşı değiştirip tekrar dene.',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                              SwanSpace.lg, 0, SwanSpace.lg, 132),
                          itemCount: list.length,
                          itemBuilder: (_, i) => _card(c, list[i]),
                        ),
                ),
              ),
            ]),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _card(SwanPalette c, CoachResult k) => Container(
        margin: const EdgeInsets.only(bottom: SwanSpace.md),
        padding: const EdgeInsets.all(SwanSpace.lg),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(SwanRadius.md),
          border: Border.all(color: c.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(k.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
                  Row(children: [
                    Icon(Icons.verified_rounded, size: 12, color: c.accent),
                    const SizedBox(width: 4),
                    Text(
                        [k.levelLabel, k.cityCode]
                            .where((e) => (e ?? '').isNotEmpty)
                            .join(' · '),
                        style: SwanType.caption(c.inkMuted)),
                  ]),
                ],
              ),
            ),
            GestureDetector(
              // Ödeme, randevu ve sözleşme yok: ilk aşamada yalnızca
              // konuşma. Plan da böyle istiyor.
              onTap: () => Navigator.pushNamed(context, '/sohbet',
                  arguments: {'id': k.profileId, 'name': k.fullName}),
              child: Container(
                height: 36,
                padding:
                    const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.accentFill,
                  borderRadius: BorderRadius.circular(SwanRadius.sm),
                ),
                child: Text('Yaz',
                    style:
                        SwanType.caption(Colors.white, w: FontWeight.w800)),
              ),
            ),
          ]),
          if ((k.bio ?? '').isNotEmpty) ...[
            const SizedBox(height: SwanSpace.sm),
            Text(k.bio!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: SwanType.caption(c.inkMuted)),
          ],
          if (k.sports.isNotEmpty) ...[
            const SizedBox(height: SwanSpace.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in k.sports)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.surfaceAlt,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(s, style: SwanType.caption(c.inkMuted)),
                  ),
              ],
            ),
          ],
        ]),
      );
}
