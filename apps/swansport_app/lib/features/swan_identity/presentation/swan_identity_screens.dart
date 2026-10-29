import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../../app/widgets/swan_module_app_bar.dart';
import '../../../app/widgets/swan_scaffold.dart';

class SwanIdScreen extends ConsumerWidget {
  const SwanIdScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(featureEnabledProvider(FeatureFlags.swanId))) {
      return const _ClosedFeature(title: 'Swan ID');
    }
    final card = ref.watch(mySwanIdProvider);
    return SwanScaffold(
      appBar: swanModuleAppBar(context, title: 'Swan ID'),
      bottomNavigationBar: const SwanBottomNav(),
      body: SafeArea(
          child: card.when(
        loading: premiumLoading,
        error: (e, _) => premiumError(context, e,
            defaultMessage: 'Swan ID kartın şu anda yüklenemedi.',
            onRetry: () => ref.invalidate(mySwanIdProvider)),
        data: (value) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(mySwanIdProvider);
            await ref.read(mySwanIdProvider.future);
          },
          child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 130),
              children: [
                _IdentityCard(card: value),
                const SizedBox(height: 16),
                if (!value.isMinor) _VisibilityCard(card: value),
                if (value.isMinor)
                  _Info(
                      'Çocuk Swan ID kartları varsayılan olarak özeldir. Süreli paylaşımı bağlı veli oluşturur.'),
                const SizedBox(height: 16),
                FilledButton.icon(
                    onPressed: () => _share(context, ref),
                    icon: const Icon(Icons.qr_code_rounded),
                    label: const Text('Süreli doğrulama QR’ı oluştur')),
                TextButton.icon(
                    onPressed: () async {
                      final count = await ref
                          .read(swanExperienceServiceProvider)
                          .revokeShares();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('$count paylaşım kapatıldı.')));
                      }
                    },
                    icon: const Icon(Icons.link_off_rounded),
                    label: const Text('Açık paylaşım bağlantılarını kapat')),
                if (value.athleteId != null &&
                    ref.watch(featureEnabledProvider(
                        FeatureFlags.athleteJourney))) ...[
                  const SizedBox(height: 24),
                  Text('Gelişim yolculuğu',
                      style: SwanType.h3(context.swan.ink)),
                  const SizedBox(height: 10),
                  _Journey(athleteId: value.athleteId!),
                ],
                if (ref.watch(
                    featureEnabledProvider(FeatureFlags.athleteShowcase))) ...[
                  const SizedBox(height: 24),
                  Text('Video vitrini', style: SwanType.h3(context.swan.ink)),
                  const SizedBox(height: 10),
                  const _Showcase(),
                ],
                if (ref
                    .watch(featureEnabledProvider(FeatureFlags.teamKudos))) ...[
                  const SizedBox(height: 24),
                  Text('Takım rozetleri', style: SwanType.h3(context.swan.ink)),
                  const SizedBox(height: 10),
                  const _Kudos(),
                ],
                if (value.athleteId != null &&
                    ref.watch(featureEnabledProvider(
                        FeatureFlags.athleteMatchCard))) ...[
                  const SizedBox(height: 24),
                  Text('Maç kartlarım', style: SwanType.h3(context.swan.ink)),
                  const SizedBox(height: 10),
                  const _MatchCards(),
                ],
              ]),
        ),
      )),
    );
  }

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    try {
      final token = await ref.read(swanExperienceServiceProvider).createShare();
      if (!context.mounted) return;
      final payload = 'https://swansport.com.tr/#/swan-id/dogrula/$token';
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('24 saat geçerli doğrulama'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  QrImageView(data: payload, size: 220),
                  const SizedBox(height: 12),
                  const Text('QR yalnız sınırlı Swan ID bilgilerini doğrular.')
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Kapat'))
                ],
              ));
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.card});
  final SwanIdCard card;
  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF0D9488), Color(0xFF115E59)]),
            borderRadius: BorderRadius.circular(24)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.verified_user_rounded, color: Colors.white),
            const Spacer(),
            Text(card.publicCode,
                style: SwanType.caption(Colors.white, w: FontWeight.w800))
          ]),
          const SizedBox(height: 28),
          Text(card.fullName, style: SwanType.h2(Colors.white)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final role in card.roles)
              Chip(
                  backgroundColor: Colors.white.withValues(alpha: .16),
                  side: BorderSide.none,
                  label: Text(_role(role),
                      style:
                          SwanType.caption(Colors.white, w: FontWeight.w700)))
          ]),
          if (card.clubs.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(card.clubs.map((x) => x['name']).join(' · '),
                style: SwanType.bodySm(Colors.white70))
          ],
          const SizedBox(height: 12),
          Text('Doğrulanmış SwanSport kimliği',
              style: SwanType.caption(Colors.white70)),
        ]));
  }

  String _role(SwanIdRole r) => r.kind == 'coach'
      ? '${r.coachLevel ?? 1}. Kademe Antrenör${r.sportCode == null ? '' : ' · ${r.sportCode}'}'
      : 'Sporcu${r.sportCode == null ? '' : ' · ${r.sportCode}'}';
}

