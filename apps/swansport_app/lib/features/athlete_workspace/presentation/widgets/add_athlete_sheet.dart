import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';

/// Kadroya sporcu ekleme.
///
/// **Neden liste, form değil:** eskiden bu akış ad ve soyad yazdırıp
/// `athletes` tablosuna kopuk bir satır atıyordu — `profile_id` hiç
/// yazılmıyordu. O kayıt bir insana bağlı olmadığı için o kişi giriş
/// yapamıyor, kendi kartını göremiyor, antrenman oturumuna katılamıyor ve
/// bildirim alamıyordu. Kulübün birbirini görmeyen iki listesi oluyordu:
/// gerçek hesaplar (`club_memberships`) ve ad-soyaddan ibaret kadro.
///
/// Artık önce kulübe **zaten katılmış** üyeler gösteriliyor. Platformdaki
/// tüm profillerde arama yapılmıyor: kulüp yöneticisine herhangi bir hesabı
/// kendi kulübüne sporcu diye ekleme yetkisi vermek olurdu. Buradaki
/// kişilerin rızası zaten alınmış — kulübe kendileri başvurup onaylanmışlar.
///
/// **Hesapsız sporcu hâlâ mümkün** ve alttaki düğme onun için duruyor:
/// küçük yaştaki sporcuların giriş profili olmayabiliyor (`profile_id`
/// 0001'den beri nullable). Bağlama zorunlu değil, mümkün.
Future<AddAthleteResult?> showAddAthleteSheet(
  BuildContext context,
  String clubId,
) =>
    showModalBottomSheet<AddAthleteResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddAthleteSheet(clubId: clubId),
    );

/// Sayfanın sonucu: ya bir üye seçildi ya da elle ekleme istendi.
sealed class AddAthleteResult {
  const AddAthleteResult();
}

/// Kulüp üyesi seçildi — kayıt hesaba bağlı oluşturulacak.
class AddAthleteFromMember extends AddAthleteResult {
  const AddAthleteFromMember(this.profileId, this.fullName);

  final String profileId;
  final String fullName;
}

/// Hesabı olmayan sporcu — eski elle giriş akışı.
class AddAthleteManually extends AddAthleteResult {
  const AddAthleteManually();
}

class _AddAthleteSheet extends ConsumerWidget {
  const _AddAthleteSheet({required this.clubId});

  final String clubId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.swan;
    final candidates = ref.watch(clubMemberCandidatesProvider(clubId));

    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(SwanRadius.lg)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: SwanSpace.md),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: c.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(SwanSpace.lg, SwanSpace.lg,
                SwanSpace.lg, SwanSpace.sm),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sporcu ekle', style: SwanType.h2(c.ink)),
                  const SizedBox(height: SwanSpace.xs),
                  Text(
                    'Kulübüne katılmış ama kadroda olmayan üyeler. Buradan '
                    'eklenen sporcu kendi hesabıyla giriş yapıp antrenmanlarını '
                    'görebilir.',
                    style: SwanType.bodySm(c.inkMuted),
                  ),
                ]),
          ),

          Flexible(
            child: candidates.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(SwanSpace.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(SwanSpace.lg),
                child: Text('$e', style: SwanType.bodySm(c.danger)),
              ),
              data: (list) => list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(SwanSpace.lg, 0,
                          SwanSpace.lg, SwanSpace.lg),
                      child: Text(
                        'Kadroda karşılığı olmayan üye yok. Sporcu önce '
                        'kulübüne katılmalı — başvurusunu onayladığında '
                        'burada görünür.',
                        style: SwanType.bodySm(c.inkMuted),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: list.length,
                      itemBuilder: (_, i) => _row(context, c, list[i]),
                    ),
            ),
          ),

          Divider(color: c.line, height: 1),
          Padding(
            padding: const EdgeInsets.all(SwanSpace.lg),
            child: Column(children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pop(context, const AddAthleteManually()),
                  icon: const Icon(Icons.person_add_alt_rounded, size: 18),
                  label: Text('Hesabı olmayan sporcu ekle',
                      style: SwanType.bodySm(c.ink)),
                ),
              ),
              const SizedBox(height: SwanSpace.xs),
              Text(
                'Küçük yaştaki sporcuların giriş hesabı olmayabilir. Bu kayıt '
                'sonradan bir hesaba bağlanabilir.',
                style: SwanType.caption(c.inkMuted),
                textAlign: TextAlign.center,
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _row(BuildContext context, SwanPalette c, ClubMemberCandidate m) =>
      ListTile(
        leading: CircleAvatar(
          backgroundColor: c.surfaceAlt,
          backgroundImage:
              m.avatarUrl == null ? null : NetworkImage(m.avatarUrl!),
          child: m.avatarUrl != null
              ? null
              : Icon(Icons.person_rounded, size: 18, color: c.inkMuted),
        ),
        title: Text(m.displayName,
            style: SwanType.body(m.hasName ? c.ink : c.inkMuted)),
        subtitle: m.hasName
            ? null
            // Profilinde ad yazmayan hesap: eklenebilir ama antrenörün adı
            // elle yazması gerekecek, bunu önceden söylemek gerekiyor.
            : Text('Adını sen yazacaksın',
                style: SwanType.caption(c.inkMuted)),
        trailing: Text('Ekle', style: SwanType.bodySm(c.accent)),
        onTap: () => Navigator.pop(
            context, AddAthleteFromMember(m.profileId, m.fullName)),
      );
}
