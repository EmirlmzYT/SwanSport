import 'package:swansport_app/app/widgets/swan_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/widgets/swan_module_app_bar.dart';
import '../widgets/development_report_export.dart';

class DevelopmentReportScreen extends ConsumerStatefulWidget {
  const DevelopmentReportScreen({super.key, this.athleteId});
  final String? athleteId;
  @override
  ConsumerState<DevelopmentReportScreen> createState() =>
      _DevelopmentReportScreenState();
}

class _DevelopmentReportScreenState
    extends ConsumerState<DevelopmentReportScreen> {
  final _search = TextEditingController();
  String _query = '';
  int _offset = 0;
  String? _athleteId;
  String? _trainingSport;
  String? _trainingSource;
  String? _trainingClub;
  late DateTime _from, _to;
  @override
  void initState() {
    super.initState();
    _athleteId = widget.athleteId;
    final now = DateTime.now().toUtc().add(const Duration(hours: 3));
    _to = DateTime(now.year, now.month, now.day);
    _from = _to.subtract(const Duration(days: 89));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  DevelopmentReportRequest get _request =>
      (athleteId: _athleteId!, from: _from, to: _to);
  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final enabled =
        ref.watch(featureEnabledProvider(FeatureFlags.developmentReport));
    return SwanScaffold(
      backgroundColor: c.bg,
      appBar: swanModuleAppBar(context, title: 'Dönem Gelişim Raporu'),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: [
                Expanded(
                  child: !enabled
                      ? Center(
                          child: Text(
                            'Bu özellik şu anda hesabına açık değil.',
                            style: SwanType.body(c.inkMuted),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(SwanSpace.lg),
                          children: [
                            if (_athleteId == null)
                              ..._picker(c)
                            else ...[
                              TextButton(
                                onPressed: () => setState(
                                  () => _athleteId = null,
                                ),
                                child: const Text('Sporcu değiştir'),
                              ),
                              Text(
                                'Tarih aralığı',
                                style: SwanType.h3(c.ink),
                              ),
                              TextButton.icon(
                                onPressed: _choosePeriod,
                                icon: const Icon(
                                  Icons.date_range_rounded,
                                ),
                                label: Text(
                                  '${reportDate(_from)} – ${reportDate(_to)}',
                                ),
                              ),
                              Text(
                                'En fazla 366 gün. Yalnız kayıtlı veriler kullanılır.',
                                style: SwanType.caption(c.inkMuted),
                              ),
                              const SizedBox(height: SwanSpace.lg),
                              ref
                                  .watch(
                                    developmentReportProvider(
                                      _request,
                                    ),
                                  )
                                  .when(
                                    loading: () => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                    error: (_, __) => Column(
                                      children: [
                                        Text(
                                          'Rapor yüklenemedi veya erişimin yok.',
                                          style: SwanType.body(c.ink),
                                        ),
                                        TextButton(
                                          onPressed: () => ref.invalidate(
                                            developmentReportProvider(
                                              _request,
                                            ),
                                          ),
                                          child: const Text(
                                            'Tekrar dene',
                                          ),
                                        ),
                                      ],
                                    ),
                                    data: (report) => _report(report, c),
                                  ),
                              const SizedBox(height: SwanSpace.lg),
                              _trainingProgress(c),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _picker(SwanPalette c) => [
        Text('Rapor hazırlanacak sporcu', style: SwanType.h3(c.ink)),
        Text(
          'Kendin, bağlı çocukların ve yetkili olduğun kulüp sporcuları.',
          style: SwanType.bodySm(c.inkMuted),
        ),
        TextField(
          controller: _search,
          maxLength: 100,
          decoration: const InputDecoration(labelText: 'Sporcu veya kulüp ara'),
          onSubmitted: (_) => _applySearch(),
        ),
        TextButton(onPressed: _applySearch, child: const Text('Ara')),
        ref
            .watch(reportAthletesProvider((query: _query, offset: _offset)))
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Column(
                children: [
                  const Text('Sporcular yüklenemedi.'),
                  TextButton(
                    onPressed: () => ref.invalidate(
                      reportAthletesProvider(
                        (query: _query, offset: _offset),
                      ),
                    ),
                    child: const Text('Tekrar dene'),
                  ),
                ],
              ),
              data: (page) => Column(
                children: [
                  if (page.athletes.isEmpty)
                    Text(
                      'Bu aramada erişebildiğin sporcu yok.',
                      style: SwanType.body(c.inkMuted),
                    ),
                  for (final athlete in page.athletes)
                    Material(
                      color: c.surface,
                      child: ListTile(
                        title: Text(athlete.name, style: SwanType.body(c.ink)),
                        subtitle: Text(
                          athlete.clubName ?? 'Ferdi sporcu',
                          style: SwanType.caption(c.inkMuted),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => setState(() => _athleteId = athlete.id),
                      ),
                    ),
                  Wrap(
                    children: [
                      if (_offset > 0)
                        TextButton(
                          onPressed: () => setState(() => _offset -= 40),
                          child: const Text('Önceki'),
                        ),
                      if (page.hasMore)
                        TextButton(
                          onPressed: () => setState(() => _offset += 40),
                          child: const Text('Sonraki'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
      ];
  void _applySearch() => setState(() {
        _query = _search.text.trim();
        _offset = 0;
      });
  Future<void> _choosePeriod() async {
    final now = DateTime.now().toUtc().add(const Duration(hours: 3));
    final today = DateTime(now.year, now.month, now.day);
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: today,
      initialDateRange: DateTimeRange(start: _from, end: _to),
      helpText: 'Rapor dönemi',
    );
    if (range == null || !mounted) return;
    final days = DateTime.utc(
      range.end.year,
      range.end.month,
      range.end.day,
    )
        .difference(
          DateTime.utc(
            range.start.year,
            range.start.month,
            range.start.day,
          ),
        )
        .inDays;
    if (days > 365) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En fazla 366 günlük dönem seç.')),
      );
      return;
    }
    setState(() {
      _from = range.start;
      _to = range.end;
    });
  }

  Widget _report(DevelopmentReport r, SwanPalette c) {
    final a = r.attendance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(r.athlete.name, style: SwanType.h2(c.ink)),
        Text(
          r.athlete.clubName ?? 'Ferdi sporcu',
          style: SwanType.bodySm(c.inkMuted),
        ),
        TextButton.icon(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) =>
                DevelopmentReportExport(request: _request, report: r),
          ),
          icon: const Icon(Icons.copy_rounded),
          label: const Text('Rapor metnini önizle'),
        ),
        _box(
          c,
          'Devam · kayıtlı etkinlikler',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                a.rate == null
                    ? 'Oran hesaplanamıyor'
                    : 'Devam oranı: %${reportNumber(a.rate!)}',
                style: SwanType.h3(c.ink),
              ),
              Text(
                'Katıldı: ${a.present} · Geç geldi: ${a.late} · Gelmedi: ${a.absent} · İzinli: ${a.excused}',
                style: SwanType.bodySm(c.ink),
              ),
              Text(
                'Geç gelenler katılmış sayılır. İzinliler paydaya girmez. Kaydedilmemiş yoklamalar devamsızlık sayılmaz.',
                style: SwanType.caption(c.inkMuted),
              ),
            ],
          ),
        ),
        _box(
          c,
          'Dönem ölçümleri',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (r.metrics.isEmpty)
                Text(
                  'Bu dönemde ölçüm kaydı yok.',
                  style: SwanType.body(c.inkMuted),
                ),
              for (final m in r.metrics)
                Padding(
                  padding: const EdgeInsets.only(bottom: SwanSpace.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${m.name} · ${m.category}',
                        style: SwanType.body(c.ink, w: FontWeight.w700),
                      ),
                      Text(
                        '${m.unit.isEmpty ? 'Birimsiz' : m.unit} · ${m.lowerIsBetter ? 'düşük değer iyi' : 'yüksek değer iyi'} · ${m.count} kayıt',
                        style: SwanType.caption(c.inkMuted),
                      ),
                      Text(m.summary, style: SwanType.bodySm(c.ink)),
                      Text(
                        '${reportDate(m.firstDate)} – ${reportDate(m.lastDate)}',
                        style: SwanType.caption(c.inkMuted),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        _box(
          c,
          'Hedefler · güncel durum',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dönem sonuna kadar açılan hedeflerin bugünkü durumu. Geçmiş ilerleme yüzdesi değildir.',
                style: SwanType.caption(c.inkMuted),
              ),
              if (r.goals.isEmpty)
                Text('Hedef kaydı yok.', style: SwanType.body(c.inkMuted)),
              for (final goal in r.goals)
                Padding(
                  padding: const EdgeInsets.only(top: SwanSpace.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.title,
                        style: SwanType.body(c.ink, w: FontWeight.w700),
                      ),
                      Text(
                        '${goal.statusLabel} · %${goal.progress} · ${goal.measured ? 'ölçüme bağlı' : 'elle takip'}',
                        style: SwanType.bodySm(c.inkMuted),
                      ),
                      if (goal.targetDate != null)
                        Text(
                          'Hedef tarihi: ${reportDate(goal.targetDate!)}',
                          style: SwanType.caption(c.inkMuted),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (r.gaps.isNotEmpty)
          _box(
            c,
            'Eksik veri ve kapsam',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final gap in r.gaps)
                  Text(gap, style: SwanType.bodySm(c.inkMuted)),
              ],
            ),
          ),
        TextButton(
          onPressed: () => ref.invalidate(developmentReportProvider(_request)),
          child: const Text('Raporu yenile'),
        ),
      ],
    );
  }

  Widget _trainingProgress(SwanPalette c) {
    final request = (
      athleteId: _athleteId!,
      from: _from,
      to: _to,
    );
    return ref.watch(trainingProgressProvider(request)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Text(
            'Antrenman gelişimi yüklenemedi.',
            style: SwanType.bodySm(c.danger),
          ),
          data: (entries) {
            final sports = entries.map((e) => e.sportCode).toSet().toList()
              ..sort();
            final sport =
                sports.contains(_trainingSport) ? _trainingSport : null;
            final bySport = entries
                .where((e) => sport == null || e.sportCode == sport)
                .toList();
            final sources = bySport.map((e) => e.sourceKind).toSet().toList()
              ..sort();
            final source =
                sources.contains(_trainingSource) ? _trainingSource : null;
            final bySource = bySport
                .where((e) => source == null || e.sourceKind == source)
                .toList();
            final clubs = bySource
                .where((e) => e.clubId != null)
                .map((e) => e.clubId!)
                .toSet()
                .toList();
            final club = clubs.contains(_trainingClub) ? _trainingClub : null;
            final filtered = bySource
                .where((e) => club == null || e.clubId == club)
                .toList();
            final groups = groupComparableTrainingProgress(filtered);

            return _box(
              c,
              'Branş bazlı antrenman gelişimi',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: SwanSpace.sm,
                    runSpacing: SwanSpace.sm,
                    children: [
                      DropdownButton<String?>(
                        value: sport,
                        hint: const Text('Tüm branşlar'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Tüm branşlar'),
                          ),
                          for (final code in sports)
                            DropdownMenuItem<String?>(
                              value: code,
                              child: Text(
                                SportsCatalog.findByCode(code)?.name ?? code,
                              ),
                            ),
                        ],
                        onChanged: (value) => setState(() {
                          _trainingSport = value;
                          _trainingSource = null;
                          _trainingClub = null;
                        }),
                      ),
                      DropdownButton<String?>(
                        value: source,
                        hint: const Text('Tüm kaynaklar'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Tüm kaynaklar'),
                          ),
                          for (final value in sources)
                            DropdownMenuItem<String?>(
                              value: value,
                              child: Text(
                                value == 'personal' ? 'Bireysel' : 'Antrenörlü',
                              ),
                            ),
                        ],
                        onChanged: (value) => setState(() {
                          _trainingSource = value;
                          _trainingClub = null;
                        }),
                      ),
                      if (clubs.length > 1)
                        DropdownButton<String?>(
                          value: club,
                          hint: const Text('Tüm kulüpler'),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Tüm kulüpler'),
                            ),
                            for (final id in clubs)
                              DropdownMenuItem<String?>(
                                value: id,
                                child: Text(
                                  bySource
                                          .where((e) => e.clubId == id)
                                          .firstOrNull
                                          ?.clubName ??
                                      'Kulüp',
                                ),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _trainingClub = value),
                        ),
                    ],
                  ),
                  if (filtered.isEmpty)
                    Text(
                      'Bu kapsamda antrenman ölçümü yok.',
                      style: SwanType.bodySm(c.inkMuted),
                    ),
                  for (final group in groups.values) _trainingGroup(c, group),
                ],
              ),
            );
          },
        );
  }

  Widget _trainingGroup(
    SwanPalette c,
    List<TrainingProgressEntry> group,
  ) {
    final first = group.first;
    final last = group.last;
    final comparable = group.length > 1;
    final delta = last.primaryValue - first.primaryValue;
    return Padding(
      padding: const EdgeInsets.only(top: SwanSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${SportsCatalog.findByCode(last.sportCode)?.name ?? last.sportCode} · ${last.workName}',
            style: SwanType.body(c.ink, w: FontWeight.w700),
          ),
          Text(
            '${last.isPersonal ? 'Bireysel' : 'Antrenörlü'}${last.clubName == null ? '' : ' · ${last.clubName}'}',
            style: SwanType.caption(c.inkMuted),
          ),
          Text(
            comparable
                ? '${_progressNumber(first.primaryValue)} → ${_progressNumber(last.primaryValue)} ${last.unit} '
                    '(${delta >= 0 ? '+' : ''}${_progressNumber(delta)})'
                : 'Son ölçüm: ${_progressNumber(last.primaryValue)} ${last.unit}',
            style: SwanType.bodySm(c.ink),
          ),
          if (!comparable)
            Text(
              'Karşılaştırılabilir ikinci kayıt yok.',
              style: SwanType.caption(c.inkMuted),
            ),
        ],
      ),
    );
  }

  static String _progressNumber(num value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  Widget _box(SwanPalette c, String title, Widget child) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: SwanSpace.lg),
        padding: const EdgeInsets.all(SwanSpace.md),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.line),
          borderRadius: BorderRadius.circular(SwanRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: SwanType.h3(c.ink)),
            const SizedBox(height: SwanSpace.sm),
            child,
          ],
        ),
      );
}
