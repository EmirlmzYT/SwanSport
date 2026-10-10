import '../../../app/widgets/action_gate.dart';
import 'package:flutter/material.dart';
import '../../../app/design/swan_shape.dart';
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
  bool _isPublic = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = (isDark ? SwanPalette.dark : SwanPalette.light).bg;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;

    final access = ref.watch(swanAccessProvider);
    final verified = access.hasVerificationTier('phone');
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
          padding: const EdgeInsets.fromLTRB(SwanSpace.lg, 4, SwanSpace.lg, 12),
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
              _seekTab(
                  isDark, ink, verified, sports, interests, myRequest, inbox),
              _openSlotsTab(isDark, ink),
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
        ref.invalidate(publicPartnerRequestsProvider);
        ref.invalidate(myOpenPartnerRequestProvider);
        ref.invalidate(incomingPartnerPingsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(SwanSpace.lg, 0, SwanSpace.lg, 24),
        children: [
          if (!verified) _verifyBanner(isDark, ink),
          _publicInvitations(),
          const SizedBox(height: SwanSpace.xl),
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
                ? _seekForm(context, isDark, ink, sports, interests)
                : _myRequestCard(isDark, ink, req),
          ),
        ],
      ),
    );
  }

  Widget _openSlotsTab(bool isDark, Color ink) {
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
            padding:
                const EdgeInsets.fromLTRB(SwanSpace.lg, 0, SwanSpace.lg, 24),
            itemCount: slots.length,
            itemBuilder: (_, i) => _openSlotCard(isDark, ink, slots[i]),
          ),
        );
      },
    );
  }

  Widget _openSlotCard(bool isDark, Color ink, OpenSlot s) {
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
        borderRadius: BorderRadius.circular(SwanRadius.md),
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
                    style: SwanType.caption(SwanColors.textSecondary,
                        w: FontWeight.w600)),
              ],
            ),
          ),
          PremiumStatusChip(
              label: '${s.remaining} kişi',
              color: SwanPalette.light.warning,
              icon: Icons.group_add_rounded),
        ]),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed:
              s.requested || _busy ? null : () => _joinOpenSlot(s.slotId),
          child: Text(s.requested ? 'İstek gönderildi' : 'Katılmak istiyorum'),
        ),
      ]),
    );
  }

  Widget _sectionTitle(Color ink, String text) =>
      Text(text, style: SwanType.bodySm(ink, w: FontWeight.w800));

  Widget _emptyLine(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(text,
            style:
                SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
      );

  Widget _verifyBanner(bool isDark, Color ink) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kTeal.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(SwanRadius.md),
          border: Border.all(color: kTeal.withValues(alpha: .25)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('İlanları incele, oynamak için hesabını doğrula',
              style: SwanType.bodySm(ink, w: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(
              'İlan açmak ve partner iletişimi için doğrulanmış telefon veya '
              'onaylı kimlik gereklidir.',
              style: SwanType.caption(SwanColors.textSecondary,
                  w: FontWeight.w600)),
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
                style: SwanType.caption(filled ? Colors.white : color,
                    w: FontWeight.w800)),
          ),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(SwanRadius.md),
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
                  style: SwanType.caption(SwanColors.textSecondary,
                      w: FontWeight.w600)),
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
    AsyncValue<List<CityRow>> sports,
    AsyncValue<Set<String>> interests,
  ) {
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(SwanRadius.md),
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
                style: SwanType.caption(SwanColors.textSecondary,
                    w: FontWeight.w600));
          }

          final myInterests = interests.valueOrNull ?? {};
          _selectedSport ??=
              myInterests.isNotEmpty ? myInterests.first : sportList.first.code;

          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('İlgilendiğin branşlar',
                    style: SwanType.caption(ink, w: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                    'Seçtiğin branşlarda başkası partner arayınca haber verilir.',
                    style: SwanType.caption(SwanColors.textSecondary,
                        w: FontWeight.w600)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in sportList)
                      _chip(isDark, ink, s.name,
                          selected: myInterests.contains(s.code),
                          onTap: () => _toggleInterest(
                              s.code, !myInterests.contains(s.code))),
                  ],
                ),
                const SizedBox(height: 18),
                Text('Partner arıyorum',
                    style: SwanType.caption(ink, w: FontWeight.w800)),
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
                Material(
                  color: surf,
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('İsteğimi halka açık yayımla',
                        style: SwanType.bodySm(ink)),
                    subtitle: Text(
                        'Branş, şehir ve geçerlilik saati misafirlere görünür. Oynayalım diyen doğrulanmış kişiyle eşleşirsin.',
                        style: SwanType.caption(context.swan.inkMuted)),
                    value: _isPublic,
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _isPublic = value ?? false),
                  ),
                ),
                const SizedBox(height: SwanSpace.md),
                FilledButton(
                  onPressed: _busy ? null : _seek,
                  child: Text(_busy ? 'Aranıyor…' : 'Partner Arıyorum'),
                ),
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
          borderRadius: BorderRadius.circular(SwanRadius.md),
          border: Border.all(color: kTeal.withValues(alpha: .4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${req.sportName} · partnerin bulundu',
              style: SwanType.bodySm(ink, w: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${req.acceptedByName} müsait olduğunu söyledi.',
              style: SwanType.caption(SwanColors.textSecondary,
                  w: FontWeight.w600)),
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
        borderRadius: BorderRadius.circular(SwanRadius.md),
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
                  style: SwanType.caption(SwanColors.textSecondary,
                      w: FontWeight.w600)),
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
          color: selected
              ? kTeal
              : (isDark
                  ? SwanPalette.dark.surfaceAlt
                  : const Color(0xFFF4F7FA)),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(label,
            style: SwanType.caption(selected ? Colors.white : ink,
                w: FontWeight.w700)),
      ),
    );
  }

  Widget _publicInvitations() {
    final c = context.swan;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Halka açık oyun ilanları', style: SwanType.h3(c.ink)),
      const SizedBox(height: SwanSpace.md),
      ref.watch(publicPartnerRequestsProvider).when(
            loading: premiumLoading,
            error: (_, __) => TextButton(
                onPressed: () => ref.invalidate(publicPartnerRequestsProvider),
                child: const Text('İlanlar yüklenemedi. Yeniden dene')),
            data: (requests) => requests.isEmpty
                ? Text('Şu an halka açık partner ilanı yok.',
                    style: SwanType.bodySm(c.inkMuted))
                : Column(children: [
                    for (final request in requests)
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: SwanSpace.sm),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(request.sportName,
                                  style: SwanType.body(c.ink)),
                              Text(
                                  [
                                    if (request.cityName != null)
                                      request.cityName!,
                                    'Son saat: ${request.expiresAt.hour.toString().padLeft(2, '0')}:${request.expiresAt.minute.toString().padLeft(2, '0')}'
                                  ].join(' · '),
                                  style: SwanType.caption(c.inkMuted)),
                              const SizedBox(height: SwanSpace.sm),
                              OutlinedButton(
                                  onPressed:
                                      _busy ? null : () => _ping(request.id),
                                  child: const Text('Oynayalım')),
                            ]),
                      ),
                  ]),
          ),
    ]);
  }

  Future<void> _joinOpenSlot(String slotId) async {
    if (!await requireSwanAction(context, ref, SwanAction.partner) || !mounted)
      return;
    setState(() => _busy = true);
    try {
      await ref.read(courtServiceProvider).requestJoin(slotId);
      ref.invalidate(openSlotsProvider(null));
      _say('İsteğin gönderildi. Sahibi onaylayınca haber vereceğiz.');
    } catch (e) {
      _say(_readable(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _ping(String requestId) async {
    if (!await requireSwanAction(context, ref, SwanAction.partner) || !mounted)
      return;
    setState(() => _busy = true);
    try {
      await ref.read(courtServiceProvider).sendPartnerPing(requestId);
      ref.invalidate(publicPartnerRequestsProvider);
      ref.invalidate(incomingPartnerPingsProvider);
      _say('Eşleşme kaydedildi; ilan sahibine haber verildi.');
    } catch (e) {
      _say(_readable(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ------------------------------- eylemler --------------------------------

  Future<void> _toggleInterest(String sportCode, bool interested) async {
    if (!await requireSwanAction(context, ref, SwanAction.partner) || !mounted)
      return;
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
    if (!await requireSwanAction(context, ref, SwanAction.partner) || !mounted)
      return;
    final sport = _selectedSport;
    if (sport == null) return;

    setState(() => _busy = true);
    try {
      final place = await currentPlaceOrNull();
      await ref.read(courtServiceProvider).seekPartner(
            sportCode: sport,
            isPublic: _isPublic,
            lat: place?.lat,
            lng: place?.lng,
          );
      ref.invalidate(myOpenPartnerRequestProvider);
      ref.invalidate(publicPartnerRequestsProvider);
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
      ref.invalidate(publicPartnerRequestsProvider);
      ref.invalidate(myOpenPartnerRequestProvider);
    } catch (e) {
      _say(_readable(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _respond(String requestId, bool accept) async {
    if (accept &&
        (!await requireSwanAction(context, ref, SwanAction.partner) ||
            !mounted)) return;
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
