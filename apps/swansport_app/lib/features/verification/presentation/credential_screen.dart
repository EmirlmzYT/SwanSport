import 'phone_verification_section.dart';
import '../../../app/widgets/action_gate.dart';
import '../../../app/design/swan_shape.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/swan_tabs.dart';

/// Lisans & Kimlik Doğrulama — Stitch Calm Athletic Modernism.
///
/// Kulüp lisans analitik paneli, öncelikli inceleme kuyruğu ve kişisel başvuru.
class CredentialScreen extends ConsumerStatefulWidget {
  const CredentialScreen({super.key});

  @override
  ConsumerState<CredentialScreen> createState() => _CredentialScreenState();
}

class _CredentialScreenState extends ConsumerState<CredentialScreen> {
  // Kişisel başvuru durumu
  int _mode = 2; // 0 antrenör, 1 sporcu, 2 kimlik
  int _kademe = 2;
  String? _sportCode;
  bool _busy = false;
  DateTime? _expiresOn;
  String? _credentialId;

  final Map<String, ({String fileName, String storagePath})> _docs = {};
  final Set<String> _uploading = {};

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = context.swan.bg;
    final surf = context.swan.surface;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final line = context.swan.line;
    final alt = (isDark ? SwanPalette.dark : SwanPalette.light).surfaceAlt;
    final async = ref.watch(myCredentialsProvider);
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                // Top Header (Stitch Screen 27)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.maybePop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: surf,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: line),
                        ),
                        child: Icon(Icons.close_rounded, size: 20, color: ink),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Lisans & Kimlik Doğrulama',
                        textAlign: TextAlign.center,
                        style: SwanType.h3(ink),
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: kTeal,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: kTeal.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child:
                          Icon(Icons.person_rounded, color: context.swan.ink),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                const PhoneVerificationSection(),

                // Kişisel Başvuru Bölümü (Supabase backend'e bağlı)
                SwanSegmentedTabs(
                  labels: const ['Antrenör', 'Sporcu', 'Kimlik'],
                  selected: _mode,
                  onSelect: (i) {
                    if (_busy || _uploading.isNotEmpty || i == _mode) return;
                    setState(() {
                      _mode = i;
                      _credentialId = null;
                      _docs.clear();
                    });
                  },
                ),
                const SizedBox(height: 16),

                if (_mode == 0) ...[
                  Text('Antrenör Kademe', style: SwanType.h3(ink)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: alt,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Row(
                      children: List.generate(5, (i) => _kademeItem(i + 1)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _kademeLabel(_kademe),
                    style: SwanType.caption(SwanColors.textSecondary,
                        w: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  Text('Branş', style: SwanType.h3(ink)),
                  const SizedBox(height: 8),
                  _sportPicker(isDark, alt, ink),
                  const SizedBox(height: 6),
                  Text(
                    'Belgen hangi branşa aitse onu seç. Platform bu branşta onaylar.',
                    style: SwanType.caption(SwanColors.textSecondary),
                  ),
                ] else if (_mode == 1) ...[
                  Text('Sporcu Branşı', style: SwanType.h3(ink)),
                  const SizedBox(height: 8),
                  _sportPicker(isDark, alt, ink),
                  const SizedBox(height: 6),
                  Text(
                    'Lisansın hangi branşa aitse onu seç. Bir kulübe bağlıysan lisanslı, değilsen ferdi sporcu sayılırsın.',
                    style: SwanType.caption(SwanColors.textSecondary),
                  ),
                ],

                const SizedBox(height: 16),
                if (_mode != 2) ...[
                  Text('Belge bitiş tarihi', style: SwanType.h3(ink)),
                  TextButton.icon(
                    onPressed: _busy ? null : _pickExpiry,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(_expiresOn == null
                        ? 'Bitiş tarihi seç'
                        : _expiresOn!.toIso8601String().substring(0, 10)),
                  ),
                  const SizedBox(height: SwanSpace.lg),
                ] else ...[
                  Text(
                      'Kimlik belgen platform yöneticisi tarafından incelenir. Kimlik onayı branş lisansı yerine geçmez.',
                      style: SwanType.bodySm(ink)),
                  const SizedBox(height: SwanSpace.lg),
                ],
                Text('Belgeler', style: SwanType.h3(ink)),
                const SizedBox(height: 8),
                if (_mode == 0) ...[
                  _uploadTile(isDark, 'kademe_belgesi', 'Kademe Belgesi'),
                  _uploadTile(isDark, 'kimlik', 'Kimlik (TC)'),
                ] else if (_mode == 1)
                  _uploadTile(isDark, 'federasyon', 'Federasyon Lisansı')
                else
                  _uploadTile(isDark, 'kimlik', 'Kimlik Belgesi'),
                const SizedBox(height: 4),
                Text(
                  'ⓘ PDF veya fotoğraf (JPG/PNG) yükleyebilirsin.',
                  style: SwanType.caption(SwanColors.textSecondary),
                ),

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
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Text(
                      _busy ? 'Gönderiliyor…' : 'Doğrulamaya Gönder',
                      style: SwanType.bodySm(Colors.white, w: FontWeight.w800),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                Text('Önceki Başvurularım', style: SwanType.h3(ink)),
                const SizedBox(height: 10),
                async.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child:
                        Center(child: CircularProgressIndicator(color: kTeal)),
                  ),
                  error: (e, _) => Text(
                    'Yüklenemedi: $e',
                    style: SwanType.caption(SwanColors.textSecondary),
                  ),
                  data: (creds) {
                    if (creds.isEmpty) {
                      return Text('Henüz başvuru yok.',
                          style: SwanType.caption(SwanColors.textSecondary));
                    }
                    return Column(
                      children: creds.map((c) => _credRow(isDark, c)).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sportPicker(bool isDark, Color alt, Color ink) {
    final sports = ref.watch(sportsProvider).valueOrNull ?? const <CityRow>[];
    final selected = sports.where((c) => c.code == _sportCode).firstOrNull;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;

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
        child: Row(
          children: [
            Expanded(
              child: Text(
                selected?.name ?? 'Branş seç',
                style: SwanType.bodySm(
                    selected == null ? SwanColors.textSecondary : ink,
                    w: FontWeight.w600),
              ),
            ),
            const Icon(Icons.expand_more_rounded,
                size: 20, color: SwanColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Future<void> _pickSport(List<CityRow> sports) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final search = TextEditingController();

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final q = search.text.trim().toLowerCase();
          final list = q.isEmpty
              ? sports
              : sports.where((c) => trContains(c.name, q)).toList();
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.75,
            decoration: BoxDecoration(
              color: surf,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              children: [
                Text('Branş seç', style: SwanType.h3(ink)),
                const SizedBox(height: 12),
                TextField(
                  controller: search,
                  autofocus: true,
                  onChanged: (_) => setSheet(() {}),
                  style: SwanType.bodySm(ink),
                  decoration: InputDecoration(
                    hintText: 'Ara…',
                    hintStyle: SwanType.bodySm(SwanColors.textSecondary),
                    prefixIcon: const Icon(Icons.search_rounded, size: 19),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) => ListTile(
                      title: Text(
                        list[i].name,
                        style: SwanType.bodySm(ink, w: FontWeight.w600),
                      ),
                      trailing: list[i].code == _sportCode
                          ? const Icon(Icons.check_rounded,
                              color: kTeal, size: 19)
                          : null,
                      onTap: () => Navigator.pop(ctx, list[i].code),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (picked != null && mounted) setState(() => _sportCode = picked);
  }

  Future<void> _submit() async {
    if (!await requireSwanAction(context, ref, SwanAction.publish) || !mounted)
      return;
    final requiredDocs = _mode == 0
        ? ['kademe_belgesi', 'kimlik']
        : [_mode == 1 ? 'federasyon' : 'kimlik'];
    final today = DateTime.now().toUtc().add(const Duration(hours: 3));
    final day = DateTime(today.year, today.month, today.day);
    if (_uploading.isNotEmpty ||
        requiredDocs.any((d) => !_docs.containsKey(d)) ||
        (_mode != 2 && (_expiresOn == null || _expiresOn!.isBefore(day)))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Gerekli belgeleri yükle ve spor belgesi için geçerli bitiş tarihi seç.')));
      return;
    }
    if (_mode != 2 && (_sportCode == null || _sportCode!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Önce branşını seç'),
          backgroundColor: SwanPalette.light.danger,
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final s = ref.read(verificationServiceProvider);
      final credId = _credentialId ??
          (_mode == 2
              ? await s.submitIdentityCredential()
              : _mode == 0
                  ? await s.submitCoachCredential(_kademe,
                      sportCode: _sportCode, expiresOn: _expiresOn)
                  : await s.submitAthleteCredential(
                      sportCode: _sportCode, expiresOn: _expiresOn));
      _credentialId = credId;

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
        setState(() {
          _docs.clear();
          _credentialId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Başvurun alındı — platform inceleyecek'),
            backgroundColor: kTeal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: SwanPalette.light.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _credRow(bool isDark, CredentialRow c) {
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final (color, icon) = switch (c.status) {
      'approved' => (SwanPalette.light.success, Icons.check_circle_rounded),
      'rejected' => (SwanPalette.light.danger, Icons.cancel_rounded),
      _ => (SwanPalette.light.warning, Icons.schedule_rounded),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line),
      ),
      child: Row(
        children: [
          Expanded(
            child:
                Text(c.label, style: SwanType.bodySm(ink, w: FontWeight.w700)),
          ),
          PremiumStatusChip(label: c.statusLabel, color: color, icon: icon),
        ],
      ),
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
          child: Text(
            '$n',
            style: SwanType.bodySm(on ? Colors.white : SwanColors.textSecondary,
                w: FontWeight.w800),
          ),
        ),
      ),
    );
  }

  Widget _uploadTile(bool isDark, String docType, String label) {
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    final alt = (isDark ? SwanPalette.dark : SwanPalette.light).surfaceAlt;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final picked = _docs[docType];
    final uploading = _uploading.contains(docType);
    final done = picked != null;

    final Color borderColor = done ? SwanPalette.light.success : line;

    return GestureDetector(
      onTap: (uploading || _busy) ? null : () => _pickAndUpload(docType),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: done ? SwanPalette.light.success.withValues(alpha: .06) : null,
          border: Border.all(color: borderColor, width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: done
                    ? SwanPalette.light.success.withValues(alpha: .12)
                    : alt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: uploading
                  ? const Padding(
                      padding: EdgeInsets.all(11),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: kTeal,
                      ),
                    )
                  : Icon(
                      done
                          ? Icons.check_circle_rounded
                          : Icons.upload_file_rounded,
                      size: 20,
                      color: done
                          ? SwanPalette.light.success
                          : SwanColors.textSecondary,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: SwanType.bodySm(ink, w: FontWeight.w700)),
                  if (done)
                    Text(
                      picked.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SwanType.caption(SwanColors.textSecondary),
                    ),
                ],
              ),
            ),
            if (done)
              GestureDetector(
                onTap: () => setState(() => _docs.remove(docType)),
                child: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: SwanColors.textSecondary,
                ),
              )
            else if (!uploading)
              Text(
                'Yükle',
                style: SwanType.caption(kTeal, w: FontWeight.w800),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now().toUtc().add(const Duration(hours: 3));
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
        context: context,
        firstDate: today,
        lastDate: DateTime(today.year + 30),
        initialDate: _expiresOn ?? today);
    if (picked != null && mounted) setState(() => _expiresOn = picked);
  }

  Future<void> _pickAndUpload(String docType) async {
    if (!await requireSwanAction(context, ref, SwanAction.publish) || !mounted)
      return;
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Yükleme hatası: $e'),
            backgroundColor: SwanPalette.light.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading.remove(docType));
    }
  }

  String _kademeLabel(int n) => switch (n) {
        1 => '1. Kademe — Yardımcı Antrenör',
        2 => '2. Kademe — Antrenör',
        3 => '3. Kademe — Kıdemli Antrenör',
        4 => '4. Kademe — Baş Antrenör',
        _ => '5. Kademe — Teknik Direktör',
      };
}
