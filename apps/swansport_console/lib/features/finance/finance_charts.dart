import 'package:flutter/material.dart';

import '../../app/theme/console_theme.dart';
import 'money.dart';

/// Mali grafiklerin paleti.
///
/// Renkler `dataviz` doğrulayıcısıyla sınandı; koyu tema açık temanın
/// çevrilmiş hali **değil**, kendi yüzeyine göre ayrı basamaklar:
///
/// * açık (#FFFFFF üstünde): #009BA6 / #C2410C — lightness, chroma, CVD ve
///   kontrast kontrollerinin hepsi geçti
/// * koyu (#171A1F üstünde): #0EA5A0 / #D97706 — aynı kontroller, koyu bandı
///
/// Tek bir çifti iki temada birden kullanmak denendi; açık temada kontrast
/// 2.96 ile 3:1 eşiğinin altında kaldığı için ayrıldılar.
///
/// Renk tek başına taşıyıcı değil: gelir her zaman soldaki çubuk, gider
/// sağdaki; ayrıca gösterge ve tablo görünümü var.
class ChartPalette {
  const ChartPalette({required this.income, required this.outgo});

  factory ChartPalette.of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const ChartPalette(
              income: Color(0xFF0EA5A0), outgo: Color(0xFFD97706))
          : const ChartPalette(
              income: Color(0xFF009BA6), outgo: Color(0xFFC2410C));

  final Color income;
  final Color outgo;
}

/// Aylık gelir–gider karşılaştırması.
///
/// Gruplanmış çubuk seçildi: iki ölçü aynı birimde (₺) ve soru "hangi ay
/// hangisi daha büyük". Çift eksen kullanılmadı — aynı birimdeki iki seri tek
/// eksende karşılaştırılır.
class MonthlyBarChart extends StatefulWidget {
  const MonthlyBarChart({
    required this.months,
    required this.incomes,
    required this.outgos,
    super.key,
  });

  /// 1..12
  final List<int> months;
  final List<num> incomes;
  final List<num> outgos;

  @override
  State<MonthlyBarChart> createState() => _MonthlyBarChartState();
}

class _MonthlyBarChartState extends State<MonthlyBarChart> {
  int? _hoverIndex;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final palette = ChartPalette.of(context);

    final maxValue = [
      ...widget.incomes,
      ...widget.outgos,
    ].fold<num>(0, (a, b) => b > a ? b : a);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Legend(palette: palette),
        const SizedBox(height: ConsoleDensity.md),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              return MouseRegion(
                onHover: (e) {
                  final i = _indexAt(e.localPosition.dx, box.maxWidth);
                  if (i != _hoverIndex) setState(() => _hoverIndex = i);
                },
                onExit: (_) => setState(() => _hoverIndex = null),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _MonthlyPainter(
                          months: widget.months,
                          incomes: widget.incomes,
                          outgos: widget.outgos,
                          maxValue: maxValue,
                          palette: palette,
                          grid: t.colorScheme.outline,
                          ink: t.textTheme.bodySmall?.color ?? Colors.grey,
                          hoverIndex: _hoverIndex,
                          surface: t.colorScheme.surface,
                        ),
                      ),
                    ),
                    if (_hoverIndex != null)
                      _Tooltip(
                        index: _hoverIndex!,
                        month: widget.months[_hoverIndex!],
                        income: widget.incomes[_hoverIndex!],
                        outgo: widget.outgos[_hoverIndex!],
                        width: box.maxWidth,
                        palette: palette,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  int? _indexAt(double dx, double width) {
    if (widget.months.isEmpty) return null;
    const leftPad = 64.0;
    final plot = width - leftPad - 8;
    if (dx < leftPad || plot <= 0) return null;
    final slot = plot / widget.months.length;
    final i = ((dx - leftPad) / slot).floor();
    return (i >= 0 && i < widget.months.length) ? i : null;
  }
}

class _MonthlyPainter extends CustomPainter {
  _MonthlyPainter({
    required this.months,
    required this.incomes,
    required this.outgos,
    required this.maxValue,
    required this.palette,
    required this.grid,
    required this.ink,
    required this.hoverIndex,
    required this.surface,
  });

  final List<int> months;
  final List<num> incomes;
  final List<num> outgos;
  final num maxValue;
  final ChartPalette palette;
  final Color grid;
  final Color ink;
  final int? hoverIndex;
  final Color surface;

  static const double _leftPad = 64;
  static const double _bottomPad = 24;
  static const double _radius = 4;

  @override
  void paint(Canvas canvas, Size size) {
    if (months.isEmpty) return;

    final plotW = size.width - _leftPad - 8;
    final plotH = size.height - _bottomPad;
    if (plotW <= 0 || plotH <= 0) return;

    final scale = maxValue == 0 ? 0.0 : plotH / maxValue.toDouble();

    // --- ızgara: geri planda, sessiz ---
    final gridPaint = Paint()
      ..color = grid.withValues(alpha: .6)
      ..strokeWidth = 1;
    final labelStyle = TextStyle(color: ink, fontSize: 10);

    for (var s = 0; s <= 4; s++) {
      final y = plotH - (plotH * s / 4);
      canvas.drawLine(Offset(_leftPad, y), Offset(size.width - 8, y), gridPaint);

      final value = maxValue * s / 4;
      _text(canvas, _short(value), Offset(_leftPad - 8, y),
          labelStyle, align: TextAlign.right, anchorRight: true);
    }

    // --- çubuklar ---
    final slot = plotW / months.length;
    // İki çubuk arasında 2px yüzey boşluğu; grupla grup arası daha geniş.
    const gap = 2.0;
    final barW = ((slot - 14) / 2).clamp(3.0, 26.0);

    for (var i = 0; i < months.length; i++) {
      final x0 = _leftPad + slot * i + (slot - (barW * 2 + gap)) / 2;
      final dim = hoverIndex != null && hoverIndex != i;

      _bar(canvas, x0, plotH, incomes[i] * scale, barW,
          palette.income, dim);
      _bar(canvas, x0 + barW + gap, plotH, outgos[i] * scale, barW,
          palette.outgo, dim);

      _text(canvas, kMonthNames[months[i] - 1],
          Offset(_leftPad + slot * i + slot / 2, plotH + 6),
          labelStyle.copyWith(
              fontWeight: hoverIndex == i ? FontWeight.w700 : FontWeight.w400),
          align: TextAlign.center, center: true);
    }
  }

