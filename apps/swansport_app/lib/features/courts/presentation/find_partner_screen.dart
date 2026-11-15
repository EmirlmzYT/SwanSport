import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_app/app/widgets/swan_module_app_bar.dart';
import 'package:swansport_app/app/widgets/swan_scaffold.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/location/place.dart';
import '../../../app/widgets/action_gate.dart';
import '../../../app/widgets/premium.dart';

/// Partner aramaları, gelen davetler ve oyuncu aranan kortlar için spor lobisi.
class FindPartnerScreen extends ConsumerStatefulWidget {
  const FindPartnerScreen({
    this.initialTab = 0,
    this.placeResolver,
    super.key,
  });

  /// Eski `/partner-ara` ve `/oyuncu-aranan` deep-link sözleşmesi için korunur.
  final int initialTab;

  @visibleForTesting
  final Future<Place?> Function()? placeResolver;

  @override
  ConsumerState<FindPartnerScreen> createState() => _FindPartnerScreenState();
}

class _FindPartnerScreenState extends ConsumerState<FindPartnerScreen> {
  String? _selectedSport;
  bool _isPublic = false;
  bool _composerOpen = false;
  bool _showAllInvites = false;
  final Set<String> _busyActions = {};
  final Set<String> _requestedSlots = {};
  final Set<String> _answeredListings = {};

  bool _busy(String key) => _busyActions.contains(key);

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final access = ref.watch(swanAccessProvider);
    final sports = ref.watch(courtSportCodesProvider);
    final interests = ref.watch(mySportInterestsProvider);
    final myRequest = ref.watch(myOpenPartnerRequestProvider);
    final inbox = ref.watch(incomingPartnerPingsProvider);
    final slots = ref.watch(openSlotsProvider(null));
    final listings = ref.watch(publicPartnerRequestsProvider);

    return SwanScaffold(
      backgroundColor: c.bg,
      appBar: swanModuleAppBar(context, title: 'Partner Bul'),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: c.accent,
          onRefresh: _refresh,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  SwanSpace.lg,
                  SwanSpace.sm,
                  SwanSpace.lg,
                  SwanSpace.xl * 3,
                ),
                children: [
                  Text(
                    'Bugün birlikte spor yapabileceğin kişileri ve açık oyunları bul.',
                    style: SwanType.bodySm(c.inkMuted),
                  ),
                  const SizedBox(height: SwanSpace.md),
                  if (!access.hasVerificationTier('phone'))
                    _verificationNotice(c, access.hasAccount),
                  _personalStatus(c, myRequest, sports, interests),
                  _incomingInvites(c, inbox),
                  _sectionHeader(
                    c,
                    title: 'Açık oyunlar',
                    subtitle: 'Sahası ve saati belli oyunlar',
                  ),
                  const SizedBox(height: SwanSpace.sm),
                  _openGames(c, slots, myRequest.valueOrNull),
                  const SizedBox(height: SwanSpace.xl),
                  _sectionHeader(
                    c,
                    title: 'Partner arayanlar',
                    subtitle: 'Henüz saha ve saat belirlememiş ilanlar',
                  ),
                  const SizedBox(height: SwanSpace.sm),
                  _partnerListings(c, listings),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(openSlotsProvider(null));
    ref.invalidate(publicPartnerRequestsProvider);
    ref.invalidate(myOpenPartnerRequestProvider);
    ref.invalidate(incomingPartnerPingsProvider);
    await Future.wait([
      ref.read(openSlotsProvider(null).future),
      ref.read(publicPartnerRequestsProvider.future),
      ref.read(myOpenPartnerRequestProvider.future),
      ref.read(incomingPartnerPingsProvider.future),
    ]);
  }

