import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';
import '../../../app/widgets/swan_tabs.dart';
import '../../../app/design/swan_type.dart';

/// Doğrulama — antrenör/sporcu kimlik başvurusu + durum (premium v3).
class CredentialScreen extends ConsumerStatefulWidget {
  const CredentialScreen({super.key});

  @override
  ConsumerState<CredentialScreen> createState() => _CredentialScreenState();
}

class _CredentialScreenState extends ConsumerState<CredentialScreen> {
  int _mode = 0; // 0 antrenör, 1 sporcu
  int _kademe = 2;
  String? _sportCode;   // antrenörlük belgesinin branşı
  bool _busy = false;

  /// Seçilip Storage'a yüklenmiş belgeler: docType -> (dosya adı, storage yolu).
  final Map<String, ({String fileName, String storagePath})> _docs = {};

  /// Şu an yüklenmekte olan docType'lar.
  final Set<String> _uploading = {};

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final alt = isDark ? const Color(0xFF1A2537) : const Color(0xFFF1F5F8);
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final async = ref.watch(myCredentialsProvider);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Row(children: [
                  _back(context, surf, isDark, ink),
                  const SizedBox(width: 14),
                  Text('Doğrulama', style: SwanType.h2(ink)),
                ],),
                const SizedBox(height: 16),

                // Mod: Antrenör / Sporcu
                SwanSegmentedTabs(
                  labels: const ['Antrenör', 'Sporcu'],
                  selected: _mode,
                  onSelect: (i) => setState(() => _mode = i),
                ),
                const SizedBox(height: 18),

