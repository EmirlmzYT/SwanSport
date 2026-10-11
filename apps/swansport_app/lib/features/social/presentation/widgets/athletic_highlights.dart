import 'package:flutter/material.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';

enum AthleticHighlightKind { training, score, record }

/// Presentation-only interpretation of explicit author statements, not a
/// verified result. Original body is retained so context cannot be lost.
class AthleticHighlight {
  const AthleticHighlight(this.kind, this.label);
  final AthleticHighlightKind kind;
  final String label;
}

List<AthleticHighlight> athleticHighlights(String body) {
  final result = <AthleticHighlight>[];
  final units = RegExp(r'\d+(?:[.,]\d+)?\s*(?:km|dk|ok|puan)(?![a-zA-ZçğıöşüÇĞİÖŞÜ])', caseSensitive: false);
  final score = RegExp(r'(?<![\d./:\-])\d{1,2}\s*[-–]\s*\d{1,2}(?![\d./:\-])');
  for (final raw in body.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty || line.length > 160) continue;
    // A question, negation, plan or quotation must not become a result badge.
    if (RegExp(r'[?"“”]|hedef|plan|değil|degil|olmad|yok|rekor kırmak', caseSensitive: false).hasMatch(line)) continue;
    final stats = units.allMatches(line).map((m) => m.group(0)!).toList();
    if (stats.length >= 2 && RegExp(r'antrenman|seans|koşu|kosu|^\d', caseSensitive: false).hasMatch(line)) {
      result.add(AthleticHighlight(AthleticHighlightKind.training, stats.take(4).join(' · ')));
    }
    if (score.hasMatch(line) && RegExp(r'maç|mac|skor|galibiyet|beraberlik|mağlubiyet|maglubiyet', caseSensitive: false).hasMatch(line)) {
      result.add(AthleticHighlight(AthleticHighlightKind.score, line));
    }
    if (RegExp(r'yeni kişisel rekor|yeni kisisel rekor|^PR\s*:', caseSensitive: false).hasMatch(line)) {
      result.add(AthleticHighlight(AthleticHighlightKind.record, line));
    }
  }
  final seen = <AthleticHighlightKind>{};
  return result.where((h) => seen.add(h.kind)).take(3).toList();
}

class AthleticHighlights extends StatelessWidget {
  const AthleticHighlights({super.key, required this.body});
  final String body;
  @override
  Widget build(BuildContext context) {
    final highlights = athleticHighlights(body);
    if (highlights.isEmpty) return const SizedBox.shrink();
    final c = context.swan;
    return Padding(
      padding: const EdgeInsets.fromLTRB(SwanSpace.lg, 0, SwanSpace.lg, SwanSpace.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: SwanSpace.sm, runSpacing: SwanSpace.sm, children: [
          for (final h in highlights)
            Container(
              padding: const EdgeInsets.all(SwanSpace.md),
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: BorderRadius.circular(SwanRadius.md),
                gradient: h.kind == AthleticHighlightKind.record
                    ? LinearGradient(colors: [c.warning.withValues(alpha: .12), c.accentSoft]) : null,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(switch (h.kind) {
                  AthleticHighlightKind.training => Icons.fitness_center_rounded,
                  AthleticHighlightKind.score => Icons.sports_score_rounded,
                  AthleticHighlightKind.record => Icons.emoji_events_outlined,
                }, color: h.kind == AthleticHighlightKind.record ? c.warning : c.accent, size: SwanSpace.xl),
                const SizedBox(width: SwanSpace.sm),
                Flexible(child: Text(h.label, style: SwanType.bodySm(c.ink, w: FontWeight.w800))),
              ]),
            ),
        ]),
        const SizedBox(height: SwanSpace.xs),
        Text('Paylaşım özeti · Kullanıcı beyanı', style: SwanType.caption(c.inkMuted)),
      ]),
    );
  }
}
