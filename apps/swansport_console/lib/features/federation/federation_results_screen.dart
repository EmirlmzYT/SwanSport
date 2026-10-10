import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/modules/console_module.dart';
import '../../app/theme/console_theme.dart';

class FederationResultsScreen extends ConsumerStatefulWidget {
  const FederationResultsScreen({super.key});
  @override
  ConsumerState<FederationResultsScreen> createState() =>
      _FederationResultsScreenState();
}

class _FederationResultsScreenState
    extends ConsumerState<FederationResultsScreen> {
  int _offset = 0;
  @override
  Widget build(BuildContext context) {
    if (!ref.watch(consoleAccessProvider).canPublishFederationResults) {
      return const Center(child: Text('Sonuç yayımlama görevi gerekli.'));
    }
    return Padding(
        padding: const EdgeInsets.all(ConsoleDensity.xl),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text('Resmi Müsabaka Sonuçları',
                    style: Theme.of(context).textTheme.headlineSmall)),
            IconButton(
                tooltip: 'Listeyi yenile',
                onPressed: () =>
                    ref.invalidate(federationPendingResultsProvider(_offset)),
                icon: const Icon(Icons.refresh))
          ]),
          const Text(
              'Görevli olduğunuz branş ve ilde sonuç bekleyen resmi müsabakalar.'),
          const SizedBox(height: ConsoleDensity.lg),
          Expanded(
              child: ref.watch(federationPendingResultsProvider(_offset)).when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) => Center(
                        child: TextButton(
                            onPressed: () => ref.invalidate(
                                federationPendingResultsProvider(_offset)),
                            child:
                                const Text('Liste yüklenemedi. Yeniden dene'))),
                    data: (rows) => Column(children: [
                      Expanded(
                          child: rows.isEmpty
                              ? const Center(
                                  child: Text(
                                      'Bu sayfada sonuç bekleyen müsabaka yok.'))
                              : ListView.separated(
                                  itemCount: rows.length,
                                  separatorBuilder: (_, __) => const Divider(),
                                  itemBuilder: (context, i) {
                                    final m = rows[i];
                                    final allowed = ref
                                        .watch(consoleAccessProvider)
                                        .canWriteFederation(
                                            m.sportCode,
                                            m.cityCode,
                                            FederationDuty.resultPublisher);
                                    return ListTile(
                                        title: Text(m.name),
                                        subtitle: Text([
                                          m.sportCode,
                                          if (m.cityCode != null)
                                            'İl ${m.cityCode}',
                                          if (m.startsAt != null)
                                            _date(m.startsAt!),
                                          '${m.homeName ?? 'Katılımcı'} — ${m.awayName ?? 'Bireysel seri'}',
                                        ].join(' · ')),
                                        trailing: FilledButton(
                                            onPressed: !allowed
                                                ? null
                                                : () async {
                                                    await showDialog<void>(
                                                        context: context,
                                                        barrierDismissible:
                                                            false,
                                                        builder: (_) =>
                                                            Dialog.fullscreen(
                                                                child:
                                                                    FederationResultForm(
                                                                        match:
                                                                            m)));
                                                    ref.invalidate(
                                                        federationPendingResultsProvider(
                                                            _offset));
                                                  },
                                            child: const Text('Sonuç Gir')));
                                  })),
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        TextButton(
                            onPressed: _offset == 0
                                ? null
                                : () => setState(() => _offset -= 100),
                            child: const Text('Önceki')),
                        Text('${_offset + 1}–${_offset + rows.length}'),
                        TextButton(
                            onPressed: rows.length < 100
                                ? null
                                : () => setState(() => _offset += 100),
                            child: const Text('Sonraki')),
                      ]),
                    ]),
                  )),
        ]));
  }
}

class FederationResultForm extends ConsumerStatefulWidget {
  const FederationResultForm({super.key, required this.match});
  final FederationPendingMatch match;
  @override
  ConsumerState<FederationResultForm> createState() =>
      _FederationResultFormState();
}

