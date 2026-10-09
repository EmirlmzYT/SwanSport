import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../design/swan_palette.dart';
import '../design/swan_type.dart';

class DiagnosticPreferencesTile extends ConsumerWidget {
  const DiagnosticPreferencesTile({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(diagnosticPreferencesProvider);
    final c = context.swan;
    Future<void> update({bool? errors, bool? usage}) async {
      try {
        await ref
            .read(diagnosticPreferencesProvider.notifier)
            .update(errors: errors, usage: usage);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tercih bu cihazda kalıcı kaydedilemedi.'),
            ),
          );
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Uygulamayı iyileştirmeye yardım et', style: SwanType.h3(c.ink)),
        Text(
          'İsteğe bağlı teknik kayıtları yalnızca yetkili SwanSport ekibi görür. '
          'Mesaj, form içeriği, belge ve para tutarları toplanmaz. '
          'Teknik kayıtlar 30 günlük saklama süresiyle günlük temizlenir; kapatınca bekleyen kayıtlar silinir.',
          style: SwanType.bodySm(c.inkMuted),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Hata tanılaması'),
          subtitle: const Text(
            'Hata kodu, sürüm, kaynak konumu ve hatadan önceki son teknik işlemler.',
          ),
          value: preferences.errors,
          onChanged: (v) => update(errors: v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Kullanım ve performans ölçümü'),
          subtitle: const Text('Açılan ekranlar, işlem sonuçları ve süreleri.'),
          value: preferences.usage,
          onChanged: (v) => update(usage: v),
        ),
      ],
    );
  }
}
