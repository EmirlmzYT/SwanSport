import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/location/place.dart';
import '../../../app/widgets/premium.dart';

/// Kort partneri arama.
///
/// Kort sisteminin doğal tamamlayıcısı: partner bul → beraber saat alın.
/// Saat almadan da çalışır — "şimdi/yakında oynamak istiyorum" demek için
/// önce bir saat almış olman gerekmiyor, `open_slots`'un aksine.
///
/// AYRILABİLİRLİK: kulüp kavramı geçmez.
class FindPartnerScreen extends ConsumerStatefulWidget {
  const FindPartnerScreen({super.key});

  @override
  ConsumerState<FindPartnerScreen> createState() => _FindPartnerScreenState();
}

class _FindPartnerScreenState extends ConsumerState<FindPartnerScreen> {
  String? _selectedSport;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

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
        title: Text('Partner Ara', style: sora(19, FontWeight.w800, ink)),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myOpenPartnerRequestProvider);
          ref.invalidate(incomingPartnerPingsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            if (!verified) _verifyBanner(isDark, ink),

            _sectionTitle(ink, 'Gelen istekler'),
            const SizedBox(height: 8),
            inbox.when(
              loading: premiumLoading,
              error: (e, _) => premiumError(context, '$e'),
              data: (pings) => pings.isEmpty
                  ? _emptyLine('Şu an sana gelen bir istek yok.')
                  : Column(
                      children: [
                        for (final p in pings) _pingCard(isDark, ink, p),
                      ],
                    ),
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
      ),
    );
  }

  Widget _sectionTitle(Color ink, String text) =>
      Text(text, style: jakarta(13, FontWeight.w800, ink));

  Widget _emptyLine(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(text,
            style: jakarta(12, FontWeight.w600, SwanColors.textSecondary)),
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
              style: jakarta(13, FontWeight.w800, ink)),
          const SizedBox(height: 5),
          Text(
              'Herhangi bir kortta bir kez "kortta olduğumu doğrula" dedikten '
              'sonra buradan partner arayabilirsin. Bu, sahte hesapların '
              'bildirimlerle seni rahatsız etmesini engelliyor.',
              style:
                  jakarta(11.5, FontWeight.w600, SwanColors.textSecondary)),
        ]),
      );

  Widget _pingCard(bool isDark, Color ink, IncomingPartnerPing p) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

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
                style: jakarta(
                    11.5, FontWeight.w800, filled ? Colors.white : color)),
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
            color: const Color(0xFFD9860B).withValues(alpha: .12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.handshake_rounded,
              color: Color(0xFFD9860B), size: 20),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${p.requesterName} · ${p.sportName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: jakarta(13, FontWeight.w800, ink)),
              Text('Müsait misin, gitmek ister misin?',
                  style: jakarta(
                      11, FontWeight.w600, SwanColors.textSecondary)),
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
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

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
                    jakarta(12, FontWeight.w600, SwanColors.textSecondary));
          }

          final myInterests = interests.valueOrNull ?? {};
          _selectedSport ??=
              myInterests.isNotEmpty ? myInterests.first : sportList.first.code;

          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('İlgilendiğin branşlar',
                style: jakarta(12.5, FontWeight.w800, ink)),
            const SizedBox(height: 4),
            Text('Seçtiğin branşlarda başkası partner arayınca haber verilir.',
                style:
                    jakarta(11, FontWeight.w600, SwanColors.textSecondary)),
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
            Text('Partner arıyorum', style: jakarta(12.5, FontWeight.w800, ink)),
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
                    style: jakarta(13.5, FontWeight.w800,
                        verified ? Colors.white : SwanColors.textSecondary)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
                'Yakınındaki ilgili kişilere bildirim gider. İki saat içinde '
                'kimse kabul etmezse istek kendiliğinden düşer.',
                style: jakarta(
                    10.5, FontWeight.w600, SwanColors.textSecondary)),
          ]);
        },
      ),
    );
  }

  Widget _myRequestCard(bool isDark, Color ink, MyPartnerRequest req) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

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
              style: jakarta(13, FontWeight.w800, ink)),
          const SizedBox(height: 4),
          Text('${req.acceptedByName} müsait olduğunu söyledi.',
              style:
                  jakarta(11.5, FontWeight.w600, SwanColors.textSecondary)),
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
                  style: jakarta(13, FontWeight.w800, Colors.white)),
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
                  style: jakarta(13, FontWeight.w800, ink)),
              const SizedBox(height: 3),
              Text('Yanıt gelene kadar bekleniyor.',
                  style: jakarta(
                      11, FontWeight.w600, SwanColors.textSecondary)),
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
                style: jakarta(
                    11.5, FontWeight.w800, const Color(0xFFD64545))),
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
          color: selected ? kTeal : (isDark ? const Color(0xFF1A2537) : const Color(0xFFF4F7FA)),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(label,
            style: jakarta(
                12, FontWeight.w700, selected ? Colors.white : ink)),
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
