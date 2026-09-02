import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/theme/console_theme.dart';
import '../finance/work_queue.dart';

/// Yardım içeriği — SSS düzenleyici ve kapsam raporu.
///
/// **Kapsam raporu üstte ve bilerek.** Bir özelliği `testers` ya da
/// `everyone` yapmak, o özelliğin yardımı yazılmadan veritabanı
/// tetikleyicisiyle reddediliyor (0070). Eksikleri kademeyi ilerletmeye
/// çalışıp hata almadan önce görmek gerekiyor.
class ConsoleFaqScreen extends ConsumerStatefulWidget {
  const ConsoleFaqScreen({super.key});

  @override
  ConsumerState<ConsoleFaqScreen> createState() => _ConsoleFaqScreenState();
}

class _ConsoleFaqScreenState extends ConsumerState<ConsoleFaqScreen> {
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final coverage = ref.watch(faqCoverageProvider);
    final entries = ref.watch(faqAdminProvider);

    return ListView(
      padding: const EdgeInsets.all(ConsoleDensity.xl),
      children: [
        ConsolePageHeader(
          title: 'Yardım İçeriği',
          subtitle: 'Uygulamadaki SSS. Bir özelliği kullanıcılara açmak, '
              'yardımı yazılmadan mümkün değil — kural veritabanında.',
          trailing: FilledButton.icon(
            onPressed: () => _edit(context, ref, null),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Soru ekle'),
          ),
        ),
        const SizedBox(height: ConsoleDensity.xl),

        Text('Kapsam', style: t.textTheme.titleMedium),
        const SizedBox(height: ConsoleDensity.xs),
        Text(
          'Yardımı olmayan özellik yayınlanamıyor. Yeni bir özellik '
          'eklediğinde buraya bir soru yazman gerekiyor.',
          style: t.textTheme.bodySmall,
        ),
        const SizedBox(height: ConsoleDensity.md),
        AsyncSection<List<FaqCoverage>>(
          value: coverage,
          errorPrefix: 'Kapsam alınamadı',
          builder: (list) {
            final missing = list.where((c) => c.entryCount == 0).toList();
            if (missing.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(ConsoleDensity.lg),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(ConsoleDensity.radius),
                  border: Border.all(color: t.colorScheme.outlineVariant),
                ),
                child: Row(children: [
                  Icon(Icons.check_circle_outline_rounded,
                      size: 18, color: t.colorScheme.primary),
                  const SizedBox(width: ConsoleDensity.sm),
                  Text('${list.length} özelliğin hepsinin yardımı yazılı.',
                      style: t.textTheme.bodyMedium),
                ]),
              );
            }
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(ConsoleDensity.lg),
              decoration: BoxDecoration(
                color: t.colorScheme.error.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(ConsoleDensity.radius),
                border: Border.all(
                    color: t.colorScheme.error.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${missing.length} özelliğin yardımı eksik',
                      style: t.textTheme.titleSmall
                          ?.copyWith(color: t.colorScheme.error)),
                  const SizedBox(height: ConsoleDensity.xs),
                  Text(
                    'Bunlar kullanıcılara açılamaz. Her biri için en az bir '
                    'soru ekle.',
                    style: t.textTheme.bodySmall,
                  ),
                  const SizedBox(height: ConsoleDensity.sm),
                  Wrap(
                    spacing: ConsoleDensity.sm,
                    runSpacing: ConsoleDensity.sm,
                    children: [
                      for (final c in missing)
                        ActionChip(
                          label: Text(c.label),
                          avatar: const Icon(Icons.add_rounded, size: 15),
                          onPressed: () => _edit(context, ref, null,
                              feature: c.feature),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: ConsoleDensity.xxl),
        Text('Sorular', style: t.textTheme.titleMedium),
        const SizedBox(height: ConsoleDensity.md),
        AsyncSection<List<FaqEntry>>(
          value: entries,
          errorPrefix: 'Sorular alınamadı',
          builder: (list) => list.isEmpty
              ? Text('Henüz soru yok.', style: t.textTheme.bodySmall)
              : Column(
                  children: [
                    for (final f in list)
                      _row(context, ref, f),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, FaqEntry f) {
    final t = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: ConsoleDensity.sm),
      padding: const EdgeInsets.all(ConsoleDensity.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ConsoleDensity.radius),
        border: Border.all(color: t.colorScheme.outlineVariant),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(f.question, style: t.textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(f.answer,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.textTheme.bodySmall),
              const SizedBox(height: ConsoleDensity.xs),
              Text(
                [
                  f.category,
                  if (f.feature != null) 'özellik: ${f.feature}',
                  if (f.route != null) f.route!,
                ].join(' · '),
                style: t.textTheme.labelSmall,
              ),
            ],
          ),
        ),
        IconButton(
          iconSize: 18,
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => _edit(context, ref, f),
        ),
      ]),
    );
  }
}

/// Soru ekleme/düzenleme.
Future<void> _edit(
  BuildContext context,
  WidgetRef ref,
  FaqEntry? existing, {
  String? feature,
}) async {
  final question = TextEditingController(text: existing?.question ?? '');
  final answer = TextEditingController(text: existing?.answer ?? '');
  final category =
      TextEditingController(text: existing?.category ?? 'Genel');
  final route = TextEditingController(text: existing?.route ?? '');
  var audience = 'everyone';
  var feat = feature ?? existing?.feature;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(existing == null ? 'Soru ekle' : 'Soruyu düzenle'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: question,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Soru',
                  hintText: 'Aidatımı ödedim ama borcum duruyor.',
                ),
              ),
              const SizedBox(height: ConsoleDensity.md),
              TextField(
                controller: answer,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Cevap',
                  hintText: 'Kısa tut. SSS\'nin işi kullanıcıyı doğru '
                      'ekrana götürmek, kılavuz yazmak değil.',
                ),
              ),
              const SizedBox(height: ConsoleDensity.md),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: category,
                    decoration:
                        const InputDecoration(labelText: 'Kategori'),
                  ),
                ),
                const SizedBox(width: ConsoleDensity.md),
                Expanded(
                  child: TextField(
                    controller: route,
                    decoration: const InputDecoration(
                        labelText: 'İlgili ekran (rota)',
                        hintText: '/aidatlarim'),
                  ),
                ),
              ]),
              const SizedBox(height: ConsoleDensity.md),
              DropdownButtonFormField<String>(
                initialValue: audience,
                decoration: const InputDecoration(labelText: 'Kimler görsün'),
                items: const [
                  DropdownMenuItem(value: 'everyone', child: Text('Herkes')),
                  DropdownMenuItem(value: 'athlete', child: Text('Sporcu')),
                  DropdownMenuItem(value: 'parent', child: Text('Veli')),
                  DropdownMenuItem(value: 'coach', child: Text('Antrenör')),
                  DropdownMenuItem(
                      value: 'club_staff', child: Text('Kulüp yetkilisi')),
                  DropdownMenuItem(
                      value: 'accountant', child: Text('Muhasebeci')),
                ],
                onChanged: (v) => setState(() => audience = v ?? 'everyone'),
              ),
              const SizedBox(height: ConsoleDensity.md),
              // Özellik bağı: doluysa soru yalnızca o özellik açıkken
              // görünüyor ve o özelliğin yayınlanmasını mümkün kılıyor.
              DropdownButtonFormField<String?>(
                initialValue: feat,
                decoration: const InputDecoration(
                  labelText: 'Hangi özellik (isteğe bağlı)',
                  helperText: 'Boş bırakılırsa genel soru. Dolu ise o '
                      'özellik açıkken görünür ve yayınlanmasını sağlar.',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('— genel —')),
                  for (final k in _knownFeatures)
                    DropdownMenuItem<String?>(value: k, child: Text(k)),
                ],
                onChanged: (v) => setState(() => feat = v),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Kaydet')),
        ],
      ),
    ),
  );

  if (ok != true) return;
  if (question.text.trim().isEmpty || answer.text.trim().isEmpty) return;

  final row = {
    'question': question.text.trim(),
    'answer': answer.text.trim(),
    'category': category.text.trim().isEmpty ? 'Genel' : category.text.trim(),
    'audience': audience,
    'route': route.text.trim().isEmpty ? null : route.text.trim(),
    'feature': feat,
    'updated_at': DateTime.now().toIso8601String(),
  };

  try {
    final c = Supabase.instance.client;
    if (existing == null) {
      await c.from('faq_entries').insert(row);
    } else {
      await c.from('faq_entries').update(row).eq('id', existing.id);
    }
    ref.invalidate(faqAdminProvider);
    ref.invalidate(faqCoverageProvider);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

/// Bilinen bayrak anahtarları — `FeatureFlags` sabitleriyle aynı kaynak.
const _knownFeatures = [
  FeatureFlags.marketplace,
  FeatureFlags.courts,
  FeatureFlags.partnerSearch,
  FeatureFlags.turfFields,
  FeatureFlags.teamHub,
  FeatureFlags.coachDiscovery,
  FeatureFlags.financeOperationsCenter,
  FeatureFlags.recurringExpenses,
  FeatureFlags.bankReconciliation,
  FeatureFlags.clubBudgeting,
  FeatureFlags.periodClosing,
  FeatureFlags.clubOperationsCenter,
  FeatureFlags.socialSavedPosts,
  FeatureFlags.socialMultiPhoto,
  FeatureFlags.socialContentShare,
  FeatureFlags.socialReposts,
  FeatureFlags.socialMentions,
  FeatureFlags.socialSportsCards,
  FeatureFlags.socialExternalShare,
  FeatureFlags.socialVideo,
  FeatureFlags.eligibilityGate,
  FeatureFlags.membershipLifecycle,
  FeatureFlags.parentHub,
  FeatureFlags.coachWorkspace,
  FeatureFlags.offlineAttendance,
  FeatureFlags.facilityConflicts,
  FeatureFlags.notificationPreferences,
  FeatureFlags.supportCenter,
  FeatureFlags.operationsAnalytics,
  FeatureFlags.clubOperationalRisk,
  FeatureFlags.tournamentHub,
  FeatureFlags.clubOnboarding,
  FeatureFlags.clubCsvImport,
  FeatureFlags.identityCustomization,
];
