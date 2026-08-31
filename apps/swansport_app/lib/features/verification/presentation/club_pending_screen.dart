import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';
import '../../demo/demo_role.dart';
import '../../../app/design/swan_type.dart';

/// Kulüp onay bekliyor — belgeler platform yöneticisince incelenene kadar
/// yöneticinin karşılaştığı kilitli ekran (premium v3).
///
/// Kulüp resmi belgelerini (tescil + federasyon) buradan yükler; belgeler
/// Storage'a gidip kulübe bağlanır, platform yöneticisi onay panelinden görür.
class ClubPendingScreen extends ConsumerStatefulWidget {
  const ClubPendingScreen({super.key});

  @override
  ConsumerState<ClubPendingScreen> createState() => _ClubPendingScreenState();
}

class _ClubPendingScreenState extends ConsumerState<ClubPendingScreen> {
  /// Yüklenip kulübe bağlanmış belgeler: docType -> dosya adı.
  final Map<String, String> _uploaded = {};

  /// Şu an yüklenmekte olan docType'lar.
  final Set<String> _uploading = {};

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

    final club = ref.watch(activeClubProvider).valueOrNull;
    final isAdmin = ref.watch(effectiveIsPlatformAdminProvider);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              children: [
                // Kilit rozeti
                Center(
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFF5B23E), Color(0xFFD9860B)],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD9860B).withValues(alpha: .34),
                          blurRadius: 26,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.hourglass_top_rounded,
                        size: 44, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Kulübün inceleniyor',
                    textAlign: TextAlign.center,
                    style: SwanType.h1(ink)),
                const SizedBox(height: 8),
                Text(
                  club != null
                      ? '“${club.name}” için kulüp belgelerini yükle; platform '
                          'yöneticisi inceleyip onaylayınca kulüp panelin açılır.'
                      : 'Kulüp belgelerini yükle; platform yöneticisi inceleyip '
                          'onaylayınca panelin açılır.',
                  textAlign: TextAlign.center,
                  style:
                      SwanType.bodySm(SwanColors.textSecondary),
                ),
                const SizedBox(height: 26),

                // Durum kartı
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: surf,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: line),
                  ),
                  child: Column(
                    children: [
                      _step(
                          ink,
                          _uploaded.isNotEmpty,
                          Icons.upload_file_rounded,
                          'Belgeler yüklendi',
                          'Kulüp tescil + federasyon kaydı'),
                      _stepDivider(line),
                      _step(ink, true, Icons.hourglass_top_rounded,
                          'İnceleme sürüyor', 'Platform yöneticisi kontrol ediyor',
                          active: true),
                      _stepDivider(line),
                      _step(ink, false, Icons.verified_rounded, 'Onay',
                          'Kulüp paneli erişime açılır'),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Kulüp belgeleri yükleme
                if (club != null) ...[
                  Text('Kulüp Belgeleri', style: SwanType.h3(ink)),
                  const SizedBox(height: 10),
                  _uploadTile(isDark, club.id, 'tescil', 'Kulüp tescil belgesi'),
                  _uploadTile(
                      isDark, club.id, 'federasyon', 'Federasyon kayıt belgesi'),
                  const SizedBox(height: 2),
                  Text(
                      'ⓘ PDF veya fotoğraf (JPG/PNG). Belgeler yalnızca sana ve '
                      'platform yöneticisine görünür.',
                      style: SwanType.caption(SwanColors.textSecondary)),
                  const SizedBox(height: 20),
                ],

                // Durumu yenile
                GestureDetector(
                  onTap: () async {
                    ref.invalidate(myClubsProvider);
                    await ref.read(activeClubProvider.future);
                  },
                  child: Container(
                    height: 52,
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.refresh_rounded,
                            size: 19, color: Colors.white),
                        const SizedBox(width: 8),
                        Text('Durumu Yenile',
                            style: SwanType.bodySm(Colors.white, w: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),

                // Platform yöneticisiyse: onay paneline git (kendi kulübünü
                // buradan onaylayabilir).
                if (isAdmin) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/onay-paneli'),
                    child: Container(
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD9860B).withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                            color:
                                const Color(0xFFD9860B).withValues(alpha: .4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.admin_panel_settings_rounded,
                              size: 18, color: Color(0xFFD9860B)),
                          const SizedBox(width: 8),
                          Text('Onay Paneli (Yönetici)',
                              style: SwanType.bodySm(const Color(0xFFD9860B), w: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                Center(
                  child: GestureDetector(
                    onTap: () async {
                      await Supabase.instance.client.auth.signOut();
                      if (context.mounted) {
                        Navigator.pushNamedAndRemoveUntil(
                            context, '/', (_) => false);
                      }
                    },
                    child: Text('Çıkış Yap',
                        style: SwanType.bodySm(const Color(0xFFF43F5E), w: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _uploadTile(
      bool isDark, String clubId, String docType, String label) {
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final alt = isDark ? const Color(0xFF1A2537) : const Color(0xFFF1F5F8);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final fileName = _uploaded[docType];
    final uploading = _uploading.contains(docType);
    final done = fileName != null;

    return GestureDetector(
      onTap: uploading ? null : () => _pickAndUpload(clubId, docType),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: done ? const Color(0xFF10B981).withValues(alpha: .06) : null,
          border: Border.all(
              color: done ? const Color(0xFF10B981) : line, width: 1.5),
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
                    child:
                        CircularProgressIndicator(strokeWidth: 2, color: kTeal),
                  )
                : Icon(
                    done
                        ? Icons.check_circle_rounded
                        : Icons.upload_file_rounded,
                    size: 20,
                    color: done
                        ? const Color(0xFF10B981)
                        : SwanColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: SwanType.bodySm(ink, w: FontWeight.w700)),
                if (done)
                  Text(fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SwanType.caption(SwanColors.textSecondary)),
              ],
            ),
          ),
          if (!done && !uploading)
            Text('Yükle', style: SwanType.caption(kTeal, w: FontWeight.w800)),
        ]),
      ),
    );
  }

  Future<void> _pickAndUpload(String clubId, String docType) async {
    try {
      final f = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (f == null) return;
      final bytes = await f.readAsBytes();
      if (!mounted) return;
      setState(() => _uploading.add(docType));
      final service = ref.read(verificationServiceProvider);
      final path = await service.uploadDocument(
          docType: docType, bytes: bytes, fileName: f.name);
      await service.attachDocuments(
        ownerType: 'club',
        ownerId: clubId,
        docs: [(docType: docType, storagePath: path)],
      );
      if (mounted) {
        setState(() => _uploaded[docType] = f.name);
        _snack('Belge yüklendi', kTeal);
      }
    } catch (e) {
      if (mounted) _snack('Yükleme hatası: $e', const Color(0xFFF43F5E));
    } finally {
      if (mounted) setState(() => _uploading.remove(docType));
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Widget _step(Color ink, bool done, IconData icon, String title, String sub,
      {bool active = false}) {
    final Color accent = active
        ? const Color(0xFFD9860B)
        : (done ? kTeal : SwanColors.textSecondary);
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: done || active ? .12 : .06),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(done && !active ? Icons.check_rounded : icon,
              size: 20, color: accent),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: SwanType.bodySm(ink, w: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(sub,
                  style: SwanType.caption(SwanColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepDivider(Color line) => Padding(
        padding: const EdgeInsets.only(left: 20),
        child: Container(
          width: 1,
          height: 16,
          margin: const EdgeInsets.symmetric(vertical: 4),
          color: line,
        ),
      );
}