class _Pair {
  int tbTarget = 7;
  final home = TextEditingController(), away = TextEditingController();
  final tbHome = TextEditingController(), tbAway = TextEditingController();
  final foulHome = TextEditingController(), foulAway = TextEditingController();
  Map<String, dynamic> score() =>
      {'home': _int(home, 'Ev sahibi'), 'away': _int(away, 'Deplasman')};
  void dispose() {
    home.dispose();
    away.dispose();
    tbHome.dispose();
    tbAway.dispose();
    foulHome.dispose();
    foulAway.dispose();
  }
}

class _Performance {
  String? athlete;
  String status = 'finished';
  final lane = TextEditingController(), heat = TextEditingController(text: '1');
  final time = TextEditingController(),
      rank = TextEditingController(),
      series = TextEditingController();
  void dispose() {
    lane.dispose();
    heat.dispose();
    time.dispose();
    rank.dispose();
    series.dispose();
  }
}

class _Incident {
  String? athlete;
  String team = 'home', card = 'yellow';
  final minute = TextEditingController(),
      added = TextEditingController(text: '0');
  void dispose() {
    minute.dispose();
    added.dispose();
  }
}

class _FederationResultFormState extends ConsumerState<FederationResultForm> {
  final _reason = TextEditingController();
  late final List<_Pair> _scores;
  final _extras = <_Pair>[],
      _performances = <_Performance>[],
      _goals = <_Incident>[],
      _cards = <_Incident>[];
  final _penalties = <({String team, bool scored})>[];
  bool _knockout = false, _busy = false, _uncertain = false;
  int _bestOf = 3;
  String? _error;
  String get _sport => widget.match.sportCode;
  bool get _individual =>
      const {'yuzme', 'atletizm', 'okculuk'}.contains(_sport);
  @override
  void initState() {
    super.initState();
    _scores = List.generate(_sport == 'basketbol' ? 4 : 2, (_) => _Pair());
  }

