import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import 'widgets/phase_timer.dart';
import 'widgets/score_pad.dart';

/// Canlı antrenman oturumu.
///
/// **Tek rota, rolde dallanma** — `coach_dashboard` deseni. Antrenör kontrol
/// panelini, sporcu koşu ekranını görüyor. Dört ayrı rota yazmak
/// `navigation_test`'in giriş noktası sözleşmesini dörde katlardı.
///
/// Oturum kimliği `arguments` ile geliyor; yoksa sporcunun canlı oturumu
/// aranıyor (bildirimden gelen kullanıcı için).
class TrainingSessionScreen extends ConsumerWidget {
  const TrainingSessionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.swan;
    final args = ModalRoute.of(context)?.settings.arguments;
    final argId = args is Map ? args['id'] as String? : args as String?;

    if (argId != null) return _SessionBody(sessionId: argId);

    // Kimlik verilmediyse sporcunun içinde olduğu canlı oturum.
    final live = ref.watch(myLiveSessionProvider);
    return live.when(
      loading: () => _shell(c, const Center(child: CircularProgressIndicator())),
      error: (e, _) => _shell(c, _message(c, 'Oturum açılamadı', '$e')),
      data: (s) => s == null
          ? _shell(
              c,
              _message(c, 'Şu an canlı antrenman yok',
                  'Antrenörün oturumu başlattığında katılım kodunu paylaşacak.'))
          : _SessionBody(sessionId: s.id),
    );
  }

  static Widget _shell(SwanPalette c, Widget child) => Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(child: child),
        bottomNavigationBar: const SwanBottomNav(),
      );

  static Widget _message(SwanPalette c, String title, String body) => Center(
        child: Padding(
          padding: const EdgeInsets.all(SwanSpace.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: SwanType.h3(c.ink), textAlign: TextAlign.center),
            const SizedBox(height: SwanSpace.sm),
            Text(body,
                style: SwanType.bodySm(c.inkMuted),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}

class _SessionBody extends ConsumerWidget {
  const _SessionBody({required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.swan;
    final access = ref.watch(swanAccessProvider);
    final session = ref.watch(trainingSessionProvider(sessionId));
    final config = ref.watch(sessionConfigProvider(sessionId));

    return Scaffold(
      extendBody: true,
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: session.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => TrainingSessionScreen._message(
                  c, 'Oturum açılamadı', '$e'),
              data: (s) {
                if (s == null) {
                  return TrainingSessionScreen._message(
                      c, 'Oturum bulunamadı', 'Kapanmış ya da silinmiş olabilir.');
                }
                final cfg = config.valueOrNull;
                // Kişisel oturumda antrenör yok; sahibi kendi yönetiyor.
                final asCoach = !s.isPersonal && access.isClubStaff;
                return asCoach
                    ? _CoachPanel(session: s, config: cfg)
                    : _AthleteRun(session: s, config: cfg);
              },
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }
}

// ============================ Antrenör paneli ==============================

class _CoachPanel extends ConsumerWidget {
  const _CoachPanel({required this.session, required this.config});

  final TrainingSession session;
  final TrainingProtocolConfig? config;

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      ref.invalidate(trainingSessionProvider(session.id));
      ref.invalidate(sessionParticipantsProvider(session.id));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.swan;
    final svc = ref.watch(trainingSessionServiceProvider);
    final people = ref.watch(sessionParticipantsProvider(session.id));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          SwanSpace.lg, SwanSpace.md, SwanSpace.lg, 120),
      children: [
        _header(context, c, session.protocolName, session.statusLabel),
        const SizedBox(height: SwanSpace.lg),

        if (session.isLive && session.joinCode != null) ...[
          _joinCard(c, session.joinCode!),
          const SizedBox(height: SwanSpace.lg),
        ],

        PhaseTimer(
          phase: session.phase,
          endsAt: session.phaseEndsAt,
          paused: session.paused,
          currentSet: session.currentSet,
          setCount: config?.setCount ?? session.setCount,
          onExpiredAction: session.isLive
              ? () => _run(context, ref, () => svc.advancePhase(session.id))
              : null,
          expiredActionLabel: 'Sonraki aşama',
        ),
        const SizedBox(height: SwanSpace.lg),

        if (session.isLive) _controls(context, ref, c, svc),
        if (session.awaitingApproval) ...[
          const SizedBox(height: SwanSpace.md),
          _reviewCard(context, ref, c),
        ],

        const SizedBox(height: SwanSpace.xl),
        Text('Katılanlar', style: SwanType.h3(c.ink)),
        const SizedBox(height: SwanSpace.sm),
        people.when(
          loading: () => const Padding(
              padding: EdgeInsets.all(SwanSpace.lg),
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text('$e', style: SwanType.bodySm(c.danger)),
          data: (list) => list.isEmpty
              ? Text('Henüz kimse katılmadı. Kodu paylaş.',
                  style: SwanType.bodySm(c.inkMuted))
              : Column(children: [
                  for (final p in list) _person(context, ref, c, svc, p),
                ]),
        ),
      ],
    );
  }

  /// Katılım kartı: QR **ve** kod.
  ///
  /// Uygulama içinde kamera okuyucu YOK ve bilerek eklenmedi — kamera izni,
  /// manifest değişikliği ve web'de kısıtlı destek getirirdi. Sporcu kodu
  /// yazıyor; isterse telefonun kendi kamerasıyla QR'ı okutuyor.
  Widget _joinCard(SwanPalette c, String code) => Container(
        padding: const EdgeInsets.all(SwanSpace.lg),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(SwanRadius.lg),
          border: Border.all(color: c.line),
        ),
        child: Column(children: [
          Text('Katılım kodu', style: SwanType.caption(c.inkMuted)),
          const SizedBox(height: SwanSpace.sm),
          Text(
            // Üçerli gruplama sesli okumayı kolaylaştırıyor.
            '${code.substring(0, 3)} ${code.substring(3)}',
            style: SwanType.display(c.ink).copyWith(letterSpacing: 4),
          ),
          const SizedBox(height: SwanSpace.md),
          Container(
            padding: const EdgeInsets.all(SwanSpace.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(SwanRadius.md),
            ),
            child: QrImageView(
              data: 'https://swansport.pages.dev/antrenman?kod=$code',
              size: 148,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: SwanSpace.sm),
          Text('Sporcular kodu yazarak ya da karekodu okutarak katılır',
              style: SwanType.caption(c.inkMuted), textAlign: TextAlign.center),
        ]),
      );

  Widget _controls(
    BuildContext context,
    WidgetRef ref,
    SwanPalette c,
    TrainingSessionService svc,
  ) =>
      Column(children: [
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () =>
                  _run(context, ref, () => svc.advancePhase(session.id)),
              style: FilledButton.styleFrom(backgroundColor: c.accent),
              icon: const Icon(Icons.skip_next_rounded, size: 18),
              label: const Text('Sonraki aşama'),
            ),
          ),
          const SizedBox(width: SwanSpace.sm),
          OutlinedButton(
            onPressed: () => _run(context, ref,
                () => svc.setPaused(session.id, !session.paused)),
            child: Icon(
                session.paused
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
                size: 18,
                color: c.ink),
          ),
        ]),
        const SizedBox(height: SwanSpace.sm),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _askReason(
                context,
                'Aşamayı atla',
                'Neden atlıyorsun? Bu bilgi denetim kaydına yazılıyor.',
                (reason) => _run(
                    context,
                    ref,
                    () => svc.advancePhase(session.id,
                        phase: SessionPhase.score, reason: reason)),
              ),
              child: Text('Aşamayı atla', style: SwanType.bodySm(c.ink)),
            ),
          ),
          const SizedBox(width: SwanSpace.sm),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _askReason(
                context,
                'Oturumu bitir',
                'Erken bitirme gerekçesi denetim kaydına yazılıyor.',
                (reason) => _run(
                    context,
                    ref,
                    () => svc.advancePhase(session.id,
                        phase: SessionPhase.done, reason: reason)),
              ),
              child: Text('Bitir', style: SwanType.bodySm(c.warning)),
            ),
          ),
        ]),
      ]);

  Widget _reviewCard(BuildContext context, WidgetRef ref, SwanPalette c) =>
      Container(
        padding: const EdgeInsets.all(SwanSpace.lg),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(SwanRadius.lg),
          border: Border.all(color: c.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Oturum bitti', style: SwanType.h3(c.ink)),
          const SizedBox(height: SwanSpace.xs),
          Text(
            'Sonuçları incele. Onayladıktan sonra skorlar kilitlenir ve '
            'sporcular değiştiremez.',
            style: SwanType.bodySm(c.inkMuted),
          ),
          const SizedBox(height: SwanSpace.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pushNamed(context, '/antrenman-sonuc',
                  arguments: {'id': session.id}),
              style: FilledButton.styleFrom(backgroundColor: c.accent),
              child: const Text('Sonuçları incele'),
            ),
          ),
        ]),
      );

  Widget _person(
    BuildContext context,
    WidgetRef ref,
    SwanPalette c,
    TrainingSessionService svc,
    SessionParticipant p,
  ) =>
      Padding(
        padding: const EdgeInsets.only(bottom: SwanSpace.sm),
        child: Row(children: [
          Expanded(child: Text(p.name, style: SwanType.body(c.ink))),
          // Kulvar İSTEĞE BAĞLI: atanmadıysa hiçbir şey bozulmuyor.
          TextButton(
            onPressed: () => _askLane(context, p.lane, (lane) async {
              await _run(context, ref,
                  () => svc.assignLane(session.id, p.athleteId, lane));
            }),
            child: Text(p.lane == null ? 'Kulvar ata' : 'Kulvar ${p.lane}',
                style: SwanType.caption(p.lane == null ? c.inkMuted : c.accent)),
          ),
        ]),
      );

  void _askReason(BuildContext context, String title, String body,
      void Function(String) onOk) {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(body),
          const SizedBox(height: SwanSpace.md),
          TextField(
            controller: ctrl,
            decoration: const InputDecoration(hintText: 'Gerekçe'),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onOk(ctrl.text.trim());
            },
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
  }

  void _askLane(BuildContext context, int? current, void Function(int?) onOk) {
    final ctrl = TextEditingController(text: current?.toString() ?? '');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kulvar ata'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Kulvar zorunlu değil. Boş bırakırsan atama kalkar.'),
          const SizedBox(height: SwanSpace.md),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Kulvar numarası'),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onOk(int.tryParse(ctrl.text.trim()));
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}

