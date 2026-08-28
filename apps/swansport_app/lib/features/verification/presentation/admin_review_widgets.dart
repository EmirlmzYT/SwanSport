import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';

/// Onay panelinin durum tutmayan parçaları.
///
/// `admin_review_screen.dart` 1300 satırı aşmıştı. Buraya taşınanların ortak
/// özelliği: hiçbiri ekranın durumuna (`setState`, alanlar) dokunmuyor,
/// gereken her şeyi parametreyle alıyor. Davranış aynı; yalnızca yer değişti.

/// Acik bir sikayet satiri.
Widget adminReportRow(
    BuildContext context, WidgetRef ref, bool isDark, ReportRow r) {
  final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
  final ink = isDark ? Colors.white : SwanColors.textPrimary;
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFF43F5E).withValues(alpha: .06),
      borderRadius: BorderRadius.circular(16),
      border:
          Border.all(color: const Color(0xFFF43F5E).withValues(alpha: .3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF43F5E).withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.flag_rounded,
                size: 19, color: Color(0xFFF43F5E)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.targetLabel + " \u00b7 " + r.reasonLabel,
                    style: jakarta(13, FontWeight.w800, ink)),
                Text("Bildiren: " + (r.reporterName ?? "Kullan\u0131c\u0131"),
                    style: jakarta(
                        11, FontWeight.w500, SwanColors.textSecondary)),
              ],
            ),
          ),
        ]),
        if (r.detail != null && r.detail!.trim().isNotEmpty) ...[
          const SizedBox(height: 9),
          Text(r.detail!,
              style: jakarta(12, FontWeight.w500, SwanColors.textSecondary)),
        ],
        const SizedBox(height: 11),
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () => adminHandleReport(context, ref, r.id,
                  dismiss: true, delete: false),
              child: Container(
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: surf, borderRadius: BorderRadius.circular(12)),
                child: Text("Yok say",
                    style: jakarta(
                        12.5, FontWeight.w800, SwanColors.textSecondary)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => adminHandleReport(context, ref, r.id,
                  dismiss: false, delete: false),
              child: Container(
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: surf, borderRadius: BorderRadius.circular(12)),
                child: Text("\u0130ncelendi",
                    style: jakarta(12.5, FontWeight.w800, ink)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => adminHandleReport(context, ref, r.id,
                  dismiss: false, delete: true),
              child: Container(
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: const Color(0xFFF43F5E),
                    borderRadius: BorderRadius.circular(12)),
                child: Text("\u0130\u00e7eri\u011fi sil",
                    style: jakarta(12.5, FontWeight.w800, Colors.white)),
              ),
            ),
          ),
        ]),
      ],
    ),
  );
}

Future<void> adminHandleReport(BuildContext context, WidgetRef ref, String id,
    {required bool dismiss, required bool delete}) async {
  try {
    await ref
        .read(moderationServiceProvider)
        .reviewReport(id, dismiss: dismiss, deleteContent: delete);
    ref.invalidate(openReportsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(delete
              ? "\u0130\u00e7erik silindi"
              : "\u015eikayet kapat\u0131ld\u0131"),
          backgroundColor: kTeal));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("\u0130\u015flem ba\u015far\u0131s\u0131z: $e"),
          backgroundColor: const Color(0xFFF43F5E)));
    }
  }
}

Widget adminMiniButton(Color color, IconData icon, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(11),),
      child: Icon(icon, color: Colors.white, size: 18),
    ),
  );
}

Widget adminCrest() => Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [kTealBright, kTealDeep]),
        borderRadius: BorderRadius.circular(13),
      ),
      child: const Icon(Icons.account_balance_rounded,
          color: Colors.white, size: 20,),
    );

Widget adminNoneText(bool isDark, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text,
          style: jakarta(12.5, FontWeight.w500, SwanColors.textSecondary),),
    );

String adminDocLabel(String t) => switch (t) {
      'kademe_belgesi' => 'Kademe belgesi',
      'kimlik' => 'Kimlik (TC)',
      'federasyon' => 'Federasyon lisansı',
      'tescil' => 'Kulüp tescil belgesi',
      _ => t,
    };

Future<void> showAdminDocs(BuildContext context, WidgetRef ref, String ownerType,
    String ownerId, String title,) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
  final ink = isDark ? Colors.white : SwanColors.textPrimary;
  final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: surf,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text('Belgeler · $title',
          style: sora(17, FontWeight.w800, ink),),
      content: SizedBox(
        width: 360,
        child: FutureBuilder<List<({String docType, String url})>>(
          future:
              ref.read(verificationServiceProvider).documentsFor(ownerType, ownerId),
          builder: (c, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(color: kTeal)),
              );
            }
            if (snap.hasError) {
              return Text('Yüklenemedi: ${snap.error}',
                  style: jakarta(
                      12, FontWeight.w500, SwanColors.textSecondary,),);
            }
            final docs = snap.data ?? const [];
            if (docs.isEmpty) {
              return Text('Bu başvuruya belge eklenmemiş.',
                  style: jakarta(
                      12.5, FontWeight.w500, SwanColors.textSecondary,),);
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final d in docs)
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: d.url));
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                          content:
                              Text('Bağlantı kopyalandı — tarayıcıda aç'),
                          backgroundColor: kTeal,),);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: line),
                      ),
                      child: Row(children: [
                        const Icon(Icons.description_rounded,
                            size: 18, color: Color(0xFF2563EB),),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(adminDocLabel(d.docType),
                              style: jakarta(13, FontWeight.w700, ink),),
                        ),
                        const Icon(Icons.copy_rounded,
                            size: 15, color: SwanColors.textSecondary,),
                      ],),
                    ),
                  ),
                const SizedBox(height: 2),
                Text('Bağlantıyı kopyalayıp tarayıcıda aç (1 saat geçerli).',
                    style: jakarta(
                        10.5, FontWeight.w500, SwanColors.textSecondary,),),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Kapat',
              style: jakarta(13, FontWeight.w800, kTeal),),
        ),
      ],
    ),
  );
}
