import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/location/place.dart';
import '../../../app/widgets/premium.dart';
import 'claim_sheet.dart';
import 'join_requests_sheet.dart';

/// Kortun saat şeridi.
///
/// Sıra ve rezervasyon ayrı sistem değil: ikisi de "bir kutuyu almak".
/// "Sıraya gir" en yakın boş kutuyu alır, "saat seç" belirli kutuyu.
///
/// AYRILABİLİRLİK: kulüp kavramı geçmez.
class CourtDetailScreen extends ConsumerStatefulWidget {
  const CourtDetailScreen({required this.court, super.key});
  final Court court;

  @override
  ConsumerState<CourtDetailScreen> createState() => _CourtDetailScreenState();
}

class _CourtDetailScreenState extends ConsumerState<CourtDetailScreen> {
  bool _busy = false;

  Court get _court => widget.court;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    final async = ref.watch(courtTimelineProvider(_court.id));
    final access = ref.watch(swanAccessProvider);
    final verified = access.hasVerificationTier('location');

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_court.name, style: sora(16, FontWeight.w800, ink)),
            Text('${_court.opensAt} – ${_court.closesAt}',
                style:
                    jakarta(11, FontWeight.w600, SwanColors.textSecondary)),
          ],
        ),
      ),
      body: async.when(
        loading: premiumLoading,
        error: (e, _) => premiumError(context, '$e'),
        data: (slots) => RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(courtTimelineProvider(_court.id)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              if (!verified) _verifyBanner(isDark, ink),
              const SizedBox(height: 4),
              for (final s in slots) _slotRow(isDark, ink, s, verified),
              const SizedBox(height: 14),
              Text(
                  'En fazla 3 saat ilerisi alınabilir. Sıranı aldıktan sonra '
                  'korta varınca uygulamadan onaylaman gerekiyor.',
                  style: jakarta(
                      11.5, FontWeight.w600, SwanColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  /// Doğrulanmamış kullanıcıya ne yapması gerektiğini söyleyen kutu.
  ///
  /// Kapıyı kapatıp sebebini söylememek en kötüsü olurdu; burada hem sebep
  /// hem çözüm var.
  Widget _verifyBanner(bool isDark, Color ink) => Container(
        margin: const EdgeInsets.only(top: 8, bottom: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kTeal.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: kTeal.withValues(alpha: .25)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Sıra alabilmek için bir kez kortta ol',
              style: jakarta(13, FontWeight.w800, ink)),
          const SizedBox(height: 5),
          Text(
              'Kortta olduğunu bir kez doğrula, bundan sonra evden sıra '
              'alabilirsin. Bu, sahte hesapların sırayı doldurmasını engelliyor.',
              style:
                  jakarta(11.5, FontWeight.w600, SwanColors.textSecondary)),
          const SizedBox(height: 11),
          GestureDetector(
            onTap: _busy ? null : _verifyHere,
            child: Container(
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [kTealBright, kTeal]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('Kortta olduğumu doğrula',
                  style: jakarta(12.5, FontWeight.w800, Colors.white)),
            ),
          ),
        ]),
      );

  Widget _slotRow(bool isDark, Color ink, TimelineSlot s, bool verified) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

    final (Color dot, String label) = switch (s) {
      _ when s.isFree => (const Color(0xFF3FB950), 'Boş'),
      _ when s.mine => (kTeal, s.isPlaying ? 'Sen · oynuyorsun' : 'Sen'),
      _ => (
          const Color(0xFFD9860B),
          '${s.ownerName ?? 'Oyuncu'}${s.isPlaying ? ' · oynuyor' : ''}'
        ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: s.mine ? kTeal.withValues(alpha: .45) : line),
      ),
      child: Row(children: [
        SizedBox(
          width: 46,
          child: Text(s.hourLabel, style: jakarta(14, FontWeight.w800, ink)),
        ),
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: jakarta(12.5, FontWeight.w700, ink)),
              if (s.lookingForPlayers)
                Text('${s.needed} oyuncu aranıyor',
                    style: jakarta(11, FontWeight.w700, kTeal)),
            ],
          ),
        ),
        _slotAction(s, verified, line),
      ]),
    );
  }

  Widget _slotAction(TimelineSlot s, bool verified, Color line) {
    Widget button(String text, VoidCallback? onTap,
            {bool filled = true, Color color = kTeal}) =>
        GestureDetector(
          onTap: _busy ? null : onTap,
          child: Container(
            height: 33,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: filled ? color : color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(text,
                style: jakarta(
                    11.5, FontWeight.w800, filled ? Colors.white : color)),
          ),
        );

    if (s.isFree) {
      if (!verified) return const SizedBox.shrink();
      return button('Al', () => _claim(s));
    }

    if (s.mine) {
      // Kortta olduğunu henüz doğrulamadıysa asıl iş bu; başka her şey sonra.
      if (!s.isPlaying) return button('Geldim', () => _checkIn(s));
      return Row(mainAxisSize: MainAxisSize.min, children: [
        if (s.needed > 0) ...[
          button('İstekler', () => _openRequests(s), filled: false),
          const SizedBox(width: 7),
        ],
        button('Devam et', () => _extend(s), filled: false),
      ]);
    }

    if (s.lookingForPlayers && verified) {
      return button('Katıl', () => _requestJoin(s),
          filled: false, color: const Color(0xFFD9860B));
    }

    return const SizedBox.shrink();
  }

  // ------------------------------- eylemler --------------------------------

  /// Konum gerektiren işleri tek yerden geçiriyoruz: her çağıran ayrı ayrı
  /// izin ve hata yönetirse biri unutur, hata da ancak sahada görünür.
  Future<void> _withPlace(Future<void> Function(Place place) action) async {
    setState(() => _busy = true);
    try {
      final place = await currentPlace();
      await action(place);
      ref.invalidate(courtTimelineProvider(_court.id));
    } on PlaceException catch (e) {
      _say(e.message);
    } catch (e) {
      _say(_readable(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyHere() => _withPlace((place) async {
        await ref.read(courtServiceProvider).verifyLocation(
              courtId: _court.id,
              lat: place.lat,
              lng: place.lng,
            );
        // Kademe profilde değişti; erişim hesabı yeniden okunmalı.
        ref.invalidate(currentProfileProvider);
        _say('Doğrulandı — artık sıra alabilirsin.');
      });

  Future<void> _checkIn(TimelineSlot s) => _withPlace((place) async {
        await ref.read(courtServiceProvider).checkIn(
              slotId: s.slotId!,
              lat: place.lat,
              lng: place.lng,
            );
        _say('Onaylandı, iyi oyunlar.');
      });

  Future<void> _claim(TimelineSlot s) async {
    final result = await showModalBottomSheet<ClaimResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClaimSheet(court: _court, startsAt: s.startsAt),
    );
    if (result == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(courtServiceProvider).claimSlot(
            courtId: _court.id,
            startsAt: s.startsAt,
            guests: result.guests,
            needed: result.needed,
          );
      ref.invalidate(courtTimelineProvider(_court.id));
      _say('Sıran alındı. Korta varınca onaylamayı unutma.');
    } catch (e) {
      _say(_readable(e));
      // Başkası kapmış olabilir — şeridi tazele ki doğru durumu görsün.
      ref.invalidate(courtTimelineProvider(_court.id));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _extend(TimelineSlot s) async {
    setState(() => _busy = true);
    try {
      await ref.read(courtServiceProvider).extend(s.slotId!);
      ref.invalidate(courtTimelineProvider(_court.id));
      _say('Bir saat daha senin.');
    } catch (e) {
      _say(_readable(e));
      ref.invalidate(courtTimelineProvider(_court.id));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestJoin(TimelineSlot s) async {
    setState(() => _busy = true);
    try {
      await ref.read(courtServiceProvider).requestJoin(s.slotId!);
      _say('İsteğin gönderildi. Sahibi onaylayınca haber vereceğiz.');
    } catch (e) {
      _say(_readable(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openRequests(TimelineSlot s) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => JoinRequestsSheet(slotId: s.slotId!),
    );
    if (mounted) ref.invalidate(courtTimelineProvider(_court.id));
  }

  /// Postgres istisnaları `PostgrestException(message: …)` diye geliyor;
  /// kullanıcıya ham hata gösterilmez.
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