  Widget _verificationNotice(SwanPalette c, bool hasAccount) => Container(
        margin: const EdgeInsets.only(bottom: SwanSpace.md),
        padding: const EdgeInsets.all(SwanSpace.md),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(SwanRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, color: c.accent, size: 21),
            const SizedBox(width: SwanSpace.sm),
            Expanded(
              child: Text(
                hasAccount
                    ? 'Oyunları inceleyebilirsin. İstek göndermek için telefonunu doğrula.'
                    : 'Oyunları inceleyebilirsin. İstek göndermek için giriş yap.',
                style: SwanType.caption(c.inkMuted, w: FontWeight.w600),
              ),
            ),
          ],
        ),
      );

  Widget _personalStatus(
    SwanPalette c,
    AsyncValue<MyPartnerRequest?> request,
    AsyncValue<List<CityRow>> sports,
    AsyncValue<Set<String>> interests,
  ) {
    return request.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: SwanSpace.md),
        child: LinearProgressIndicator(),
      ),
      error: (_, __) => _inlineError(
        c,
        'Arama durumun yüklenemedi.',
        () => ref.invalidate(myOpenPartnerRequestProvider),
      ),
      data: (active) {
        if (active != null) return _activeRequestCard(c, active);
        if (_composerOpen) return _searchComposer(c, sports, interests);
        return Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => setState(() => _composerOpen = true),
            icon: const Icon(Icons.person_search_rounded),
            label: const Text('Partner ara'),
          ),
        );
      },
    );
  }

  Widget _searchComposer(
    SwanPalette c,
    AsyncValue<List<CityRow>> sports,
    AsyncValue<Set<String>> interests,
  ) {
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SwanRadius.md),
        side: BorderSide(color: c.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(SwanSpace.md),
        child: sports.when(
          loading: premiumLoading,
          error: (_, __) => _inlineError(
            c,
            'Branşlar yüklenemedi.',
            () => ref.invalidate(courtSportCodesProvider),
          ),
          data: (sportList) {
            if (sportList.isEmpty) {
              return Text(
                'Partner araması için kullanılabilir bir branş bulunamadı.',
                style: SwanType.bodySm(c.inkMuted),
              );
            }
            if (!sportList.any((sport) => sport.code == _selectedSport)) {
              final preferred = interests.valueOrNull ?? const <String>{};
              for (final sport in sportList) {
                if (preferred.contains(sport.code)) {
                  _selectedSport = sport.code;
                  break;
                }
              }
              _selectedSport ??= sportList.first.code;
            }
            final seekBusy = _busy('seek');
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Yeni partner araması',
                        style: SwanType.body(c.ink, w: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Paneli kapat',
                      onPressed: seekBusy
                          ? null
                          : () => setState(() => _composerOpen = false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: SwanSpace.sm),
                DropdownButtonFormField<String>(
                  initialValue: _selectedSport,
                  decoration: const InputDecoration(
                    labelText: 'Branş',
                    prefixIcon: Icon(Icons.sports_tennis_rounded),
                  ),
                  items: [
                    for (final sport in sportList)
                      DropdownMenuItem(
                        value: sport.code,
                        child: Text(
                          sport.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: seekBusy
                      ? null
                      : (value) => setState(() => _selectedSport = value),
                ),
                const SizedBox(height: SwanSpace.sm),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _isPublic,
                  onChanged: seekBusy
                      ? null
                      : (value) => setState(() => _isPublic = value),
                  title: Text(
                    'Halka açık yayımla',
                    style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                  ),
                  subtitle: Text(
                    _isPublic
                        ? 'Branş, şehir ve geçerlilik saati herkese görünür; adın ve konumun görünmez.'
                        : 'Arama yalnızca aynı branşla ilgilenen doğrulanmış kişilere bildirilir.',
                    style: SwanType.caption(c.inkMuted),
                  ),
                ),
                Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      'Branş bildirimleri',
                      style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                    ),
                    subtitle: Text(
                      'İlgilendiğin branşlardaki yeni aramalardan haberdar ol.',
                      style: SwanType.caption(c.inkMuted),
                    ),
                    children: [
                      interests.when(
                        loading: premiumLoading,
                        error: (_, __) => _inlineError(
                          c,
                          'Bildirim tercihleri yüklenemedi.',
                          () => ref.invalidate(mySportInterestsProvider),
                        ),
                        data: (selected) => Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: SwanSpace.sm,
                            runSpacing: SwanSpace.sm,
                            children: [
                              for (final sport in sportList)
                                FilterChip(
                                  label: Text(sport.name),
                                  selected: selected.contains(sport.code),
                                  onSelected: (value) =>
                                      _toggleInterest(sport.code, value),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: SwanSpace.sm),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: seekBusy ? null : _seek,
                    child: Text(
                      seekBusy ? 'Arama başlatılıyor…' : 'Aramayı başlat',
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _activeRequestCard(SwanPalette c, MyPartnerRequest request) {
    final matched = request.isMatched;
    return Semantics(
      container: true,
      label: matched ? 'Partner bulundu' : 'Yanıt bekleniyor',
      child: Container(
        padding: const EdgeInsets.all(SwanSpace.md),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(SwanRadius.md),
          border: Border.all(color: matched ? c.accent : c.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c.accentSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    matched ? Icons.handshake_rounded : Icons.search_rounded,
                    color: c.accent,
                  ),
                ),
                const SizedBox(width: SwanSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.sportName,
                        style: SwanType.body(c.ink, w: FontWeight.w800),
                      ),
                      Text(
                        matched ? 'Partner bulundu' : 'Yanıt bekleniyor',
                        style: SwanType.caption(
                          matched ? c.accent : c.inkMuted,
                          w: FontWeight.w800,
                        ),
                      ),
                      if (matched &&
                          (request.acceptedByName?.trim().isNotEmpty ?? false))
                        Text(
                          '${request.acceptedByName} seninle oynamaya hazır.',
                          style: SwanType.caption(c.inkMuted),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: SwanSpace.md),
            if (matched)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: request.acceptedBy == null
                      ? null
                      : () => Navigator.pushNamed(
                            context,
                            '/sohbet',
                            arguments: {
                              'id': request.acceptedBy,
                              'name': request.acceptedByName,
                            },
                          ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: const Text('Sohbete geç'),
                ),
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _busy('cancel:${request.id}')
                      ? null
                      : () => _cancel(request.id),
                  child: Text(
                    _busy('cancel:${request.id}')
                        ? 'İptal ediliyor…'
                        : 'İptal et',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _incomingInvites(
    SwanPalette c,
    AsyncValue<List<IncomingPartnerPing>> inbox,
  ) {
    return inbox.when(
      loading: () => const SizedBox(height: SwanSpace.md),
      error: (_, __) => Padding(
        padding: const EdgeInsets.only(top: SwanSpace.md),
        child: _inlineError(
          c,
          'Gelen davetler yüklenemedi.',
          () => ref.invalidate(incomingPartnerPingsProvider),
        ),
      ),
      data: (invites) {
        if (invites.isEmpty) return const SizedBox(height: SwanSpace.lg);
        final visible = _showAllInvites ? invites : invites.take(3).toList();
        return Padding(
          padding:
              const EdgeInsets.only(top: SwanSpace.xl, bottom: SwanSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(
                c,
                title: 'Gelen davetler',
                trailing: invites.length > 3
                    ? TextButton(
                        onPressed: () =>
                            setState(() => _showAllInvites = !_showAllInvites),
                        child: Text(
                          _showAllInvites ? 'Daha az göster' : 'Tümünü gör',
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: SwanSpace.xs),
              for (final invite in visible) _inviteRow(c, invite),
            ],
          ),
        );
      },
    );
  }

  Widget _inviteRow(SwanPalette c, IncomingPartnerPing invite) {
    final key = 'invite:${invite.requestId}';
    final busy = _busy(key);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SwanSpace.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: c.accentSoft,
                child: Text(
                  _initials(invite.requesterName),
                  style: SwanType.caption(c.accent, w: FontWeight.w800),
                ),
              ),
              const SizedBox(width: SwanSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invite.requesterName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SwanType.bodySm(c.ink, w: FontWeight.w800),
                    ),
                    Text(
                      '${invite.sportName} için davet gönderdi',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SwanType.caption(c.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: SwanSpace.xs),
          Wrap(
            alignment: WrapAlignment.end,
            runAlignment: WrapAlignment.end,
            spacing: SwanSpace.xs,
            children: [
              TextButton(
                onPressed:
                    busy ? null : () => _respond(invite.requestId, false),
                child: const Text('Reddet'),
              ),
              FilledButton(
                onPressed: busy ? null : () => _respond(invite.requestId, true),
                child: Text(busy ? 'Bekle…' : 'Kabul et'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(
    SwanPalette c, {
    required String title,
    String? subtitle,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: SwanType.h3(c.ink)),
              if (subtitle != null)
                Text(subtitle, style: SwanType.caption(c.inkMuted)),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _openGames(
    SwanPalette c,
    AsyncValue<List<OpenSlot>> slots,
    MyPartnerRequest? activeRequest,
  ) {
    return slots.when(
      loading: premiumLoading,
      error: (_, __) => _inlineError(
        c,
        'Açık oyunlar yüklenemedi.',
        () => ref.invalidate(openSlotsProvider(null)),
      ),
      data: (games) {
        if (games.isEmpty) {
          return _emptyState(
            c,
            icon: Icons.sports_tennis_rounded,
            title: 'Şu an açık oyun yok',
            message:
                'Yeni bir partner araması başlatarak ilk adımı atabilirsin.',
            action: activeRequest == null
                ? TextButton(
                    onPressed: () => setState(() => _composerOpen = true),
                    child: const Text('Partner ara'),
                  )
                : null,
          );
        }
        return Column(
          children: [for (final game in games) _openGameCard(c, game)],
        );
      },
    );
  }

  Widget _openGameCard(SwanPalette c, OpenSlot game) {
    final key = 'slot:${game.slotId}';
    final requested = game.requested || _requestedSlots.contains(game.slotId);
    final busy = _busy(key);
    final place = [
      if ((game.venue ?? '').trim().isNotEmpty) game.venue!.trim(),
      if ((game.cityName ?? '').trim().isNotEmpty) game.cityName!.trim(),
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: SwanSpace.sm),
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: SwanSpace.md,
            runSpacing: SwanSpace.xs,
            children: [
              Text(
                _dateTimeLabel(game.startsAt),
                style: SwanType.bodySm(c.accent, w: FontWeight.w800),
              ),
              Text(
                '${game.remaining} kişi aranıyor',
                style: SwanType.caption(c.inkMuted, w: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: SwanSpace.xs),
          Text(
            game.courtName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: SwanType.body(c.ink, w: FontWeight.w800),
          ),
          Text(
            [game.ownerName, if (place.isNotEmpty) place].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: SwanType.caption(c.inkMuted),
          ),
          const SizedBox(height: SwanSpace.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed:
                  requested || busy ? null : () => _joinOpenSlot(game.slotId),
              child: Text(
                requested
                    ? 'İstek gönderildi'
                    : busy
                        ? 'Gönderiliyor…'
                        : 'Katılma isteği gönder',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _partnerListings(
    SwanPalette c,
    AsyncValue<List<PublicPartnerRequest>> requests,
  ) {
    return requests.when(
      loading: premiumLoading,
      error: (_, __) => _inlineError(
        c,
        'Partner ilanları yüklenemedi.',
        () => ref.invalidate(publicPartnerRequestsProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Text(
            'Şu an halka açık partner ilanı yok.',
            style: SwanType.bodySm(c.inkMuted),
          );
        }
        return Column(
          children: [for (final item in items) _partnerListingRow(c, item)],
        );
      },
    );
  }

  Widget _partnerListingRow(SwanPalette c, PublicPartnerRequest request) {
    final key = 'listing:${request.id}';
    final answered = _answeredListings.contains(request.id);
    final busy = _busy(key);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: SwanSpace.sm),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.sportName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SwanType.bodySm(c.ink, w: FontWeight.w800),
                ),
                Text(
                  [
                    if ((request.cityName ?? '').trim().isNotEmpty)
                      request.cityName!.trim(),
                    'Son yanıt ${_clock(request.expiresAt)}',
                  ].join(' · '),
                  style: SwanType.caption(c.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: SwanSpace.sm),
          OutlinedButton(
            onPressed: answered || busy ? null : () => _ping(request.id),
            child: Text(
              answered
                  ? 'Yanıtlandı'
                  : busy
                      ? 'Gönderiliyor…'
                      : 'Oynamak istiyorum',
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(
    SwanPalette c, {
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SwanSpace.lg),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(SwanRadius.md),
      ),
      child: Column(
        children: [
          Icon(icon, color: c.inkMuted),
          const SizedBox(height: SwanSpace.sm),
          Text(title, style: SwanType.bodySm(c.ink, w: FontWeight.w800)),
          const SizedBox(height: SwanSpace.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: SwanType.caption(c.inkMuted),
          ),
          if (action != null) action,
        ],
      ),
    );
  }

  Widget _inlineError(SwanPalette c, String message, VoidCallback retry) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(SwanRadius.md),
      ),
      child: Row(
        children: [
          Expanded(child: Text(message, style: SwanType.bodySm(c.inkMuted))),
          TextButton(onPressed: retry, child: const Text('Tekrar dene')),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    return '${parts.first[0]}${parts.length > 1 ? parts.last[0] : ''}'
        .toUpperCase();
  }

  String _clock(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}.${value.minute.toString().padLeft(2, '0')}';

  String _dateTimeLabel(DateTime value) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(value.year, value.month, value.day);
    final date = day == today
        ? 'Bugün'
        : day == today.add(const Duration(days: 1))
            ? 'Yarın'
            : '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}';
    return '$date · ${_clock(value)}';
  }

  Future<void> _runAction(String key, Future<void> Function() action) async {
    if (_busyActions.contains(key)) return;
    setState(() => _busyActions.add(key));
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busyActions.remove(key));
    }
  }

  Future<void> _joinOpenSlot(String slotId) async {
    if (!await requireSwanAction(context, ref, SwanAction.partner) ||
        !mounted) {
      return;
    }
    await _runAction('slot:$slotId', () async {
      try {
        await ref.read(courtServiceProvider).requestJoin(slotId);
        if (!mounted) return;
        setState(() => _requestedSlots.add(slotId));
        ref.invalidate(openSlotsProvider(null));
        _say(
          'Katılma isteğin gönderildi. Oyun sahibi onaylayınca haber alacaksın.',
        );
      } catch (error) {
        _say(_readable(error));
      }
    });
  }

  Future<void> _ping(String requestId) async {
    if (!await requireSwanAction(context, ref, SwanAction.partner) ||
        !mounted) {
      return;
    }
    await _runAction('listing:$requestId', () async {
      try {
        await ref.read(courtServiceProvider).sendPartnerPing(requestId);
        if (!mounted) return;
        setState(() => _answeredListings.add(requestId));
        ref.invalidate(publicPartnerRequestsProvider);
        ref.invalidate(myOpenPartnerRequestProvider);
        _say('İlan sahibine oynamak istediğin bildirildi.');
      } catch (error) {
        _say(_readable(error));
      }
    });
  }

  Future<void> _toggleInterest(String sportCode, bool interested) async {
    if (!await requireSwanAction(context, ref, SwanAction.partner) ||
        !mounted) {
      return;
    }
    try {
      await ref
          .read(courtServiceProvider)
          .setSportInterest(sportCode, interested);
      ref.invalidate(mySportInterestsProvider);
    } catch (error) {
      _say(_readable(error));
    }
  }

  Future<void> _seek() async {
    if (!await requireSwanAction(context, ref, SwanAction.partner) ||
        !mounted) {
      return;
    }
    final sport = _selectedSport;
    if (sport == null) return;
    await _runAction('seek', () async {
      try {
        final place = await (widget.placeResolver ?? currentPlaceOrNull)();
        await ref.read(courtServiceProvider).seekPartner(
              sportCode: sport,
              isPublic: _isPublic,
              lat: place?.lat,
              lng: place?.lng,
            );
        ref.invalidate(myOpenPartnerRequestProvider);
        ref.invalidate(publicPartnerRequestsProvider);
        if (mounted) setState(() => _composerOpen = false);
        _say('Partner araman başladı. Yanıt geldiğinde burada göreceksin.');
      } catch (error) {
        _say(_readable(error));
      }
    });
  }

  Future<void> _cancel(String id) async {
    await _runAction('cancel:$id', () async {
      try {
        await ref.read(courtServiceProvider).cancelPartnerRequest(id);
        ref.invalidate(publicPartnerRequestsProvider);
        ref.invalidate(myOpenPartnerRequestProvider);
      } catch (error) {
        _say(_readable(error));
      }
    });
  }

  Future<void> _respond(String requestId, bool accept) async {
    if (accept &&
        (!await requireSwanAction(context, ref, SwanAction.partner) ||
            !mounted)) {
      return;
    }
    await _runAction('invite:$requestId', () async {
      try {
        await ref
            .read(courtServiceProvider)
            .respondPartnerPing(requestId: requestId, accept: accept);
        ref.invalidate(incomingPartnerPingsProvider);
        ref.invalidate(myOpenPartnerRequestProvider);
        _say(accept ? 'Davet kabul edildi.' : 'Davet reddedildi.');
      } catch (error) {
        // Başarısız yanıtta provider yenilenmez; davet ekranda kalır.
        _say(_readable(error));
      }
    });
  }

  String _readable(Object error) {
    final match = RegExp(r'message: ([^,]+)').firstMatch('$error');
    return match?.group(1)?.trim() ?? 'İşlem tamamlanamadı. Tekrar deneyin.';
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
