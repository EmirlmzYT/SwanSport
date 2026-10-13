import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../app/modules/console_module.dart';
import '../../app/shell/too_narrow_notice.dart';
import '../../app/theme/console_theme.dart';
import '../../app/widgets/status_pill.dart';
import 'referee_assignments_screen.dart';

String penaltyLabel(String kind) => switch(kind) {
  'match_ban' => 'Maç Men Cezası', 'rights_ban' => 'Hak Mahrumiyeti', 'fine' => 'Para Cezası', _ => 'İhtar'};

class DisciplinaryBoardScreen extends ConsumerStatefulWidget {
  const DisciplinaryBoardScreen({super.key});
  @override
  ConsumerState<DisciplinaryBoardScreen> createState() => _DisciplinaryBoardScreenState();
}
class _DisciplinaryBoardScreenState extends ConsumerState<DisciplinaryBoardScreen> {
  int _offset = 0;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < ConsoleDensity.minSupportedWidth) return const TooNarrowNotice();
    if (!ref.watch(consoleAccessProvider).isDisciplinaryBoardMember) return const Center(child: Text('Aktif Başkan/Disiplin Kurulu görevi gerekli.'));
    final data = ref.watch(federationDisciplinaryReportsProvider(_offset));
    return Padding(padding: const EdgeInsets.all(ConsoleDensity.xl), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text('Disiplin Kurulu · İmzalı Rapor Kuyruğu', style: Theme.of(context).textTheme.headlineSmall)),
        IconButton(tooltip: 'Yenile', onPressed: () => ref.invalidate(federationDisciplinaryReportsProvider), icon: const Icon(Icons.refresh))]),
      const Text('Özel hakem raporları · En eski önce · Kırmızı kart otomatik ceza değildir; kurul kararı gerekir.'),
      const SizedBox(height: ConsoleDensity.lg),
      Expanded(child: data.when(loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: TextButton(onPressed: () => ref.invalidate(federationDisciplinaryReportsProvider(_offset)), child: const Text('Raporlar alınamadı. Tekrar dene'))),
        data: (page) => page.rows.isEmpty ? const Center(child: Text('Bu kapsamda imzalı maç raporu yok.')) : ListView.separated(
          itemCount: page.rows.length, separatorBuilder: (_, __) => const SizedBox(height: ConsoleDensity.md),
          itemBuilder: (context, i) {
            final r = page.rows[i];
            return Card(child: Padding(padding: const EdgeInsets.all(ConsoleDensity.lg), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text('${r.program} · ${r.sportCode} · İl ${r.cityCode ?? 'Ulusal'}', style: Theme.of(context).textTheme.titleMedium)),
                StatusPill(label: '${r.redCardAthleteIds.length} kırmızı kart', tone: r.redCardAthleteIds.isEmpty ? PillTone.info : PillTone.bad)]),
              Text('İmzalandı: ${federationDate(r.signedAt)} · ${r.matchId}'),
              const SizedBox(height: ConsoleDensity.md),
              Text(r.notes),
              for (final d in r.decisions) Padding(padding: const EdgeInsets.only(top: ConsoleDensity.sm), child: Text(
                '${penaltyLabel(d.penaltyType)}${d.matchBanCount == null ? '' : ' · ${d.matchBanCount} maç'}${d.months == null ? '' : ' · ${d.months} ay'}${d.fineAmount == null ? '' : ' · ${fmtMoney(d.fineAmount!)}'} · ${d.reason}')),
              const SizedBox(height: ConsoleDensity.md),
              FilledButton.icon(onPressed: !r.canDecide || r.athletes.every((a) => r.decisions.any((d) => d.athleteId == a.athleteId)) ? null :
                () => showDialog<void>(context: context, barrierDismissible: false, builder: (_) => DisciplinaryDecisionDialog(report: r)),
                icon: const Icon(Icons.gavel_rounded), label: const Text('Ceza Kararı Gir')),
            ])));
          }))),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [Text('${_offset + 1}–${_offset + (data.asData?.value.rows.length ?? 0)} / ${data.asData?.value.total ?? 0}'),
        IconButton(tooltip: 'Önceki sayfa', onPressed: _offset == 0 ? null : () => setState(() => _offset -= 50), icon: const Icon(Icons.chevron_left)),
        IconButton(tooltip: 'Sonraki sayfa', onPressed: _offset + 50 >= (data.asData?.value.total ?? 0) ? null : () => setState(() => _offset += 50), icon: const Icon(Icons.chevron_right))]),
    ]));
  }
}