// ============================ Sporcu ekranı ================================

class _AthleteRun extends ConsumerWidget {
  const _AthleteRun({required this.session, required this.config});

  final TrainingSession session;
  final TrainingProtocolConfig? config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.swan;
    final svc = ref.watch(trainingSessionServiceProvider);
    final sets = ref.watch(mySessionSetsProvider(session.id));
    final cfg = config;

    // Kişisel ritimde sporcu aşamayı kendi ilerletiyor; ortak ritimde
    // antrenör başlatıyor ve sporcu yalnızca izliyor.
    final canAdvance =
        session.isLive && session.rhythm.athleteControlsPhase;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          SwanSpace.lg, SwanSpace.md, SwanSpace.lg, 120),
      children: [
        _header(context, c, session.protocolName,
            session.isPersonal ? 'Bireysel' : session.statusLabel),
        const SizedBox(height: SwanSpace.lg),

        PhaseTimer(
          phase: session.phase,
          endsAt: session.phaseEndsAt,
          paused: session.paused,
          currentSet: session.currentSet,
          setCount: cfg?.setCount ?? session.setCount,
          onExpiredAction: canAdvance
              ? () async {
                  await svc.advancePhase(session.id);
                  ref.invalidate(trainingSessionProvider(session.id));
                }
              : null,
          expiredActionLabel: 'Sonraki aşama',
        ),

        if (cfg != null) ...[
          const SizedBox(height: SwanSpace.lg),
          sets.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('$e', style: SwanType.bodySm(c.danger)),
            data: (list) {
              // Skor girişi yalnızca uygun aşamada açık.
              if (!session.phase.acceptsScore && session.isLive) {
                return _waiting(c, session.phase);
              }
              final existing = list
                  .where((s) => s.setNo == session.currentSet)
                  .cast<TrainingSet?>()
                  .firstWhere((_) => true, orElse: () => null);

              return ScorePad(
                config: cfg,
                setNo: session.currentSet,
                branch: null,
                existing: existing,
                onSubmit: ({num? total, List<num?>? entries}) async {
                  await svc.submitSet(
                    sessionId: session.id,
                    setNo: session.currentSet,
                    total: total,
                    entries: entries,
                  );
                  ref.invalidate(mySessionSetsProvider(session.id));
                  ref.invalidate(trainingSessionProvider(session.id));
                },
              );
            },
          ),
        ],

        const SizedBox(height: SwanSpace.xl),
        Text('Setlerim', style: SwanType.h3(c.ink)),
        const SizedBox(height: SwanSpace.sm),
        sets.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (list) => list.isEmpty
              ? Text('Henüz set kaydetmedin.',
                  style: SwanType.bodySm(c.inkMuted))
              : Column(children: [for (final s in list) _setRow(c, s)]),
        ),

        if (!session.isLive) ...[
          const SizedBox(height: SwanSpace.xl),
          _AssessmentCard(sessionId: session.id),
        ],
      ],
    );
  }

  Widget _waiting(SwanPalette c, SessionPhase phase) => Container(
        padding: const EdgeInsets.all(SwanSpace.lg),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(SwanRadius.lg),
          border: Border.all(color: c.line),
        ),
        child: Row(children: [
          Icon(Icons.hourglass_empty_rounded, size: 18, color: c.inkMuted),
          const SizedBox(width: SwanSpace.sm),
          Expanded(
            child: Text('Skor girişi ${phase.label} aşamasından sonra açılır.',
                style: SwanType.bodySm(c.inkMuted)),
          ),
        ]),
      );

  Widget _setRow(SwanPalette c, TrainingSet s) => Padding(
        padding: const EdgeInsets.only(bottom: SwanSpace.sm),
        child: Row(children: [
          SizedBox(
            width: 34,
            child: Text('${s.setNo}.', style: SwanType.bodySm(c.inkMuted)),
          ),
          Expanded(
            child: Text(
              // EKSİK ≠ SIFIR: girilmemiş set "Eksik" yazıyor, "0" değil.
              s.isMissing
                  ? 'Eksik'
                  : '${s.totalScore! == s.totalScore!.roundToDouble() ? s.totalScore!.toInt() : s.totalScore} puan',
              style: SwanType.body(s.isMissing ? c.inkMuted : c.ink),
            ),
          ),
          if (s.locked) Icon(Icons.lock_rounded, size: 14, color: c.inkMuted),
        ]),
      );
}

