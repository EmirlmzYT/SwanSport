import 'package:swansport_app/app/widgets/swan_scaffold.dart';
import '../../../app/widgets/swan_module_app_bar.dart';
import '../../../app/widgets/swan_surface.dart';
import 'venue_overview.dart';
import '../../../app/widgets/action_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
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
    final bg = (isDark ? SwanPalette.dark : SwanPalette.light).bg;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;

    final async = ref.watch(courtTimelineProvider(_court.id));
    final access = ref.watch(swanAccessProvider);
    final verified = access.hasVerificationTier('phone');

    return SwanScaffold(
      backgroundColor: bg,
      appBar: swanModuleAppBar(context,
          title: _court.name,
          subtitle: '${_court.opensAt} – ${_court.closesAt}'),
      body: async.when(
        loading: premiumLoading,
        error: (e, _) => premiumError(
          context,
          'Saatler yüklenemedi.',
          onRetry: () => ref.invalidate(courtTimelineProvider(_court.id)),
        ),
        data: (slots) => RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(courtTimelineProvider(_court.id)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              VenueOverview(
                  where: _court.where,
                  surfaceType: _court.surfaceType,
                  photoUrls: _court.photoUrls,
                  lat: _court.lat,
                  lng: _court.lng),
              if (_busy) const LinearProgressIndicator(minHeight: 2),
              if (!verified) _verifyBanner(isDark, ink),
              const SizedBox(height: SwanSpace.sm),
              Text('Müsait saatler', style: SwanType.h3(ink)),
              const SizedBox(height: SwanSpace.xs),
              Text(
                'Bir saat seçerek ayrıntıları kontrol et. Dolu saatler yalnızca bilgi amaçlıdır.',
                style: SwanType.caption(context.swan.inkMuted),
              ),
              const SizedBox(height: SwanSpace.sm),
              _legend(ink),
              const SizedBox(height: SwanSpace.md),
              if (ref.watch(featureEnabledProvider(FeatureFlags.courtWaitlist)))
                SwanActionCard(
                  title: 'Bekleme listem',
                  icon: Icons.schedule_rounded,
                  onTap: () => Navigator.pushNamed(context, '/saha-islemlerim'),
                ),
              if (slots.isEmpty) _emptyTimeline(ink),
              for (final s in slots) ...[
                _slotRow(isDark, ink, s, verified),
                if (!s.isFree &&
                    !s.mine &&
                    s.startsAt.isAfter(DateTime.now()) &&
                    ref.watch(
                      featureEnabledProvider(FeatureFlags.courtWaitlist),
                    ))
                  TextButton(
                    onPressed: _busy ? null : () => _wait(s),
                    child: const Text('Bekleme listesine gir'),
                  ),
              ],
              const SizedBox(height: 14),
              Text(
                'En fazla 3 saat ilerisi alınabilir. Sıranı aldıktan sonra '
                'korta varınca uygulamadan onaylaman gerekiyor.',
                style: SwanType.caption(
                  context.swan.inkMuted,
                  w: FontWeight.w600,
                ),
              ),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sıra almak için hesabını doğrula',
              style: SwanType.bodySm(ink, w: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text(
              'Saatleri serbestçe inceleyebilirsin. Sıra ve rezervasyon için '
              'telefon veya kimlik doğrulaması gereklidir.',
              style: SwanType.caption(
                context.swan.inkMuted,
                w: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 11),
            GestureDetector(
              onTap: _busy
                  ? null
                  : () =>
                      requireSwanAction(context, ref, SwanAction.reservation),
              child: Container(
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [kTealBright, kTeal]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Hesabımı doğrula',
                  style: SwanType.caption(Colors.white, w: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _slotRow(bool isDark, Color ink, TimelineSlot s, bool verified) {
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;

    final (Color dot, String label) = switch (s) {
      _ when s.isFree => (const Color(0xFF3FB950), 'Boş'),
      _ when s.mine => (kTeal, s.isPlaying ? 'Sen · oynuyorsun' : 'Sen'),
      _ => (
          SwanPalette.light.warning,
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
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Text(
              s.hourLabel,
              style: SwanType.bodySm(ink, w: FontWeight.w800),
            ),
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
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SwanType.caption(ink, w: FontWeight.w700),
                ),
                if (s.lookingForPlayers)
                  Text(
                    '${s.needed} oyuncu aranıyor',
                    style: SwanType.caption(kTeal, w: FontWeight.w700),
                  ),
              ],
            ),
          ),
          _slotAction(s, verified, line),
        ],
      ),
    );
  }

  Widget _slotAction(TimelineSlot s, bool verified, Color line) {
    Widget button(
      String text,
      VoidCallback? onTap, {
      bool filled = true,
      Color color = kTeal,
    }) =>
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
            child: Text(
              text,
              style: SwanType.caption(
                filled ? Colors.white : color,
                w: FontWeight.w800,
              ),
            ),
          ),
        );

    if (s.isFree) {
      return button('Al', () => _claim(s));
    }

    if (s.mine) {
      // Kortta olduğunu henüz doğrulamadıysa asıl iş bu; başka her şey sonra.
      if (!s.isPlaying) {
        return Row(mainAxisSize: MainAxisSize.min, children: [
          _cancelMenu(s),
          const SizedBox(width: 4),
          button('Geldim', () => _checkIn(s)),
        ]);
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (s.needed > 0) ...[
            button('İstekler', () => _openRequests(s), filled: false),
            const SizedBox(width: 7),
          ],
          _cancelMenu(s),
          const SizedBox(width: 4),
          button('Devam et', () => _extend(s), filled: false),
        ],
      );
    }

    if (s.lookingForPlayers) {
      return button(
        'Katıl',
        () => _requestJoin(s),
        filled: false,
        color: SwanPalette.light.warning,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _legend(Color ink) => Wrap(
        spacing: SwanSpace.md,
        runSpacing: SwanSpace.xs,
        children: [
          _legendItem(const Color(0xFF3FB950), 'Müsait', ink),
          _legendItem(SwanPalette.light.warning, 'Dolu', ink),
          _legendItem(kTeal, 'Senin saatin', ink),
        ],
      );

  Widget _legendItem(Color color, String label, Color ink) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 9, color: color),
          const SizedBox(width: 5),
          Text(label, style: SwanType.caption(ink, w: FontWeight.w700)),
        ],
      );

  Widget _emptyTimeline(Color ink) => Container(
        padding: const EdgeInsets.all(SwanSpace.lg),
        decoration: BoxDecoration(
          color: context.swan.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.swan.line),
        ),
        child: Column(children: [
          Icon(Icons.event_busy_outlined, color: context.swan.inkMuted),
          const SizedBox(height: SwanSpace.sm),
          Text('Şu an seçilebilir saat yok',
              style: SwanType.bodySm(ink, w: FontWeight.w800)),
          const SizedBox(height: SwanSpace.xs),
          Text('Biraz sonra yenileyerek yeni saatleri kontrol edebilirsin.',
              textAlign: TextAlign.center,
              style: SwanType.caption(context.swan.inkMuted)),
          TextButton.icon(
            onPressed: () => ref.invalidate(courtTimelineProvider(_court.id)),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Saatleri yenile'),
          ),
        ]),
      );

  Widget _cancelMenu(TimelineSlot slot) => IconButton(
        tooltip: 'Saati iptal et',
        visualDensity: VisualDensity.compact,
        onPressed: _busy ? null : () => _cancel(slot),
        icon: Icon(Icons.close_rounded, color: context.swan.inkMuted, size: 19),
      );

  // ------------------------------- eylemler --------------------------------

  /// Konum gerektiren işleri tek yerden geçiriyoruz: her çağıran ayrı ayrı
  /// izin ve hata yönetirse biri unutur, hata da ancak sahada görünür.
  Future<void> _withPlace(Future<void> Function(Place place) action) async {
    if (!await requireSwanAction(context, ref, SwanAction.courtCheckIn) ||
        !mounted) return;
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

  Future<void> _checkIn(TimelineSlot s) => _withPlace((place) async {
        await ref.read(courtServiceProvider).checkIn(
              slotId: s.slotId!,
              lat: place.lat,
              lng: place.lng,
            );
        _say('Onaylandı, iyi oyunlar.');
      });

  Future<void> _wait(TimelineSlot s) async {
    if (!await requireSwanAction(context, ref, SwanAction.reservation) ||
        !mounted) return;
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(sahaOperationsServiceProvider)
          .joinWait(_court.id, s.startsAt);
      if (mounted) {
        _say(
          'Bekleme listesine katıldın. Saha İşlemlerim’den takip edebilirsin.',
        );
      }
    } catch (e) {
      _say(_readable(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _claim(TimelineSlot s) async {
    if (!await requireSwanAction(context, ref, SwanAction.reservation) ||
        !mounted) return;
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
      if (mounted) setState(() => _busy = false);
      await _showClaimResult(s);
    } catch (e) {
      _say(_claimFailure(e));
      // Başkası kapmış olabilir — şeridi tazele ki doğru durumu görsün.
      ref.invalidate(courtTimelineProvider(_court.id));
    } finally {
      if (mounted && _busy) setState(() => _busy = false);
    }
  }

  Future<void> _showClaimResult(TimelineSlot slot) => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded, color: kTeal),
          title: const Text('Saat ayrıldı'),
          content: Text(
            '${_court.name}\n${_dayLabel(slot.startsAt)} · ${slot.hourLabel}\n\n'
            'Korta varınca uygulamadan “Geldim” diyerek konumunu doğrula.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );

  String _dayLabel(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';

  String _claimFailure(Object error) {
    final readable = _readable(error);
    final lower = readable.toLowerCase();
    if (lower.contains('dolu') ||
        lower.contains('alındı') ||
        lower.contains('unique') ||
        lower.contains('conflict')) {
      return 'Bu saat az önce doldu. Saatleri yeniledik; başka bir saat seçebilirsin.';
    }
    return readable;
  }

  Future<void> _cancel(TimelineSlot slot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Saati iptal et?'),
        content: Text(
            '${_court.name} · ${slot.hourLabel} için ayırdığın saat boşalacak.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('İptal et'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || slot.slotId == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(courtServiceProvider).cancel(slot.slotId!);
      ref.invalidate(courtTimelineProvider(_court.id));
      _say('Saat iptal edildi.');
    } catch (e) {
      _say(_readable(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _extend(TimelineSlot s) async {
    if (!await requireSwanAction(context, ref, SwanAction.reservation) ||
        !mounted) return;
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
    if (!await requireSwanAction(context, ref, SwanAction.reservation) ||
        !mounted) return;
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