class DisciplinaryDecisionDialog extends ConsumerStatefulWidget {
  const DisciplinaryDecisionDialog({required this.report, super.key});
  final FederationDisciplinaryReport report;
  @override
  ConsumerState<DisciplinaryDecisionDialog> createState() => _DisciplinaryDecisionDialogState();
}
class _DisciplinaryDecisionDialogState extends ConsumerState<DisciplinaryDecisionDialog> {
  final _reason = TextEditingController();
  final _fine = TextEditingController();
  final _form = GlobalKey<FormState>();
  String? _athlete, _actor, _error;
  String _kind = 'match_ban';
  int _count = 1;
  bool _busy = false;
  Map<String, dynamic>? _pending;
  @override
  void initState() {super.initState();_actor = ref.read(authSessionProvider).valueOrNull?.user.id;}
  @override
  void dispose() {_reason.dispose();_fine.dispose();super.dispose();}
  @override
  Widget build(BuildContext context) {
    if (ref.watch(authSessionProvider).valueOrNull?.user.id != _actor || !ref.watch(consoleAccessProvider).isDisciplinaryBoardMember) {
      return const AlertDialog(content: Text('Oturum/yetki değişti. Bu pencereyi kapatın.'));
    }
    final locked = _busy || _pending != null;
    return PopScope(canPop: !locked, child: AlertDialog(title: const Text('Disiplin Kararı'),
      content: SizedBox(width: ConsoleDensity.loginCardWidth, child: SingleChildScrollView(child: Form(key: _form, child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Karar değiştirilemez. İhtar/para cezası esameyi kilitlemez. Para cezası mali deftere otomatik tahakkuk ettirilmez.'),
        const SizedBox(height: ConsoleDensity.md),
        DropdownButtonFormField<String>(value: _athlete, decoration: const InputDecoration(labelText: 'Esamedeki sporcu (maskeli kimlik)'),
          items: [for (final a in widget.report.athletes.where((a) => !widget.report.decisions.any((d) => d.athleteId == a.athleteId)))
            DropdownMenuItem(value: a.athleteId, child: Text('${a.reference}${widget.report.redCardAthleteIds.contains(a.athleteId) ? ' · Kırmızı kart' : ''}'))],
          validator: (v) => v == null ? 'Sporcu seçin' : null, onChanged: locked ? null : (v) => setState(() => _athlete = v)),
        DropdownButtonFormField<String>(value: _kind, decoration: const InputDecoration(labelText: 'Ceza türü'),
          items: [for (final k in ['match_ban','rights_ban','warning','fine']) DropdownMenuItem(value: k, child: Text(penaltyLabel(k)))],
          onChanged: locked ? null : (v) => setState(() {_kind = v!;_count = 1;})),
        if (_kind == 'match_ban' || _kind == 'rights_ban') DropdownButtonFormField<int>(value: _count,
          decoration: InputDecoration(labelText: _kind == 'match_ban' ? 'Maç sayısı' : 'Ay sayısı'),
          items: [for (var i = 1; i <= (_kind == 'match_ban' ? 10 : 12); i++) DropdownMenuItem(value: i, child: Text('$i'))],
          onChanged: locked ? null : (v) => setState(() => _count = v!)),
        if (_kind == 'fine') TextFormField(controller: _fine, enabled: !locked,
          decoration: const InputDecoration(labelText: 'Para cezası (₺)'), keyboardType: TextInputType.number,
          validator: (v) {final n = double.tryParse((v ?? '').replaceAll(',', '.'));return n == null || !n.isFinite || n <= 0 ? 'Pozitif tutar girin' : null;}),
        TextFormField(controller: _reason, enabled: !locked, maxLength: 1000, minLines: 3, maxLines: 5,
          decoration: const InputDecoration(labelText: 'Gerekçeli karar'), validator: (v) => (v ?? '').trim().isEmpty ? 'Gerekçe zorunlu' : null),
        if (_error != null) Text(_error!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error)),
      ])))), actions: [TextButton(onPressed: locked ? null : () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(onPressed: _busy ? null : _save, child: _busy ? const CircularProgressIndicator() : Text(_pending == null ? 'Kararı Kaydet' : 'Aynı İşlemi Tekrar Dene'))]));
  }
  Future<void> _save() async {
    if (_pending == null && !_form.currentState!.validate()) return;
    _pending ??= {'p_match_id': widget.report.matchId, 'p_athlete_id': _athlete,
      'p_operation_id': refereeOperationId(), 'p_penalty_type': _kind, 'p_reason': _reason.text.trim(),
      'p_match_ban_count': _kind == 'match_ban' ? _count : null, 'p_months': _kind == 'rights_ban' ? _count : null,
      'p_fine_amount': _kind == 'fine' ? double.parse(_fine.text.replaceAll(',', '.')) : null};
    setState(() {_busy = true;_error = null;});
    try {
      final service = ref.read(federationConsoleServiceProvider);
      if (service == null) { _pending = null;throw StateError('Backend gerekli.'); }
      await service.recordDecision(Map.unmodifiable(_pending!));
      if (!mounted || ref.read(authSessionProvider).valueOrNull?.user.id != _actor) return;
      ref.invalidate(federationDisciplinaryReportsProvider);Navigator.pop(context);
    } catch (e) {
      // Definite validation/permission rejections permit edits; a lost reply
      // retains the exact operation ID/payload, never silently duplicates.
      if (e is PostgrestException && ['22023','23514','23502','42501','55000'].contains(e.code)) _pending = null;
      if (mounted) setState(() => _error = _pending == null ? 'Karar reddedildi. Yetki, dosya ve alanları kontrol edin.' : 'Sonuç belirsiz. Aynı işlem kimliğiyle tekrar deneyin.');
    } finally {if (mounted) setState(() => _busy = false);}
  }
}