class _VisibilityCard extends ConsumerWidget {
  const _VisibilityCard({required this.card});
  final SwanIdCard card;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      DropdownButtonFormField<String>(
          initialValue: card.visibility,
          decoration: const InputDecoration(labelText: 'Kart görünürlüğü'),
          items: const [
            DropdownMenuItem(value: 'private', child: Text('Yalnız ben')),
            DropdownMenuItem(
                value: 'members', child: Text('SwanSport üyeleri')),
            DropdownMenuItem(
                value: 'public_link', child: Text('Süreli bağlantı'))
          ],
          onChanged: (v) async {
            if (v == null) return;
            await ref.read(swanExperienceServiceProvider).setVisibility(v);
            ref.invalidate(mySwanIdProvider);
          });
}

class _Journey extends ConsumerWidget {
  const _Journey({required this.athleteId});
  final String athleteId;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(athleteJourneyProvider(athleteId)).when(
          loading: premiumLoading,
          error: (e, _) => premiumError(context, '$e'),
          data: (rows) => rows.isEmpty
              ? const _Info('Henüz gelişim kaydı yok.')
              : Column(children: [
                  for (final row in rows)
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                            row.source == 'club_verified'
                                ? Icons.verified_rounded
                                : Icons.flag_rounded,
                            color: context.swan.accent),
                        title: Text(row.title),
                        subtitle: Text([
                          if (row.summary != null) row.summary!,
                          _date(row.happenedAt)
                        ].join(' · ')))
                ]));
}

class _Showcase extends ConsumerWidget {
  const _Showcase();
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(myShowcaseVideosProvider).when(
          loading: premiumLoading,
          error: (e, _) => premiumError(context, '$e'),
          data: (rows) => rows.isEmpty
              ? const _Info(
                  'Henüz vitrin videosu yok. Video yükleme, gerçek süre doğrulaması tamamlanınca açılacak.')
              : Column(children: [
                  for (final row in rows)
                    Card(
                        child: ListTile(
                            leading: const Icon(Icons.play_circle_fill_rounded),
                            title: Text(row.title),
                            subtitle: Text(
                                '${row.durationSeconds} sn · ${_status(row.status)}${row.clubVerified ? ' · Antrenör doğruladı' : ''}'),
                            onTap: row.signedUrl == null
                                ? null
                                : () => launchUrl(Uri.parse(row.signedUrl!),
                                    mode: LaunchMode.externalApplication)))
                ]));
}

class _Kudos extends ConsumerWidget {
  const _Kudos();
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(myTeamKudosProvider).when(
          loading: premiumLoading,
          error: (e, _) => premiumError(context, '$e'),
          data: (rows) => rows.isEmpty
              ? const _Info('Henüz takım rozeti yok.')
              : Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final row in rows)
                    Chip(
                        avatar: Icon(
                            row.source == 'coach_verified'
                                ? Icons.verified_rounded
                                : Icons.favorite_rounded,
                            size: 18),
                        label: Text(_badge(row.badge)))
                ]));
}