  /// Tabana oturan, üstü 4px yuvarlatılmış ince çubuk.
  void _bar(Canvas canvas, double x, double baseY, double h, double w,
      Color color, bool dim) {
    if (h <= 0) return;
    final paint = Paint()..color = dim ? color.withValues(alpha: .35) : color;
    final top = baseY - h;
    final r = h < _radius ? h : _radius;
    canvas.drawRRect(
      RRect.fromLTRBAndCorners(x, top, x + w, baseY,
          topLeft: Radius.circular(r), topRight: Radius.circular(r)),
      paint,
    );
  }

  void _text(Canvas canvas, String s, Offset at, TextStyle style,
      {TextAlign align = TextAlign.left,
      bool center = false,
      bool anchorRight = false}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: style),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = at.dx;
    if (center) dx -= tp.width / 2;
    if (anchorRight) dx -= tp.width;
    canvas.paint(tp, Offset(dx, at.dy - (anchorRight ? tp.height / 2 : 0)));
  }

  static String _short(num v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}B';
    return v.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(_MonthlyPainter old) =>
      old.hoverIndex != hoverIndex ||
      old.incomes != incomes ||
      old.outgos != outgos ||
      old.maxValue != maxValue;
}

extension on Canvas {
  void paint(TextPainter tp, Offset o) => tp.paint(this, o);
}

class _Legend extends StatelessWidget {
  const _Legend({required this.palette});

  final ChartPalette palette;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    Widget item(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  color: c, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: ConsoleDensity.sm),
            // Etiket metin rengini taşır, seri rengini değil — kimlik yandaki
            // renkli işaretten okunuyor.
            Text(label, style: t.textTheme.bodySmall),
          ],
        );

    return Row(
      children: [
        item(palette.income, 'Gelir'),
        const SizedBox(width: ConsoleDensity.lg),
        item(palette.outgo, 'Gider'),
      ],
    );
  }
}

class _Tooltip extends StatelessWidget {
  const _Tooltip({
    required this.index,
    required this.month,
    required this.income,
    required this.outgo,
    required this.width,
    required this.palette,
  });

  final int index;
  final int month;
  final num income;
  final num outgo;
  final double width;
  final ChartPalette palette;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    const leftPad = 64.0;
    final slot = (width - leftPad - 8) / 12;
    var left = leftPad + slot * index + slot / 2 - 90;
    left = left.clamp(4.0, width - 184);

    return Positioned(
      left: left,
      top: 4,
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(ConsoleDensity.md),
        decoration: BoxDecoration(
          color: t.colorScheme.surface,
          borderRadius: BorderRadius.circular(ConsoleDensity.radius),
          border: Border.all(color: t.colorScheme.outline),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(kMonthNames[month - 1], style: t.textTheme.labelSmall),
            const SizedBox(height: ConsoleDensity.sm),
            _row(t, palette.income, 'Gelir', income),
            const SizedBox(height: 2),
            _row(t, palette.outgo, 'Gider', outgo),
            Divider(height: ConsoleDensity.md, color: t.colorScheme.outline),
            Row(
              children: [
                Text('Net', style: t.textTheme.bodySmall),
                const Spacer(),
                Text(fmtMoney(income - outgo),
                    style: t.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(ThemeData t, Color c, String label, num value) => Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: ConsoleDensity.sm),
          Text(label, style: t.textTheme.bodySmall),
          const Spacer(),
          Text(fmtMoney(value), style: t.textTheme.bodySmall),
        ],
      );
}

/// Kategori dağılımı — sıralı yatay çubuklar.
///
/// Pasta grafik kullanılmadı: sekiz dilimin açılarını gözle karşılaştırmak
/// zordur, sıralı çubukta aynı bilgi tek bakışta okunur. Tek seri olduğu için
/// tek renk yeter; kimlik satır etiketinden geliyor, renkten değil.
class CategoryBars extends StatelessWidget {
  const CategoryBars({
    required this.labels,
    required this.values,
    super.key,
  });

  final List<String> labels;
  final List<num> values;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final color = ChartPalette.of(context).outgo;
    final max = values.fold<num>(0, (a, b) => b > a ? b : a);
    final total = values.fold<num>(0, (a, b) => a + b);

    return ListView.separated(
      itemCount: labels.length,
      separatorBuilder: (_, __) => const SizedBox(height: ConsoleDensity.md),
      itemBuilder: (_, i) {
        final ratio = max == 0 ? 0.0 : values[i] / max;
        final share = total == 0 ? 0.0 : values[i] / total * 100;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(labels[i],
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.bodyMedium),
                ),
                Text('%${share.toStringAsFixed(0)}',
                    style: t.textTheme.bodySmall),
                const SizedBox(width: ConsoleDensity.md),
                Text(
                  fmtMoney(values[i]),
                  style: t.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: ConsoleDensity.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: ratio.toDouble(),
                minHeight: 6,
                backgroundColor: t.colorScheme.outline.withValues(alpha: .35),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        );
      },
    );
  }
}