                if (_mode == 0) ...[
                  Text('Kademe', style: SwanType.h3(ink),),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        color: alt, borderRadius: BorderRadius.circular(13),),
                    child: Row(
                        children: List.generate(5, (i) => _kademeItem(i + 1)),),
                  ),
                  const SizedBox(height: 6),
                  Text(_kademeLabel(_kademe),
                      style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600),),

                  const SizedBox(height: 18),
                  Text('Branş', style: SwanType.h3(ink),),
                  const SizedBox(height: 8),
                  _sportPicker(isDark, alt, ink),
                  const SizedBox(height: 6),
                  Text(
                      'Belgen hangi branşa aitse onu seç. Platform bu branşta '
                      'onaylar ve ilgili federasyonun duyuru kanalına '
                      'eklenirsin.',
                      style: SwanType.caption(SwanColors.textSecondary),),
                ] else ...[
                  Text('Branş', style: SwanType.h3(ink),),
                  const SizedBox(height: 8),
                  _sportPicker(isDark, alt, ink),
                  const SizedBox(height: 6),
                  Text(
                      'Lisansın hangi branşa aitse onu seç. Ferdi sporcu da bir '
                      'branşta yarışır; ferdi olmak kulübü olmamak demektir.',
                      style: SwanType.caption(SwanColors.textSecondary),),

                  const SizedBox(height: 18),
                  Text('Sporcu Doğrulaması', style: SwanType.h3(ink),),
                  const SizedBox(height: 8),
                  // Lisanslı/ferdi ayrımı seçilmez: bir kulübe bağlıysan
                  // lisanslı, değilsen ferdi sporcu sayılırsın.
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: kTeal.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kTeal.withValues(alpha: .3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 18, color: kTeal),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                            'Bir kulübe bağlıysan lisanslı sporcu, değilsen '
                            'ferdi sporcu olarak görünürsün. Kulübe katılınca '
                            'otomatik güncellenir.',
                            style: SwanType.caption(SwanColors.textSecondary),),
                      ),
                    ],),
                  ),
                ],

                const SizedBox(height: 18),
                Text('Belgeler', style: SwanType.h3(ink),),
                const SizedBox(height: 8),
                if (_mode == 0) ...[
                  _uploadTile(isDark, 'kademe_belgesi', 'Kademe belgesi'),
                  _uploadTile(isDark, 'kimlik', 'Kimlik (TC)'),
                ] else
                  _uploadTile(isDark, 'federasyon', 'Federasyon lisansı'),
                const SizedBox(height: 2),
                Text(
                    'ⓘ PDF veya fotoğraf (JPG/PNG) yükleyebilirsin. '
                    'Belgeler yalnızca sana ve platform yöneticisine görünür.',
                    style:
                        SwanType.caption(SwanColors.textSecondary),),
                const SizedBox(height: 16),

                GestureDetector(
                  onTap: _busy ? null : _submit,
                  child: Container(
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient:
                          const LinearGradient(colors: [kTealBright, kTeal]),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                            color: kTeal.withValues(alpha: .34),
                            blurRadius: 18,
                            offset: const Offset(0, 8),),
                      ],
                    ),
                    child: Text(_busy ? 'Gönderiliyor…' : 'Doğrulamaya Gönder',
                        style: SwanType.bodySm(Colors.white, w: FontWeight.w800),),
                  ),
                ),

                // Mevcut başvurular
                const SizedBox(height: 24),
                Text('Başvurularım', style: SwanType.h3(ink),),
                const SizedBox(height: 10),
                async.when(
                  loading: () => const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Center(
                          child: CircularProgressIndicator(color: kTeal),),),
                  error: (e, _) => Text('Yüklenemedi: $e',
                      style: SwanType.caption(SwanColors.textSecondary),),
                  data: (creds) {
                    if (creds.isEmpty) {
                      return Text('Henüz başvuru yok.',
                          style: SwanType.caption(SwanColors.textSecondary),);
                    }
                    return Column(
                        children:
                            creds.map((c) => _credRow(isDark, c)).toList(),);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  /// Branş seçici — liste veritabanından gelir (federasyon kanallarıyla aynı
  /// kaynak, böylece seçilen branş her zaman bir kanala karşılık gelir).
  Widget _sportPicker(bool isDark, Color alt, Color ink) {
    final sports = ref.watch(sportsProvider).valueOrNull ?? const <CityRow>[];
    final selected = sports.where((c) => c.code == _sportCode).firstOrNull;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

    return GestureDetector(
      onTap: sports.isEmpty ? null : () => _pickSport(sports),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: alt,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: line),
        ),
        child: Row(children: [
          Expanded(
            child: Text(
              selected?.name ?? 'Branş seç',
              style: SwanType.bodySm(selected == null ? SwanColors.textSecondary : ink, w: FontWeight.w600),
            ),
          ),
          const Icon(Icons.expand_more_rounded,
              size: 20, color: SwanColors.textSecondary,),
        ],),
      ),
    );
  }

  Future<void> _pickSport(List<CityRow> sports) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final search = TextEditingController();

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        final q = search.text.trim().toLowerCase();
        final list = q.isEmpty
            ? sports
            : sports.where((c) => c.name.toLowerCase().contains(q)).toList();
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.75,
          decoration: BoxDecoration(
            color: surf,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom,),
          child: Column(children: [
            Text('Branş seç', style: SwanType.h3(ink)),
            const SizedBox(height: 12),
            TextField(
              controller: search,
              autofocus: true,
              onChanged: (_) => setSheet(() {}),
              style: SwanType.bodySm(ink),
              decoration: InputDecoration(
                hintText: 'Ara…',
                hintStyle:
                    SwanType.bodySm(SwanColors.textSecondary),
                prefixIcon: const Icon(Icons.search_rounded, size: 19),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) => ListTile(
                  title: Text(list[i].name,
                      style: SwanType.bodySm(ink, w: FontWeight.w600),),
                  trailing: list[i].code == _sportCode
                      ? const Icon(Icons.check_rounded, color: kTeal, size: 19)
                      : null,
                  onTap: () => Navigator.pop(ctx, list[i].code),
                ),
              ),
            ),
          ],),
        );
      },),
    );

    if (picked != null && mounted) setState(() => _sportCode = picked);
  }

  Future<void> _submit() async {
    // Branşsız başvuru kabul edilmez — antrenörde de sporcuda da. Federasyon
    // kanalı, rozet etiketi ve keşif filtreleri bu alana dayanıyor.
    if (_sportCode == null || _sportCode!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Önce branşını seç'),
          backgroundColor: Color(0xFFF43F5E),),);
      return;
    }
    setState(() => _busy = true);
    try {
      final s = ref.read(verificationServiceProvider);
      final credId = _mode == 0
          ? await s.submitCoachCredential(_kademe, sportCode: _sportCode)
          : await s.submitAthleteCredential(sportCode: _sportCode);

      // Yüklenen belgeleri bu başvuruya bağla.
      if (_docs.isNotEmpty) {
        await s.attachDocuments(
          ownerType: 'credential',
          ownerId: credId,
          docs: [
            for (final e in _docs.entries)
              (docType: e.key, storagePath: e.value.storagePath),
          ],
        );
      }

      ref.invalidate(myCredentialsProvider);
      if (mounted) {
        setState(_docs.clear);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Başvurun alındı — platform inceleyecek'),
            backgroundColor: kTeal,),);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: const Color(0xFFF43F5E),),);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _credRow(bool isDark, CredentialRow c) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final (color, icon) = switch (c.status) {
      'approved' => (const Color(0xFF10B981), Icons.check_circle_rounded),
      'rejected' => (const Color(0xFFF43F5E), Icons.cancel_rounded),
      _ => (const Color(0xFFD9860B), Icons.schedule_rounded),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line),
      ),
      child: Row(children: [
        Expanded(
            child: Text(c.label, style: SwanType.bodySm(ink, w: FontWeight.w700)),),
        PremiumStatusChip(label: c.statusLabel, color: color, icon: icon),
      ],),
    );
  }


  Widget _kademeItem(int n) {
    final on = _kademe == n;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _kademe = n),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 9),
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: on ? kTeal : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$n',
              style: SwanType.bodySm(on ? Colors.white : SwanColors.textSecondary, w: FontWeight.w800),),
        ),
      ),
    );
  }

  Widget _uploadTile(bool isDark, String docType, String label) {
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final alt = isDark ? const Color(0xFF1A2537) : const Color(0xFFF1F5F8);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final picked = _docs[docType];
    final uploading = _uploading.contains(docType);
    final done = picked != null;

    final Color borderColor = done ? const Color(0xFF10B981) : line;

    return GestureDetector(
      onTap: (uploading || _busy) ? null : () => _pickAndUpload(docType),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: done ? const Color(0xFF10B981).withValues(alpha: .06) : null,
          border: Border.all(color: borderColor, width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: done ? const Color(0xFF10B981).withValues(alpha: .12) : alt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: uploading
                ? const Padding(
                    padding: EdgeInsets.all(11),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: kTeal,),)
                : Icon(
                    done
                        ? Icons.check_circle_rounded
                        : Icons.upload_file_rounded,
                    size: 20,
                    color: done
                        ? const Color(0xFF10B981)
                        : SwanColors.textSecondary,),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: SwanType.bodySm(ink, w: FontWeight.w700)),
                if (done)
                  Text(picked.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SwanType.caption(SwanColors.textSecondary),),
              ],
            ),
          ),
          if (done)
            GestureDetector(
              onTap: () => setState(() => _docs.remove(docType)),
              child: const Icon(Icons.close_rounded,
                  size: 18, color: SwanColors.textSecondary,),
            )
          else if (!uploading)
            Text('Yükle',
                style: SwanType.caption(kTeal, w: FontWeight.w800),),
        ],),
      ),
    );
  }

  Future<void> _pickAndUpload(String docType) async {
    try {
      final f = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (f == null) return;
      final bytes = await f.readAsBytes();
      if (!mounted) return;
      setState(() => _uploading.add(docType));
      final path = await ref.read(verificationServiceProvider).uploadDocument(
            docType: docType,
            bytes: bytes,
            fileName: f.name,
          );
      if (mounted) {
        setState(() {
          _docs[docType] = (fileName: f.name, storagePath: path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Yükleme hatası: $e'),
            backgroundColor: const Color(0xFFF43F5E),),);
      }
    } finally {
      if (mounted) setState(() => _uploading.remove(docType));
    }
  }

  Widget _back(BuildContext context, Color surf, bool isDark, Color ink) {
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    return GestureDetector(
      onTap: () => Navigator.maybePop(context),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
            color: surf,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: line),),
        child: Icon(Icons.arrow_back_ios_new_rounded, size: 15, color: ink),
      ),
    );
  }

  String _kademeLabel(int n) => switch (n) {
        1 => '1. Kademe — Yardımcı Antrenör',
        2 => '2. Kademe — Antrenör',
        3 => '3. Kademe — Kıdemli Antrenör',
        4 => '4. Kademe — Baş Antrenör',
        _ => '5. Kademe — Teknik Direktör',
      };
}