class _MatchCards extends ConsumerWidget {
  const _MatchCards();
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(athleteMatchCardsProvider).when(
          loading: premiumLoading,
          error: (e, _) => premiumError(context, '$e'),
          data: (rows) => rows.isEmpty
              ? const _Info('Henüz resmi maç kartı yok.')
              : Column(children: [
                  for (final card in rows)
                    Card(
                        child: ListTile(
                            leading: Icon(card.isLive
                                ? Icons.sensors_rounded
                                : Icons.sports_rounded),
                            title: Text(card.programName),
                            subtitle: Text(card.lineupStatus == 'approved'
                                ? 'Onaylı esame'
                                : 'Kadro bilgisi bekleniyor'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => Navigator.pushNamed(
                                context, '/mac-kartim/${card.matchId}')))
                ]));
}

class SwanIdVerifyScreen extends ConsumerWidget {
  const SwanIdVerifyScreen({super.key, required this.token});
  final String token;
  @override
  Widget build(BuildContext context, WidgetRef ref) => SwanScaffold(
      appBar: swanModuleAppBar(context, title: 'Swan ID doğrula'),
      body: FutureBuilder<Map<String, dynamic>>(
          future: ref.read(swanExperienceServiceProvider).verify(token),
          builder: (context, s) {
            if (s.connectionState != ConnectionState.done)
              return premiumLoading();
            if (s.hasError)
              return premiumError(context, 'Doğrulama yapılamadı');
            final data = s.data ?? const {};
            if (data['valid'] != true)
              return const Center(
                  child: _Info(
                      'Bu doğrulama bağlantısı geçersiz veya süresi dolmuş.'));
            return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.verified_rounded,
                          color: Color(0xFF0D9488), size: 72),
                      const SizedBox(height: 16),
                      Text('${data['full_name']}',
                          style: SwanType.h2(context.swan.ink)),
                      Text('${data['public_code']}',
                          style: SwanType.bodySm(context.swan.inkMuted)),
                      const SizedBox(height: 14),
                      const Text('Swan ID geçerli'),
                      const SizedBox(height: 10),
                      for (final r in data['roles'] as List? ?? const [])
                        Text(_verifyRole(Map<String, dynamic>.from(r as Map)))
                    ]));
          }));
}

class SwanAssistantScreen extends ConsumerStatefulWidget {
  const SwanAssistantScreen({super.key});
  @override
  ConsumerState<SwanAssistantScreen> createState() =>
      _SwanAssistantScreenState();
}

class _SwanAssistantScreenState extends ConsumerState<SwanAssistantScreen> {
  final controller = TextEditingController();
  String query = '';
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(featureEnabledProvider(FeatureFlags.swanAssistant)))
      return const _ClosedFeature(title: 'Swan Asistan');
    final suggestions = ref.watch(swanAssistantProvider(''));
    final rows = ref.watch(swanAssistantProvider(query));
    return SwanScaffold(
        appBar: swanModuleAppBar(context, title: 'Swan Asistan'),
        bottomNavigationBar: const SwanBottomNav(),
        body: SafeArea(
            child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 130),
                children: [
              const _Info(
                  'Hazır yanıtlar ve güvenli uygulama kısayolları kullanır; cevap uydurmaz.'),
              const SizedBox(height: 12),
              Text('Hazır sorular', style: SwanType.h3(context.swan.ink)),
              const SizedBox(height: 8),
              suggestions.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
                data: (items) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in items.take(6))
                      ActionChip(
                        avatar:
                            const Icon(Icons.auto_awesome_rounded, size: 17),
                        label: Text(item.title),
                        onPressed: () {
                          controller.text = item.title;
                          setState(() => query = item.title);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                  controller: controller,
                  decoration: InputDecoration(
                      hintText: 'Sorunu yaz…',
                      suffixIcon: IconButton(
                          icon: const Icon(Icons.send_rounded),
                          onPressed: () =>
                              setState(() => query = controller.text.trim()))),
                  onSubmitted: (v) => setState(() => query = v.trim())),
              const SizedBox(height: 16),
              rows.when(
                  loading: premiumLoading,
                  error: (e, _) => premiumError(context, e,
                      defaultMessage: 'Hazır yanıtlar yüklenemedi.',
                      onRetry: () =>
                          ref.invalidate(swanAssistantProvider(query))),
                  data: (items) => query.isEmpty
                      ? const _Info(
                          'Bir hazır soru seçebilir veya kendi sorunu yazabilirsin.')
                      : items.isEmpty
                          ? Column(children: [
                              const _Info(
                                  'Bu soruya hazır bir yanıt bulamadım.'),
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pushNamed(context, '/yardim'),
                                  child: const Text('Yardım merkezinde ara'))
                            ])
                          : Column(children: [
                              for (final item in items)
                                Card(
                                    child: Column(children: [
                                  ListTile(
                                      title: Text(item.title),
                                      subtitle: Text(item.answer),
                                      trailing: const Icon(
                                          Icons.arrow_forward_rounded),
                                      onTap: () =>
                                          _act(context, item.actionKey)),
                                  Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        IconButton(
                                            tooltip: 'Yardımcı oldu',
                                            icon: const Icon(
                                                Icons.thumb_up_alt_outlined),
                                            onPressed: () =>
                                                _feedback(item.key, true)),
                                        IconButton(
                                            tooltip: 'Yardımcı olmadı',
                                            icon: const Icon(
                                                Icons.thumb_down_alt_outlined),
                                            onPressed: () =>
                                                _feedback(item.key, false)),
                                      ])
                                ]))
                            ]))
            ])));
  }

  Future<void> _feedback(String key, bool helpful) async {
    await ref
        .read(swanExperienceServiceProvider)
        .assistantFeedback(key, matched: true, helpful: helpful);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geri bildirimin kaydedildi.')));
    }
  }

  void _act(BuildContext context, String action) {
    final route = switch (action) {
      'next_event' || 'event_preparation' => '/calendar',
      'document_status' => '/documents',
      'open_fees' => '/aidatlarim',
      'swan_id' || 'showcase' => '/swan-id',
      'match_card' => '/swan-id',
      'help' => '/yardim',
      'support' => '/destek',
      _ => null
    };
    if (route != null) Navigator.pushNamed(context, route);
  }
}

