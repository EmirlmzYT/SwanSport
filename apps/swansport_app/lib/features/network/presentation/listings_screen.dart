import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';
import '../../../app/widgets/quick_form.dart';
import '../../social/presentation/widgets/social_widgets.dart';
import 'equipment_listing_sheet.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/design/swan_palette.dart';

/// İlanlar — sporcu arayan kulüp, kulüp arayan sporcu/antrenör ve seçmeler.
///
/// Seçme ayrı bir modül değil: tarihi, konumu ve kontenjanı olan bir ilan.
/// Aynı filtreler ve aynı başvuru akışı ikinci kez yazılmadı.
class ListingsScreen extends ConsumerStatefulWidget {
  const ListingsScreen({super.key});

  @override
  ConsumerState<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends ConsumerState<ListingsScreen> {
  var _filter = const DiscoverFilter();

  ListingKind? get _kind =>
      _filter.kind.isEmpty ? null : ListingKindX.fromCode(_filter.kind);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = (isDark ? SwanPalette.dark : SwanPalette.light).bg;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;

    final async = ref.watch(listingsProvider(_filter));

    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                          color: surf,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: line)),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 15, color: ink),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text('İlanlar', style: SwanType.h2(ink)),
                  const Spacer(),
                  AddButton(onTap: _create, tooltip: 'İlan ver'),
                ]),
              ),
              _kindBar(isDark, ink),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(listingsProvider(_filter));
                    await ref.read(listingsProvider(_filter).future);
                  },
                  child: async.when(
                    loading: () => ListView(children: [premiumLoading()]),
                    error: (e, _) =>
                        ListView(children: [premiumError(context, '$e')]),
                    data: (list) => list.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.only(top: 40),
                            children: [
                              premiumEmpty(
                                context,
                                icon: Icons.campaign_outlined,
                                title: 'İlan yok',
                                subtitle:
                                    'Sporcu, antrenör arayanlar ve seçme '
                                    'duyuruları burada görünür. İlk ilanı sen ver.',
                                actionLabel: 'İlan ver',
                                onAction: _create,
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(20, 4, 20, 132),
                            itemCount: list.length,
                            itemBuilder: (_, i) =>
                                _card(isDark, ink, list[i]),
                          ),
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

  Widget _kindBar(bool isDark, Color ink) {
    Widget chip(String label, bool active, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color: active
                  ? kTeal
                  : (isDark ? SwanPalette.dark.surfaceAlt : Colors.white),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                  color: active
                      ? kTeal
                      : (isDark
                          ? SwanPalette.dark.line
                          : SwanPalette.light.line)),
            ),
            child: Text(label,
                style: SwanType.caption(active ? Colors.white : ink, w: FontWeight.w700)),
          ),
        );

    final sports = ref.watch(sportsProvider).valueOrNull ?? const <CityRow>[];

    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          chip(
              'Tümü',
              _kind == null,
              () => setState(() => _filter =
                  _filter.copyWith(kind: '', clearPriceMax: true))),
          for (final k in ListingKind.values)
            chip(
                k.shortLabel,
                _kind == k,
                () => setState(() => _filter = _filter.copyWith(
                    kind: k.code,
                    // Fiyat tavanı yalnızca satılıkta anlamlı; tür
                    // değişince taşınmasın.
                    clearPriceMax: k != ListingKind.equipmentSale))),
          chip(
            _filter.sport.isEmpty
                ? 'Branş'
                : (sports
                        .where((s) => s.code == _filter.sport)
                        .map((s) => s.name)
                        .firstOrNull ??
                    'Branş'),
            _filter.sport.isNotEmpty,
            () async {
              final picked = await _pickSport(sports);
              if (picked != null) {
                setState(() => _filter = _filter.copyWith(sport: picked));
              }
            },
          ),
        ],
      ),
    );
  }

  Future<String?> _pickSport(List<CityRow> sports) async {
    if (sports.isEmpty) return null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.7,
        decoration: BoxDecoration(
          color: surf,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
        child: Column(children: [
          Text('Branş', style: SwanType.h3(ink)),
          Expanded(
            child: ListView(children: [
              ListTile(
                title: Text('Hepsi', style: SwanType.bodySm(ink, w: FontWeight.w600)),
                onTap: () => Navigator.pop(ctx, ''),
              ),
              for (final s in sports)
                ListTile(
                  title:
                      Text(s.name, style: SwanType.bodySm(ink, w: FontWeight.w600)),
                  onTap: () => Navigator.pop(ctx, s.code),
                ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _card(bool isDark, Color ink, Listing l) {
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    final accent = l.isTryout
        ? SwanPalette.light.warning
        : (l.isEquipment ? const Color(0xFF5B6ABF) : kTeal);

    return GestureDetector(
      onTap: () => _openDetail(l),
      child: Container(
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((l.imageUrl ?? '').isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    l.imageUrl!,
                    fit: BoxFit.cover,
                    // Görsel gelmezse kart bozulmasın: ilan metni zaten
                    // kendi başına anlamlı.
                    errorBuilder: (_, __, ___) => Container(color: line),
                  ),
                ),
              ),
              const SizedBox(height: 11),
            ],
            Row(children: [
              SocialAvatar(
                initials: l.byline.isEmpty ? '?' : l.byline[0].toUpperCase(),
                imageUrl: l.logoUrl,
                size: 38,
                radius: 12,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.byline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SwanType.caption(ink, w: FontWeight.w700)),
                    Text(shortAgo(l.createdAt),
                        style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
                  ],
                ),
              ),
              PremiumStatusChip(
                label: l.kind.shortLabel,
                color: accent,
                icon: l.isTryout
                    ? Icons.sports_rounded
                    : (l.isEquipment
                        ? Icons.inventory_2_rounded
                        : Icons.person_search_rounded),
              ),
            ]),
            const SizedBox(height: 11),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: Text(l.title,
                      style: SwanType.bodySm(ink, w: FontWeight.w800))),
              if (l.kind == ListingKind.equipmentSale) ...[
                const SizedBox(width: 8),
                Text(
                    // Fiyatın boş olması "pazarlıklı" demek.
                    l.price == null ? 'Pazarlıklı' : fmtMoney(l.price!),
                    style: SwanType.bodySm(accent, w: FontWeight.w800)),
              ],
            ]),
            if (l.criteria.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(l.criteria,
                  style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
            ],
            if (l.isTryout && l.startsAt != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.event_rounded,
                    size: 14, color: SwanPalette.light.warning),
                const SizedBox(width: 6),
                Text(
                    '${l.startsAt!.day}.${l.startsAt!.month}.${l.startsAt!.year}'
                    ' · ${l.startsAt!.hour.toString().padLeft(2, '0')}:'
                    '${l.startsAt!.minute.toString().padLeft(2, '0')}'
                    '${(l.location ?? '').isEmpty ? '' : ' · ${l.location}'}',
                    style: SwanType.caption(SwanPalette.light.warning, w: FontWeight.w700)),
              ]),
            ],
            const SizedBox(height: 12),
            Row(children: [Expanded(child: _cardAction(l, line, accent))]),
          ],
        ),
      ),
    );
  }

  /// Kartın altındaki tek eylem düğmesi.
  ///
  /// Malzeme ilanında başvuru akışı kullanılmıyor: kimse malzemeye
  /// "başvurmaz", pazarlık eder. Bu yüzden mevcut sohbet ekranına
  /// yönlendiriyoruz — yeni bir mesajlaşma yazılmadı.
  Widget _cardAction(Listing l, Color line, Color accent) {
    Widget button(String text, Color fg,
            {VoidCallback? onTap, Gradient? gradient, Color? fill}) =>
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: gradient,
              color: fill,
              borderRadius: BorderRadius.circular(12),
              border: (gradient == null && fill == null)
                  ? Border.all(color: line)
                  : null,
            ),
            child: Text(text, style: SwanType.caption(fg, w: FontWeight.w800)),
          ),
        );

    if (l.isEquipment) {
      if (l.canManage) {
        return button('Satıldı olarak işaretle', accent,
            onTap: () => _close(l), fill: accent.withValues(alpha: .10));
      }
      return button('Satıcıya yaz', Colors.white,
          onTap: () => _messageOwner(l),
          gradient: LinearGradient(
              colors: [accent.withValues(alpha: .85), accent]));
    }

    if (l.canManage) {
      return button('${l.applicationCount} başvuru', kTeal,
          onTap: () => _openApplicants(l), fill: kTeal.withValues(alpha: .10));
    }

    return button(
      l.applied ? 'Başvuruldu' : 'Başvur',
      l.applied ? SwanColors.textSecondary : Colors.white,
      onTap: l.applied ? null : () => _apply(l),
      gradient: l.applied
          ? null
          : const LinearGradient(colors: [kTealBright, kTeal]),
    );
  }

  /// İlan sahibiyle sohbeti açar. Rota ve ekran hazır (`/sohbet`).
  void _messageOwner(Listing l) {
    Navigator.pushNamed(context, '/sohbet',
        arguments: {'id': l.ownerId, 'name': l.byline});
  }

  // ------------------------------- eylemler --------------------------------
  Future<void> _openDetail(Listing l) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.8),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
            20, 18, 20, 20 + MediaQuery.of(ctx).padding.bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.title, style: SwanType.h3(ink)),
              const SizedBox(height: 4),
              Text('${l.kind.label} · ${l.byline}',
                  style: SwanType.caption(kTeal, w: FontWeight.w600)),
              if (l.criteria.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(l.criteria,
                    style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
              ],
              if ((l.body ?? '').isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(l.body!,
                    style: SwanType.bodySm(ink)
                        .copyWith(height: 1.5)),
              ],
              if (l.isTryout) ...[
                const SizedBox(height: 14),
                if (l.quota != null)
                  Text('Kontenjan: ${l.quota}',
                      style: SwanType.caption(ink, w: FontWeight.w700)),
                if ((l.location ?? '').isNotEmpty)
                  Text('Yer: ${l.location}',
                      style: SwanType.caption(ink, w: FontWeight.w600)),
              ],
              if (l.deadline != null) ...[
                const SizedBox(height: 8),
                Text(
                    'Son başvuru: ${l.deadline!.day}.${l.deadline!.month}.${l.deadline!.year}',
                    style: SwanType.caption(SwanPalette.light.warning, w: FontWeight.w700)),
              ],
              const SizedBox(height: 20),
              if (l.canManage)
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    _close(l);
                  },
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: SwanPalette.light.danger.withValues(alpha: .4)),
                    ),
                    child: Text('İlanı kapat',
                        style: SwanType.bodySm(SwanPalette.light.danger, w: FontWeight.w800)),
                  ),
                )
              else if (!l.applied)
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    _apply(l);
                  },
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient:
                          const LinearGradient(colors: [kTealBright, kTeal]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text('Başvur',
                        style: SwanType.bodySm(Colors.white, w: FontWeight.w800)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _apply(Listing l) async {
    final note = FormField_('Mesajın', hint: 'Kendini kısaca tanıt',
        required: false);
    final ok = await showQuickForm(
      context,
      title: l.title,
      note: 'Profilin ilan sahibine görünecek.',
      fields: [note],
      onSubmit: () => ref
          .read(networkServiceProvider)
          .applyToListing(l.id, note: note.value),
    );
    if (ok == true) {
      ref.invalidate(listingsProvider(_filter));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Başvurun iletildi'), backgroundColor: kTeal));
      }
    }
  }

  Future<void> _close(Listing l) async {
    try {
      await ref.read(networkServiceProvider).closeListing(l.id);
      ref.invalidate(listingsProvider(_filter));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Kapatılamadı: $e'),
            backgroundColor: SwanPalette.light.danger));
      }
    }
  }

  Future<void> _openApplicants(Listing l) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.75,
        decoration: BoxDecoration(
          color: surf,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        child: Column(children: [
          Text('Başvurular', style: SwanType.h3(ink)),
          Text(l.title,
              style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
          const SizedBox(height: 14),
          Expanded(
            child: Consumer(builder: (_, r, __) {
              final list = r.watch(applicantsProvider(l.id));
              return list.when(
                loading: premiumLoading,
                error: (e, _) => premiumError(context, '$e'),
                data: (rows) => rows.isEmpty
                    ? Center(
                        child: Text('Henüz başvuru yok',
                            style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)))
                    : ListView.builder(
                        itemCount: rows.length,
                        itemBuilder: (_, i) => _applicantRow(ink, l, rows[i]),
                      ),
              );
            }),
          ),
        ]),
      ),
    );
  }

  Widget _applicantRow(Color ink, Listing l, Applicant a) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/profil',
              arguments: a.profileId),
          child: SocialAvatar(
              initials: a.name[0].toUpperCase(),
              imageUrl: a.avatarUrl,
              size: 40),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.name, style: SwanType.bodySm(ink, w: FontWeight.w700)),
              if (a.subtitle.isNotEmpty)
                Text(a.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SwanType.caption(SwanColors.textSecondary)),
              if ((a.note ?? '').isNotEmpty)
                Text(a.note!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SwanType.caption(ink)),
              if (!a.isPending)
                Text(a.status == 'accepted' ? 'Kabul edildi' : 'Reddedildi',
                    style: SwanType.caption(a.status == 'accepted'
                            ? SwanPalette.light.success
                            : SwanColors.textSecondary, w: FontWeight.w800)),
            ],
          ),
        ),
        if (a.isPending) ...[
          _mini(SwanPalette.light.danger, Icons.close_rounded,
              () => _review(l, a, false)),
          const SizedBox(width: 6),
          _mini(SwanPalette.light.success, Icons.check_rounded,
              () => _review(l, a, true)),
        ],
      ]),
    );
  }

  Widget _mini(Color color, IconData icon, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: Colors.white, size: 17),
        ),
      );

  Future<void> _review(Listing l, Applicant a, bool accept) async {
    try {
      await ref.read(networkServiceProvider).reviewApplication(a.id, accept);
      ref.invalidate(applicantsProvider(l.id));
      ref.invalidate(listingsProvider(_filter));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('İşlem başarısız: $e'),
            backgroundColor: SwanPalette.light.danger));
      }
    }
  }

  /// İlan verme. Tür seçimine göre form alanları değişir; seçme ilanında
  /// tarih/konum/kontenjan sorulur.
  Future<void> _create() async {
    final club = ref.read(activeClubProvider).valueOrNull;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;

    // Malzeme ilanı kulüpsüz de verilebilir; kişisel ilanda onaylanmış bir
    // belge aranıyor. Asıl engel `create_listing` içinde — buradaki kontrol
    // yalnızca kapalı bir seçeneği tıklatıp hata aldırmamak için.
    final access = ref.read(swanAccessProvider);
    bool enabled(ListingKind k) {
      if (club != null) return true;
      if (k == ListingKind.clubWanted) return true;
      if (k.isEquipment) return access.hasApprovedCredential;
      return false;
    }

    String? blockReason(ListingKind k) {
      if (enabled(k)) return null;
      if (k.isEquipment) return 'Onaylanmış bir belgen olmalı';
      return 'Kulüp gerekiyor';
    }

    final kind = await showModalBottomSheet<ListingKind>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: surf,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
            20, 18, 20, 20 + MediaQuery.of(ctx).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Ne ilanı vereceksin?', style: SwanType.h3(ink)),
          const SizedBox(height: 10),
          for (final k in ListingKind.values)
            ListTile(
              enabled: enabled(k),
              leading: Icon(
                  k == ListingKind.tryout
                      ? Icons.sports_rounded
                      : (k.isEquipment
                          ? Icons.inventory_2_rounded
                          : Icons.person_search_rounded),
                  color: kTeal),
              title: Text(k.label, style: SwanType.bodySm(ink, w: FontWeight.w600)),
              subtitle: blockReason(k) == null
                  ? null
                  : Text(blockReason(k)!,
                      style: SwanType.caption(SwanColors.textSecondary)),
              onTap: () => Navigator.pop(ctx, k),
            ),
        ]),
      ),
    );
    if (kind == null) return;
    if (!mounted) return;

    if (kind.isEquipment) {
      final created = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) =>
            EquipmentListingSheet(kind: kind, clubId: club?.id),
      );
      if (created == true) {
        ref.invalidate(listingsProvider(_filter));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('İlan yayımlandı'), backgroundColor: kTeal));
        }
      }
      return;
    }

    final title = FormField_('Başlık',
        hint: kind == ListingKind.tryout
            ? 'U-14 altyapı seçmesi'
            : 'Libero arıyoruz');
    final body = FormField_('Açıklama', hint: 'Detaylar', required: false);
    final ageMin = FormField_('Alt yaş', hint: '12', required: false);
    final ageMax = FormField_('Üst yaş', hint: '14', required: false);
    final position = FormField_('Mevki', hint: 'Libero', required: false);
    final location = FormField_('Yer', hint: 'Merkez Salon', required: false);
    final quota = FormField_('Kontenjan', hint: '30', required: false);

    final fields = <FormField_>[
      title,
      body,
      ageMin,
      ageMax,
      if (kind != ListingKind.coachWanted) position,
      if (kind == ListingKind.tryout) ...[location, quota],
    ];

    final ok = await showQuickForm(
      context,
      title: kind.label,
      fields: fields,
      onSubmit: () => ref.read(networkServiceProvider).createListing(
            kind: kind.code,
            title: title.value,
            body: body.value,
            clubId: kind == ListingKind.clubWanted ? null : club?.id,
            sport: _filter.sport.isEmpty ? null : _filter.sport,
            ageMin: int.tryParse(ageMin.value),
            ageMax: int.tryParse(ageMax.value),
            position: position.value,
            location: location.value,
            quota: int.tryParse(quota.value),
            startsAt: kind == ListingKind.tryout
                ? DateTime.now().add(const Duration(days: 14))
                : null,
          ),
    );

    if (ok == true) {
      ref.invalidate(listingsProvider(_filter));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('İlan yayımlandı'), backgroundColor: kTeal));
      }
    }
  }
}
