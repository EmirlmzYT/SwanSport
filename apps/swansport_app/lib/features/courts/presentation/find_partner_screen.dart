import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/location/place.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/swan_tabs.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/design/swan_palette.dart';

/// Kort partneri arama.
///
/// Kort sisteminin doğal tamamlayıcısı: partner bul → beraber saat alın.
/// Saat almadan da çalışır — "şimdi/yakında oynamak istiyorum" demek için
/// önce bir saat almış olman gerekmiyor, `open_slots`'un aksine.
///
/// AYRILABİLİRLİK: kulüp kavramı geçmez.
class FindPartnerScreen extends ConsumerStatefulWidget {
  const FindPartnerScreen({this.initialTab = 0, super.key});

  /// 0 = Partner ara, 1 = Oyuncu aranan oyunlar.
  ///
  /// Eski `/oyuncu-aranan` rotası korunuyor ve ikinci sekmeye açılıyor.
  final int initialTab;

  @override
  ConsumerState<FindPartnerScreen> createState() => _FindPartnerScreenState();
}

class _FindPartnerScreenState extends ConsumerState<FindPartnerScreen> {
  late int _tab = widget.initialTab;
  String? _selectedSport;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = (isDark ? SwanPalette.dark : SwanPalette.light).bg;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;

    final access = ref.watch(swanAccessProvider);
    final verified = access.hasVerificationTier('location');
    final sports = ref.watch(courtSportCodesProvider);
    final interests = ref.watch(mySportInterestsProvider);
    final myRequest = ref.watch(myOpenPartnerRequestProvider);
    final inbox = ref.watch(incomingPartnerPingsProvider);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text('Partner Bul', style: SwanType.h3(ink)),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: SwanSegmentedTabs(
            labels: const ['Partner ara', 'Oyuncu aranan'],
            selected: _tab,
            onSelect: (i) => setState(() => _tab = i),
          ),
        ),
        // IndexedStack: sekme değişince doldurulmuş form (seçili branş)
        // kaybolmasın diye gövde canlı tutuluyor.
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: [
              _seekTab(isDark, ink, verified, sports, interests, myRequest, inbox),
              _openSlotsTab(isDark, ink, verified),
            ],
          ),
        ),
      ]),
    );
  }

  // ------------------------------- sekmeler --------------------------------

  Widget _seekTab(
    bool isDark,
    Color ink,
    bool verified,
    AsyncValue<List<CityRow>> sports,
    AsyncValue<Set<String>> interests,
    AsyncValue<MyPartnerRequest?> myRequest,
    AsyncValue<List<IncomingPartnerPing>> inbox,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myOpenPartnerRequestProvider);
        ref.invalidate(incomingPartnerPingsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          if (!verified) _verifyBanner(isDark, ink),
          _sectionTitle(ink, 'Gelen istekler'),
          const SizedBox(height: 8),
          inbox.when(
            loading: premiumLoading,
            error: (e, _) => premiumError(context, '$e'),
            data: (pings) => pings.isEmpty
                ? _emptyLine('Şu an sana gelen bir istek yok.')
                : Column(children: [
                    for (final p in pings) _pingCard(isDark, ink, p),
                  ]),
          ),
          const SizedBox(height: 22),
          _sectionTitle(ink, 'Benim isteğim'),
          const SizedBox(height: 8),
          myRequest.when(
            loading: premiumLoading,
            error: (e, _) => premiumError(context, '$e'),
            data: (req) => req == null
                ? _seekForm(context, isDark, ink, verified, sports, interests)
                : _myRequestCard(isDark, ink, req),
          ),
        ],
      ),
    );
  }

  Widget _openSlotsTab(bool isDark, Color ink, bool verified) {
    final async = ref.watch(openSlotsProvider(null));
    return async.when(
      loading: premiumLoading,
      error: (e, _) => premiumError(context, '$e'),
      data: (slots) {
        if (slots.isEmpty) {
          return premiumEmpty(
            context,
            icon: Icons.group_add_rounded,
            title: 'Şu an oyuncu arayan yok',
            subtitle:
                'Sen saat alırken "oyuncu arıyorum" dersen burada görünürsün.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(openSlotsProvider(null)),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            itemCount: slots.length,
            itemBuilder: (_, i) =>
                _openSlotCard(isDark, ink, slots[i], verified),
          ),
        );
      },
    );
  }

  Widget _openSlotCard(bool isDark, Color ink, OpenSlot s, bool verified) {
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;

    final hour = '${s.startsAt.hour.toString().padLeft(2, '0')}:'
        '${s.startsAt.minute.toString().padLeft(2, '0')}';
    final where = [
      if ((s.venue ?? '').isNotEmpty) s.venue!,
      if ((s.cityName ?? '').isNotEmpty) s.cityName!,
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$hour · ${s.courtName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SwanType.bodySm(ink, w: FontWeight.w800)),
                const SizedBox(height: 3),
                Text([s.ownerName, if (where.isNotEmpty) where].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
              ],
            ),
          ),
          PremiumStatusChip(
              label: '${s.remaining} kişi',
              color: SwanPalette.light.warning,
              icon: Icons.group_add_rounded),
        ]),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: (s.requested || !verified)
              ? null
              : () async {
                  try {
                    await ref.read(courtServiceProvider).requestJoin(s.slotId);
                    ref.invalidate(openSlotsProvider(null));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'İsteğin gönderildi. Sahibi onaylayınca haber vereceğiz.')));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('$e')));
                    }
                  }
                },
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: (s.requested || !verified)
                  ? null
                  : const LinearGradient(colors: [kTealBright, kTeal]),
              borderRadius: BorderRadius.circular(12),
              border: (s.requested || !verified)
                  ? Border.all(color: line)
                  : null,
            ),
            child: Text(
                s.requested
                    ? 'İstek gönderildi'
                    : (verified
                        ? 'Katılmak istiyorum'
                        : 'Önce kortta doğrulanmalısın'),
                style: SwanType.caption(
                    (s.requested || !verified)
                        ? context.swan.inkMuted
                        : Colors.white,
                    w: FontWeight.w800)),
          ),
        ),
      ]),
    );
  }

  Widget _sectionTitle(Color ink, String text) =>
      Text(text, style: SwanType.bodySm(ink, w: FontWeight.w800));

  Widget _emptyLine(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(text,
            style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
      );

  Widget _verifyBanner(bool isDark, Color ink) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kTeal.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: kTeal.withValues(alpha: .25)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Partner aramak için önce bir kortu doğrula',
              style: SwanType.bodySm(ink, w: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(
              'Herhangi bir kortta bir kez "kortta olduğumu doğrula" dedikten '
              'sonra buradan partner arayabilirsin. Bu, sahte hesapların '
              'bildirimlerle seni rahatsız etmesini engelliyor.',
              style:
                  SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
        ]),
      );

  Widget _pingCard(bool isDark, Color ink, IncomingPartnerPing p) {
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;

    Widget button(String text, VoidCallback onTap,
            {bool filled = true, Color color = kTeal}) =>
        GestureDetector(
          onTap: _busy ? null : onTap,
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: filled ? color : color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(text,
                style: SwanType.caption(filled ? Colors.white : color, w: FontWeight.w800)),
          ),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: SwanPalette.light.warning.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.handshake_rounded,
              color: SwanPalette.light.warning, size: 20),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${p.requesterName} · ${p.sportName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SwanType.bodySm(ink, w: FontWeight.w800)),
              Text('Müsait misin, gitmek ister misin?',
                  style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        button('Kabul', () => _respond(p.requestId, true)),
        const SizedBox(width: 6),
        button('Ret', () => _respond(p.requestId, false),
            filled: false, color: const Color(0xFFD64545)),
      ]),
    );
  }

  Widget _seekForm(
    BuildContext context,
    bool isDark,
    Color ink,
    bool verified,
    AsyncValue<List<CityRow>> sports,
    AsyncValue<Set<String>> interests,
  ) {
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
      ),
      child: sports.when(
        loading: premiumLoading,
        error: (e, _) => premiumError(context, '$e'),
        data: (sportList) {
          if (sportList.isEmpty) {
            return Text(
                'Henüz hiçbir kortta branş tanımlı değil — partner arama '
                'yakında burada olacak.',
                style:
                    SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600));
          }

          final myInterests = interests.valueOrNull ?? {};
          _selectedSport ??=
              myInterests.isNotEmpty ? myInterests.first : sportList.first.code;

          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('İlgilendiğin branşlar',
                style: SwanType.caption(ink, w: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Seçtiğin branşlarda başkası partner arayınca haber verilir.',
                style:
                    SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in sportList)
                  _chip(isDark, ink, s.name,
                      selected: myInterests.contains(s.code),
                      onTap: () => _toggleInterest(s.code,
                          !myInterests.contains(s.code))),
              ],
            ),
            const SizedBox(height: 18),
            Text('Partner arıyorum', style: SwanType.caption(ink, w: FontWeight.w800)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in sportList)
                  _chip(isDark, ink, s.name,
                      selected: _selectedSport == s.code,
                      onTap: () => setState(() => _selectedSport = s.code)),
              ],
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: (_busy || !verified) ? null : _seek,
              child: Container(
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: verified
                      ? const LinearGradient(colors: [kTealBright, kTeal])
                      : null,
                  color: verified ? null : line,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(_busy ? 'Aranıyor…' : 'Partner Arıyorum',
                    style: SwanType.bodySm(verified ? Colors.white : SwanColors.textSecondary, w: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
                'Yakınındaki ilgili kişilere bildirim gider. İki saat içinde '
                'kimse kabul etmezse istek kendiliğinden düşer.',
                style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
          ]);
        },
      ),
    );
  }

  Widget _myRequestCard(bool isDark, Color ink, MyPartnerRequest req) {
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;

    if (req.isMatched) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kTeal.withValues(alpha: .4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${req.sportName} · partnerin bulundu',
              style: SwanType.bodySm(ink, w: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${req.acceptedByName} müsait olduğunu söyledi.',
              style:
                  SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/sohbet', arguments: {
              'id': req.acceptedBy,
              'name': req.acceptedByName,
            }),
            child: Container(
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [kTealBright, kTeal]),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text('Sohbete geç',
                  style: SwanType.bodySm(Colors.white, w: FontWeight.w800)),
            ),
          ),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${req.sportName} için aranıyor',
                  style: SwanType.bodySm(ink, w: FontWeight.w800)),
              const SizedBox(height: 3),
              Text('Yanıt gelene kadar bekleniyor.',
                  style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
            ],
          ),
        ),
        GestureDetector(
          onTap: _busy ? null : () => _cancel(req.id),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFD64545).withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('İptal et',
                style: SwanType.caption(const Color(0xFFD64545),
                    w: FontWeight.w800)),
          ),
        ),
      ]),
    );
  }

  Widget _chip(bool isDark, Color ink, String label,
      {required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kTeal : (isDark ? SwanPalette.dark.surfaceAlt : const Color(0xFFF4F7FA)),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(label,
            style: SwanType.caption(selected ? Colors.white : ink, w: FontWeight.w700)),
      ),
    );
  }

  // ------------------------------- eylemler --------------------------------

  Future<void> _toggleInterest(String sportCode, bool interested) async {
    try {
      await ref
          .read(courtServiceProvider)
          .setSportInterest(sportCode, interested);
      ref.invalidate(mySportInterestsProvider);
    } catch (e) {
      _say(_readable(e));
    }
  }

  Future<void> _seek() async {
    final sport = _selectedSport;
    if (sport == null) return;

    setState(() => _busy = true);
    try {
      final place = await currentPlaceOrNull();
      await ref.read(courtServiceProvider).seekPartner(
            sportCode: sport,
            lat: place?.lat,
            lng: place?.lng,
          );
      ref.invalidate(myOpenPartnerRequestProvider);
      _say('İstek gönderildi — yakınındaki ilgili kişilere haber gitti.');
    } catch (e) {
      _say(_readable(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(String id) async {
    setState(() => _busy = true);
    try {
      await ref.read(courtServiceProvider).cancelPartnerRequest(id);
      ref.invalidate(myOpenPartnerRequestProvider);
    } catch (e) {
      _say(_readable(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _respond(String requestId, bool accept) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(courtServiceProvider)
          .respondPartnerPing(requestId: requestId, accept: accept);
      ref.invalidate(incomingPartnerPingsProvider);
      _say(accept ? 'Kabul edildi.' : 'Reddedildi.');
    } catch (e) {
      _say(_readable(e));
      ref.invalidate(incomingPartnerPingsProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _readable(Object e) {
    final text = '$e';
    final match = RegExp(r'message: ([^,]+)').firstMatch(text);
    return match?.group(1)?.trim() ?? 'Bir şeyler ters gitti.';
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