class AthleteMatchCardScreen extends ConsumerWidget {
  const AthleteMatchCardScreen({super.key, required this.matchId});
  final String matchId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(featureEnabledProvider(FeatureFlags.athleteMatchCard)))
      return const _ClosedFeature(title: 'Dijital maç kartı');
    return SwanScaffold(
        appBar: swanModuleAppBar(context, title: 'Maç kartım'),
        body: ref.watch(athleteMatchCardProvider(matchId)).when(
            loading: premiumLoading,
            error: (e, _) => premiumError(context, '$e'),
            data: (card) {
              final d = card.data;
              return ListView(padding: const EdgeInsets.all(20), children: [
                Text(card.programName, style: SwanType.h2(context.swan.ink)),
                const SizedBox(height: 18),
                _Info(
                    '${d['home_club_name'] ?? 'Ev sahibi'}  ${d['home_score'] ?? '-'} - ${d['away_score'] ?? '-'}  ${d['away_club_name'] ?? 'Deplasman'}'),
                ListTile(
                    leading: const Icon(Icons.schedule_rounded),
                    title: Text(
                        _date(DateTime.parse('${d['starts_at']}').toLocal())),
                    subtitle:
                        Text('${d['location'] ?? 'Tesis bilgisi bekleniyor'}')),
                ListTile(
                    leading: const Icon(Icons.groups_rounded),
                    title: Text(card.lineupStatus == 'approved'
                        ? 'Onaylı esamedesin'
                        : 'Kadro bilgisi henüz paylaşılmadı')),
                if (card.isLive)
                  FilledButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/canli-mac/$matchId'),
                      child: const Text('Canlı skoru aç'))
              ]);
            }));
  }
}

class _Info extends StatelessWidget {
  const _Info(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: context.swan.surface,
          border: Border.all(color: context.swan.line),
          borderRadius: BorderRadius.circular(16)),
      child: Text(text, style: SwanType.bodySm(context.swan.ink)));
}

class _ClosedFeature extends StatelessWidget {
  const _ClosedFeature({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => SwanScaffold(
      appBar: swanModuleAppBar(context, title: title),
      body: const Center(child: Text('Bu özellik henüz hesabına açık değil.')));
}

String _date(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
String _status(String v) => switch (v) {
      'draft' => 'Taslak',
      'pending' => 'Onay bekliyor',
      'published' => 'Yayında',
      'rejected' => 'Reddedildi',
      'archived' => 'Arşiv',
      _ => v
    };
String _badge(String v) => switch (v) {
      'team_player' => 'İyi takım arkadaşı',
      'fair_play' => 'Fair play',
      'helpful' => 'Yardımsever',
      'determined' => 'Mücadeleci',
      'motivator' => 'Takımı motive etti',
      _ => v
    };
String _verifyRole(Map<String, dynamic> r) => r['kind'] == 'coach'
    ? '${r['coach_level'] ?? 1}. Kademe Antrenör · ${r['sport_code'] ?? ''}'
    : 'Sporcu · ${r['sport_code'] ?? ''}';