  @override
  void dispose() {
    _reason.dispose();
    for (final row in [..._scores, ..._extras]) {
      row.dispose();
    }
    for (final row in _performances) {
      row.dispose();
    }
    for (final row in [..._goals, ..._cards]) {
      row.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _protocol() {
    final raw = <String, dynamic>{'sport_code': _sport, 'status': 'finished'};
    if (_sport == 'basketbol') {
      raw['periods'] = [
        for (var i = 0; i < _scores.length; i++)
          {
            ..._scores[i].score(),
            'label': i < 4 ? 'Q${i + 1}' : 'OT${i - 3}',
            'team_fouls': {
              'home': _int(_scores[i].foulHome, 'Ev sahibi takım faulü'),
              'away': _int(_scores[i].foulAway, 'Deplasman takım faulü')
            }
          }
      ];
    } else if (_sport == 'futbol') {
      raw.addAll({
        'halves': [for (final s in _scores) s.score()],
        'knockout': _knockout,
        'extra_time': [for (final s in _extras) s.score()],
        'penalties': [
          for (final p in _penalties) {'team': p.team, 'scored': p.scored}
        ],
        'goals': [for (final g in _goals) _incident(g, false)],
        'cards': [for (final c in _cards) _incident(c, true)]
      });
    } else if (_sport == 'tenis') {
      raw.addAll({
        'best_of': _bestOf,
        'sets': [
          for (final s in _scores)
            {
              ...s.score(),
              'tie_break_target': s.tbTarget,
              if (s.tbHome.text.isNotEmpty || s.tbAway.text.isNotEmpty)
                'tie_break': {
                  'home': _int(s.tbHome, 'Tie-break ev sahibi'),
                  'away': _int(s.tbAway, 'Tie-break deplasman')
                },
            }
        ]
      });
    } else if (_individual) {
      raw['performances'] = [
        for (final p in _performances)
          {
            'athlete_ref': p.athlete,
            'lane': _int(p.lane, 'Kulvar/hedef'),
            'heat': _int(p.heat, 'Seri'),
            'dq': p.status == 'dq',
            'dnf': p.status == 'dnf',
            if (p.status == 'finished') ...{
              'rank': _int(p.rank, 'Sıra'),
              if (_sport == 'okculuk')
                'series': [
                  for (final value in p.series.text.split(','))
                    _parse(value.trim(), 'Seri puanı')
                ]
              else
                'time': p.time.text.trim(),
            },
          }
      ];
    } else {
      throw const FormatException('Bu branş için sonuç formu desteklenmiyor');
    }
    return normalizeOfficialResult(_sport, raw);
  }

  Map<String, dynamic> _incident(_Incident row, bool card) => {
        'minute': _int(row.minute, 'Dakika'),
        'added_time': _int(row.added, 'Uzatma dakikası'),
        'player_ref': row.athlete,
        'team': row.team,
        if (card) 'card': row.card,
      };

  Future<void> _publish() async {
    if (_busy || _uncertain) return;
    if (!ref.read(consoleAccessProvider).canWriteFederation(
        _sport, widget.match.cityCode, FederationDuty.resultPublisher)) {
      setState(() => _error = 'Geçerli sonuç yayımlama görevi gerekli.');
      return;
    }
    Map<String, dynamic> raw;
    try {
      raw = _protocol();
      if (_reason.text.trim().isEmpty)
        throw const FormatException('Yayın gerekçesi gerekli');
    } catch (e) {
      setState(() => _error = '$e');
      return;
    }
    final service = ref.read(federationRecordsServiceProvider);
    if (service == null) {
      setState(() => _error = 'Sunucu bağlantısı gerekli.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await service.publishOfficialResult(
          match: widget.match, protocol: raw, reason: _reason.text);
      if (!mounted) return;
      ref.invalidate(federationPendingResultsProvider);
      for (final a in ref
              .read(federationResultCardProvider(widget.match.id))
              .valueOrNull
              ?.athletes ??
          const <({String athleteId, String? name})>[]) {
        ref.invalidate(officialAchievementsProvider(a.athleteId));
      }
      Navigator.pop(context);
    } catch (e) {
      if (mounted)
        setState(() {
          _uncertain = true;
          _error =
              'Yayın doğrulanamadı. Yeniden göndermeden önce sunucu durumunu kontrol edin. $e';
        });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check() async {
    setState(() => _busy = true);
    try {
      ref.invalidate(federationResultCardProvider(widget.match.id));
      final card =
          await ref.read(federationResultCardProvider(widget.match.id).future);
      if (!mounted) return;
      if (card.version > widget.match.version) {
        Navigator.pop(context);
        return;
      }
      setState(() {
        _uncertain = false;
        _error =
            'Sunucuda sonuç kaydı yok. Formu kontrol edip tekrar yayımlayabilirsiniz.';
      });
    } catch (_) {
      if (mounted)
        setState(() =>
            _error = 'Sunucu durumu doğrulanamadı. Bağlantıyı kontrol edin.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allowed = ref.watch(consoleAccessProvider).canWriteFederation(
        _sport, widget.match.cityCode, FederationDuty.resultPublisher);
    final card = ref.watch(federationResultCardProvider(widget.match.id));
    return PopScope(
        canPop: !_busy,
        child: Scaffold(
          appBar: AppBar(
              title: Text(widget.match.name),
              automaticallyImplyLeading: false,
              actions: [
                TextButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: const Text('Kapat'))
              ]),
          body: !allowed
              ? const Center(child: Text('Sonuç yayımlama görevi gerekli.'))
              : card.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => Center(
                      child: TextButton(
                          onPressed: () => ref.invalidate(
                              federationResultCardProvider(widget.match.id)),
                          child: const Text(
                              'Resmi kadro yüklenemedi. Yeniden dene'))),
                  data: (data) => SingleChildScrollView(
                      padding: const EdgeInsets.all(ConsoleDensity.xl),
                      child: AbsorbPointer(
                          absorbing: _busy || _uncertain,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '${widget.match.homeName ?? 'Katılımcı'} — ${widget.match.awayName ?? 'Bireysel seri'}',
                                    style:
                                        Theme.of(context).textTheme.titleLarge),
                                Text(
                                    '$_sport · Resmi sonuç revizyonu ${widget.match.version + 1}'),
                                const Text(
                                    'Yayın, sonucu ve sporcu sicilini birlikte kaydeder. Eski kayıtlar değiştirilemez.'),
                                const SizedBox(height: ConsoleDensity.xl),
                                if (!_individual) ...[
                                  if (_sport == 'tenis')
                                    DropdownButtonFormField<int>(
                                        initialValue: _bestOf,
                                        decoration: const InputDecoration(
                                            labelText: 'Maç formatı'),
                                        items: const [
                                          DropdownMenuItem(
                                              value: 3,
                                              child: Text('3 setin 2’si')),
                                          DropdownMenuItem(
                                              value: 5,
                                              child: Text('5 setin 3’ü'))
                                        ],
                                        onChanged: (v) =>
                                            setState(() => _bestOf = v!)),
                                  for (var i = 0; i < _scores.length; i++)
                                    _pair(
                                        _scores[i],
                                        _sport == 'basketbol'
                                            ? (i < 4
                                                ? 'Q${i + 1}'
                                                : 'OT${i - 3}')
                                            : _sport == 'tenis'
                                                ? 'Set ${i + 1}'
                                                : '${i + 1}. Devre',
                                        tieBreak: _sport == 'tenis'),
                                  if (_sport == 'basketbol' ||
                                      _sport == 'tenis')
                                    Row(children: [
                                      TextButton(
                                          onPressed: (_sport == 'basketbol' &&
                                                      _scores.length < 24) ||
                                                  (_sport == 'tenis' &&
                                                      _scores.length < _bestOf)
                                              ? () => setState(
                                                  () => _scores.add(_Pair()))
                                              : null,
                                          child: Text(_sport == 'basketbol'
                                              ? 'Uzatma Ekle'
                                              : 'Set Ekle')),
                                      TextButton(
                                          onPressed: _scores.length >
                                                  (_sport == 'basketbol'
                                                      ? 4
                                                      : 2)
                                              ? () => setState(() => _scores
                                                  .removeLast()
                                                  .dispose())
                                              : null,
                                          child:
                                              const Text('Son satırı kaldır'))
                                    ]),
                                  if (_sport == 'futbol') ...[
                                    SwitchListTile(
                                        title: const Text('Eleme maçı'),
                                        value: _knockout,
                                        onChanged: (v) =>
                                            setState(() => _knockout = v)),
                                    if (_knockout) ...[
                                      TextButton(
                                          onPressed: () => setState(() {
                                                if (_extras.isEmpty) {
                                                  _extras.addAll(
                                                      [_Pair(), _Pair()]);
                                                } else {
                                                  for (final e in _extras) {
                                                    e.dispose();
                                                  }
                                                  _extras.clear();
                                                }
                                              }),
                                          child: Text(_extras.isEmpty
                                              ? 'Uzatma devreleri ekle'
                                              : 'Uzatma devrelerini kaldır')),
                                      for (var i = 0; i < _extras.length; i++)
                                        _pair(_extras[i], 'Uzatma ${i + 1}'),
                                      const Text(
                                          'Seri penaltılar: atışları gerçekleştiği sırayla girin.'),
                                      for (var i = 0;
                                          i < _penalties.length;
                                          i++)
                                        ListTile(
                                            title: Text(
                                                '${i + 1}. atış · ${_penalties[i].team == 'home' ? 'Ev sahibi' : 'Deplasman'}'),
                                            trailing: Switch(
                                                value: _penalties[i].scored,
                                                onChanged: (v) => setState(() =>
                                                    _penalties[i] = (
                                                      team: _penalties[i].team,
                                                      scored: v
                                                    )))),
                                      Wrap(
                                          spacing: ConsoleDensity.sm,
                                          children: [
                                            for (final team in ['home', 'away'])
                                              TextButton(
                                                  onPressed: () => setState(
                                                      () => _penalties.add((
                                                            team: team,
                                                            scored: false
                                                          ))),
                                                  child: Text(team == 'home'
                                                      ? 'Ev sahibi penaltısı'
                                                      : 'Deplasman penaltısı')),
                                            TextButton(
                                                onPressed: _penalties.isEmpty
                                                    ? null
                                                    : () => setState(() =>
                                                        _penalties
                                                            .removeLast()),
                                                child: const Text(
                                                    'Son atışı kaldır'))
                                          ]),
                                    ],
                                    _incidents(_goals, 'Goller', false, data),
                                    _incidents(_cards, 'Kartlar', true, data),
                                  ],
                                ] else ...[
                                  const Text(
                                      'Resmi kadrodan sporcu seçin. Her seri kendi içinde sıralanır. DQ/DNF için derece girilmez.'),
                                  for (var i = 0; i < _performances.length; i++)
                                    _performance(_performances[i], i, data),
                                  TextButton.icon(
                                      onPressed: () => setState(() =>
                                          _performances.add(_Performance())),
                                      icon: const Icon(Icons.add),
                                      label: const Text('Sporcu / seri ekle')),
                                ],
                                const SizedBox(height: ConsoleDensity.lg),
                                TextField(
                                    controller: _reason,
                                    maxLength: 500,
                                    decoration: const InputDecoration(
                                        labelText: 'Onay / yayın gerekçesi')),
                                if (_error != null)
                                  Text(_error!,
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error)),
                                const SizedBox(height: ConsoleDensity.lg),
                                FilledButton.icon(
                                    onPressed:
                                        _busy || _uncertain ? null : _publish,
                                    icon: const Icon(Icons.verified_user),
                                    label: Text(_busy
                                        ? 'Yayımlanıyor…'
                                        : 'Sonucu Onayla ve Yayınla')),
                              ]))),
                ),
          bottomNavigationBar: !_uncertain
              ? null
              : Padding(
                  padding: const EdgeInsets.all(ConsoleDensity.lg),
                  child: FilledButton(
                      onPressed: _busy ? null : _check,
                      child: const Text('Sunucu durumunu kontrol et'))),
        ));
  }

  Widget _pair(_Pair pair, String label, {bool tieBreak = false}) => Padding(
      key: ObjectKey(pair),
      padding: const EdgeInsets.symmetric(vertical: ConsoleDensity.sm),
      child: Row(children: [
        Expanded(child: Text(label)),
        Expanded(child: _field(pair.home, 'Ev sahibi')),
        const SizedBox(width: ConsoleDensity.sm),
        Expanded(child: _field(pair.away, 'Deplasman')),
        if (_sport == 'basketbol') ...[
          const SizedBox(width: ConsoleDensity.sm),
          Expanded(child: _field(pair.foulHome, 'Takım faulü ev')),
          const SizedBox(width: ConsoleDensity.sm),
          Expanded(child: _field(pair.foulAway, 'Takım faulü dep.')),
        ],
        if (tieBreak) ...[
          const SizedBox(width: ConsoleDensity.sm),
          Expanded(child: _field(pair.tbHome, 'Tie-break ev (varsa)')),
          const SizedBox(width: ConsoleDensity.sm),
          Expanded(child: _field(pair.tbAway, 'Tie-break dep. (varsa)')),
          const SizedBox(width: ConsoleDensity.sm),
          Expanded(
              child: DropdownButtonFormField<int>(
                  initialValue: pair.tbTarget,
                  decoration:
                      const InputDecoration(labelText: 'Tie-break hedefi'),
                  items: const [
                    DropdownMenuItem(value: 7, child: Text('7 puan')),
                    DropdownMenuItem(value: 10, child: Text('10 puan'))
                  ],
                  onChanged: (v) => setState(() => pair.tbTarget = v!)))
        ],
      ]));
  Widget _athlete(FederationResultCard card, String? value,
          ValueChanged<String?> change) =>
      DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Resmi kadro sporcusu'),
          items: [
            for (var i = 0; i < card.athletes.length; i++)
              DropdownMenuItem(
                  value: card.athletes[i].athleteId,
                  child: Text(card.athletes[i].name ?? 'Sporcu ${i + 1}'))
          ],
          onChanged: change);
  Widget _performance(_Performance p, int i, FederationResultCard card) => Card(
      key: ObjectKey(p),
      child: Padding(
          padding: const EdgeInsets.all(ConsoleDensity.lg),
          child: Column(children: [
            Row(children: [
              Expanded(
                  child: _athlete(
                      card, p.athlete, (v) => setState(() => p.athlete = v))),
              IconButton(
                  tooltip: 'Seri satırını kaldır',
                  onPressed: () =>
                      setState(() => _performances.removeAt(i).dispose()),
                  icon: const Icon(Icons.close))
            ]),
            const SizedBox(height: ConsoleDensity.sm),
            Row(children: [
              Expanded(child: _field(p.heat, 'Seri')),
              const SizedBox(width: ConsoleDensity.sm),
              Expanded(
                  child:
                      _field(p.lane, _sport == 'okculuk' ? 'Hedef' : 'Kulvar')),
              const SizedBox(width: ConsoleDensity.sm),
              Expanded(
                  child: DropdownButtonFormField<String>(
                      initialValue: p.status,
                      items: const [
                        DropdownMenuItem(
                            value: 'finished', child: Text('Tamamladı')),
                        DropdownMenuItem(value: 'dq', child: Text('DQ')),
                        DropdownMenuItem(value: 'dnf', child: Text('DNF'))
                      ],
                      onChanged: (v) => setState(() => p.status = v!)))
            ]),
            if (p.status == 'finished')
              Row(children: [
                Expanded(child: _field(p.rank, 'Resmi sıra')),
                const SizedBox(width: ConsoleDensity.sm),
                Expanded(
                    child: _sport == 'okculuk'
                        ? TextField(
                            controller: p.series,
                            decoration: const InputDecoration(
                                labelText: 'Seri puanları (25, 28, 30)'))
                        : TextField(
                            controller: p.time,
                            decoration: const InputDecoration(
                                labelText: 'Resmi derece (01:02.345)')))
              ]),
          ])));
  Widget _incidents(List<_Incident> rows, String label, bool cards,
          FederationResultCard card) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        for (var i = 0; i < rows.length; i++)
          Padding(
              key: ObjectKey(rows[i]),
              padding: const EdgeInsets.symmetric(vertical: ConsoleDensity.sm),
              child: Row(children: [
                Expanded(
                    child: _athlete(card, rows[i].athlete,
                        (v) => setState(() => rows[i].athlete = v))),
                const SizedBox(width: ConsoleDensity.sm),
                Expanded(child: _field(rows[i].minute, 'Dakika')),
                const SizedBox(width: ConsoleDensity.sm),
                Expanded(child: _field(rows[i].added, '+ dakika')),
                Expanded(
                    child: DropdownButtonFormField<String>(
                        initialValue: rows[i].team,
                        items: const [
                          DropdownMenuItem(
                              value: 'home', child: Text('Ev sahibi')),
                          DropdownMenuItem(
                              value: 'away', child: Text('Deplasman'))
                        ],
                        onChanged: (v) => setState(() => rows[i].team = v!))),
                if (cards)
                  Expanded(
                      child: DropdownButtonFormField<String>(
                          initialValue: rows[i].card,
                          items: const [
                            DropdownMenuItem(
                                value: 'yellow', child: Text('Sarı')),
                            DropdownMenuItem(
                                value: 'red', child: Text('Kırmızı'))
                          ],
                          onChanged: (v) => setState(() => rows[i].card = v!))),
                IconButton(
                    tooltip: 'Olayı kaldır',
                    onPressed: () => setState(() => rows.removeAt(i).dispose()),
                    icon: const Icon(Icons.close)),
              ])),
        TextButton(
            onPressed: () => setState(() => rows.add(_Incident())),
            child: Text('$label ekle (isteğe bağlı)')),
      ]);
}

Widget _field(TextEditingController controller, String label) => TextField(
    controller: controller,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(labelText: label));
int _parse(String value, String label) {
  final v = int.tryParse(value);
  if (v == null || v < 0)
    throw FormatException('$label: sıfır veya pozitif tamsayı gerekli');
  return v;
}

int _int(TextEditingController c, String label) => _parse(c.text.trim(), label);
String _date(DateTime d) {
  final t = calendarTurkeyTime(d);
  return '${t.day}.${t.month}.${t.year} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