/// Antrenman sonu öz değerlendirmesi — tamamen isteğe bağlı.
class _AssessmentCard extends ConsumerStatefulWidget {
  const _AssessmentCard({required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<_AssessmentCard> createState() => _AssessmentCardState();
}

class _AssessmentCardState extends ConsumerState<_AssessmentCard> {
  int? _rpe;
  final _tags = <String>{};
  final _note = TextEditingController();
  bool _saved = false;

  static const _options = [
    'Odak iyiydi',
    'Teknik zorlandı',
    'Ortam/rüzgâr etkiledi',
    'Ekipman sorunu',
    'Yorgunluk',
  ];

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    if (_saved) {
      return Text('Değerlendirmen kaydedildi.',
          style: SwanType.bodySm(c.inkMuted));
    }

    return Container(
      padding: const EdgeInsets.all(SwanSpace.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Nasıl geçti?', style: SwanType.h3(c.ink)),
        const SizedBox(height: SwanSpace.xs),
        Text('İsteğe bağlı — boş bırakırsan antrenmanın yine kaydedilir.',
            style: SwanType.caption(c.inkMuted)),
        const SizedBox(height: SwanSpace.md),

        Text('Zorluk', style: SwanType.bodySm(c.ink)),
        const SizedBox(height: SwanSpace.sm),
        Wrap(spacing: SwanSpace.xs, children: [
          for (var i = 1; i <= 10; i++)
            ChoiceChip(
              label: Text('$i'),
              selected: _rpe == i,
              onSelected: (_) => setState(() => _rpe = _rpe == i ? null : i),
            ),
        ]),
        const SizedBox(height: SwanSpace.md),

        Wrap(spacing: SwanSpace.xs, runSpacing: SwanSpace.xs, children: [
          for (final t in _options)
            FilterChip(
              label: Text(t),
              selected: _tags.contains(t),
              onSelected: (v) => setState(
                  () => v ? _tags.add(t) : _tags.remove(t)),
            ),
        ]),
        const SizedBox(height: SwanSpace.md),

        TextField(
          controller: _note,
          maxLines: 2,
          style: SwanType.bodySm(c.ink),
          decoration: InputDecoration(
            hintText: 'Kısa not (isteğe bağlı)',
            hintStyle: SwanType.bodySm(c.inkMuted),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(SwanRadius.md),
              borderSide: BorderSide(color: c.line),
            ),
          ),
        ),
        const SizedBox(height: SwanSpace.md),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () async {
              final profile = ref.read(currentProfileProvider).valueOrNull;
              if (profile == null) return;
              final athlete = await ref
                  .read(athleteByProfileProvider(profile.id).future);
              if (athlete == null) return;
              await ref.read(trainingSessionServiceProvider).saveAssessment(
                    sessionId: widget.sessionId,
                    athleteId: athlete.id,
                    rpe: _rpe,
                    tags: _tags.toList(),
                    note: _note.text.trim().isEmpty ? null : _note.text.trim(),
                  );
              if (mounted) setState(() => _saved = true);
            },
            style: FilledButton.styleFrom(backgroundColor: c.accent),
            child: const Text('Kaydet'),
          ),
        ),
      ]),
    );
  }
}

Widget _header(BuildContext context, SwanPalette c, String title, String badge) =>
    Row(children: [
      GestureDetector(
        onTap: () => Navigator.maybePop(context),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(SwanRadius.sm),
            border: Border.all(color: c.line),
          ),
          child: Icon(Icons.arrow_back_ios_new_rounded, size: 15, color: c.ink),
        ),
      ),
      const SizedBox(width: SwanSpace.md),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: SwanType.h2(c.ink), maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text(badge, style: SwanType.caption(c.inkMuted)),
        ]),
      ),
    ]);
