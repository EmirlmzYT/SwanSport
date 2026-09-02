import 'package:flutter/material.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';

/// Set sonucu girişi.
///
/// EKSİK ≠ SIFIR. Boş bırakılan ok `null` gidiyor, sıfır değil. Ekranda da
/// "—" görünüyor: sporcu 0 ile boş arasındaki farkı görebilmeli, çünkü
/// ikisi farklı gerçek ("ıskaladım" ve "atmadım").
///
/// Zorunlu yorum yok — spec'in kararı. Yorum zorunlu olsaydı sporcu her
/// sete rastgele bir şey yazar, veri kirlenirdi.
class ScorePad extends StatefulWidget {
  const ScorePad({
    super.key,
    required this.config,
    required this.setNo,
    required this.branch,
    this.existing,
    required this.onSubmit,
  });

  final TrainingProtocolConfig config;
  final int setNo;

  /// Branşın kelimeleri — okçulukta "ok".
  final BranchDefinitionContract? branch;

  /// Daha önce girilmiş sonuç (düzeltme).
  final TrainingSet? existing;

  /// [total] ya da [entries] doluyor; hangisi biçime bağlı.
  final Future<void> Function({num? total, List<num?>? entries}) onSubmit;

  @override
  State<ScorePad> createState() => _ScorePadState();
}

class _ScorePadState extends State<ScorePad> {
  late List<num?> _entries;
  late bool _detailed;
  final _totalCtrl = TextEditingController();
  String? _error;
  bool _busy = false;

  String get _unit => (widget.branch as ArcheryDefinition?)?.unitLabel ?? 'atış';

  @override
  void initState() {
    super.initState();
    _detailed = widget.config.entryMode.allowsDetailed &&
        widget.config.entryMode != ScoreEntryMode.flexible;
    // Esnek biçimde varsayılan basit: daha az dokunuş.
    if (widget.config.entryMode == ScoreEntryMode.detailed) _detailed = true;

    _entries = List<num?>.filled(widget.config.unitsPerSet, null);
    final prev = widget.existing;
    if (prev != null) {
      for (var i = 0; i < prev.entries.length && i < _entries.length; i++) {
        _entries[i] = prev.entries[i];
      }
      if (prev.totalScore != null) {
        _totalCtrl.text = _fmt(prev.totalScore!);
      }
      if (prev.entries.isNotEmpty) _detailed = true;
    }
  }

  @override
  void dispose() {
    _totalCtrl.dispose();
    super.dispose();
  }

  static String _fmt(num v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  Future<void> _save() async {
    setState(() => _error = null);

    if (_detailed) {
      final check = checkEntries(_entries,
          unitsPerSet: widget.config.unitsPerSet,
          maxUnitScore: widget.config.maxUnitScore);
      if (!check.isValid) {
        setState(() => _error = check.error);
        return;
      }
    } else {
      final raw = _totalCtrl.text.trim().replaceAll(',', '.');
      final total = raw.isEmpty ? null : num.tryParse(raw);
      if (raw.isNotEmpty && total == null) {
        setState(() => _error = 'Puanı sayı olarak yaz');
        return;
      }
      final check = checkSetTotal(total,
          unitsPerSet: widget.config.unitsPerSet,
          maxUnitScore: widget.config.maxUnitScore);
      if (!check.isValid) {
        setState(() => _error = check.error);
        return;
      }
    }

    setState(() => _busy = true);
    try {
      if (_detailed) {
        await widget.onSubmit(entries: _entries);
      } else {
        final raw = _totalCtrl.text.trim().replaceAll(',', '.');
        await widget.onSubmit(total: raw.isEmpty ? null : num.tryParse(raw));
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final locked = widget.existing?.locked ?? false;

    return Container(
      padding: const EdgeInsets.all(SwanSpace.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('${widget.setNo}. set', style: SwanType.h3(c.ink)),
          const Spacer(),
          if (locked)
            Row(children: [
              Icon(Icons.lock_rounded, size: 14, color: c.inkMuted),
              const SizedBox(width: SwanSpace.xs),
              Text('Onaylandı', style: SwanType.caption(c.inkMuted)),
            ])
          else if (widget.config.entryMode == ScoreEntryMode.flexible)
            // Yalnızca esnek biçimde seçim sporcuda.
            TextButton(
              onPressed: () => setState(() => _detailed = !_detailed),
              child: Text(_detailed ? 'Toplam gir' : 'Tek tek gir',
                  style: SwanType.caption(c.accent)),
            ),
        ]),
        const SizedBox(height: SwanSpace.md),

        if (locked)
          Text(
            widget.existing?.totalScore == null
                ? 'Eksik sonuç'
                : '${_fmt(widget.existing!.totalScore!)} puan',
            style: SwanType.h2(c.ink),
          )
        else if (_detailed)
          _grid(c)
        else
          _totalField(c),

        if (!locked && _detailed) ...[
          const SizedBox(height: SwanSpace.sm),
          Text(
            'Toplam: ${sumEntries(_entries) == null ? '—' : _fmt(sumEntries(_entries)!)}'
            '   ·   ${countEntries(_entries)}/${widget.config.unitsPerSet} $_unit',
            style: SwanType.caption(c.inkMuted),
          ),
        ],

        if (_error != null) ...[
          const SizedBox(height: SwanSpace.sm),
          Text(_error!, style: SwanType.bodySm(c.danger)),
        ],

        if (!locked) ...[
          const SizedBox(height: SwanSpace.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _save,
              style: FilledButton.styleFrom(backgroundColor: c.accent),
              child: Text(_busy ? 'Kaydediliyor…' : 'Seti kaydet'),
            ),
          ),
          const SizedBox(height: SwanSpace.xs),
          Text(
            'Boş bıraktığın $_unit eksik sayılır, sıfır puan yazılmaz.',
            style: SwanType.caption(c.inkMuted),
          ),
        ],
      ]),
    );
  }

  Widget _totalField(SwanPalette c) => TextField(
        controller: _totalCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: SwanType.h2(c.ink),
        decoration: InputDecoration(
          hintText: '0 – ${_fmt(widget.config.maxSetScore)}',
          hintStyle: SwanType.h2(c.inkMuted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SwanRadius.md),
            borderSide: BorderSide(color: c.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SwanRadius.md),
            borderSide: BorderSide(color: c.line),
          ),
        ),
      );

  /// Her ok için bir kutu. Boş kutu = atılmamış ok.
  Widget _grid(SwanPalette c) => Wrap(
        spacing: SwanSpace.sm,
        runSpacing: SwanSpace.sm,
        children: [
          for (var i = 0; i < _entries.length; i++)
            SizedBox(
              width: 56,
              child: TextFormField(
                initialValue:
                    _entries[i] == null ? '' : _fmt(_entries[i]!),
                textAlign: TextAlign.center,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: SwanType.h3(c.ink),
                onChanged: (v) {
                  final t = v.trim().replaceAll(',', '.');
                  setState(() => _entries[i] = t.isEmpty ? null : num.tryParse(t));
                },
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '—',
                  hintStyle: SwanType.h3(c.inkMuted),
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: SwanSpace.md, horizontal: SwanSpace.xs),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(SwanRadius.sm),
                    borderSide: BorderSide(color: c.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(SwanRadius.sm),
                    borderSide: BorderSide(color: c.line),
                  ),
                ),
              ),
            ),
        ],
      );
}
