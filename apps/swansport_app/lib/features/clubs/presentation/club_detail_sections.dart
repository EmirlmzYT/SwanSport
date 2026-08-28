import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';
import '../../../app/widgets/quick_form.dart';
import '../../social/presentation/widgets/social_widgets.dart';

/// Kulüp profilinin künye bölümü — adres, iletişim, kuruluş, branş.
///
/// Hiçbir alan doldurulmamışsa bölüm görünmez; yalnızca kulüp yöneticisine
/// "künyeyi doldur" çağrısı çıkar. Boş satırlarla dolu bir kart göstermek
/// sayfayı zenginleştirmiyor, tam tersine bakımsız gösteriyor.
class ClubIdentitySection extends ConsumerWidget {
  const ClubIdentitySection({super.key, required this.clubId});
  final String clubId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(clubDetailsProvider(clubId)).valueOrNull;
    if (d == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

    if (!d.hasAnyDetail && !d.canManage) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text('KÜNYE',
                  style: jakarta(11, FontWeight.w700, SwanColors.textSecondary,
                      ls: 1.2)),
            ),
            if (d.canManage)
              GestureDetector(
                onTap: () => _edit(context, ref, d),
                child: Text('Düzenle',
                    style: jakarta(11.5, FontWeight.w800, kTeal)),
              ),
          ]),
          const SizedBox(height: 10),

          // Sayılar — kulübün büyüklüğü bir bakışta.
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: surf,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: line),
            ),
            child: Column(children: [
              Row(children: [
                _count(ink, '${d.athleteCount}', 'Sporcu'),
                _count(ink, '${d.coachCount}', 'Antrenör'),
                _count(ink, '${d.teamCount}', 'Takım'),
                _count(ink, '${d.memberCount}', 'Üye'),
              ]),
              if (d.hasAnyDetail) ...[
                const SizedBox(height: 14),
                Divider(color: line, height: 1),
                const SizedBox(height: 12),
                if ((d.sportName ?? '').isNotEmpty)
                  _line(ink, Icons.sports_volleyball_rounded, d.sportName!),
                if (d.foundedYear != null)
                  _line(ink, Icons.flag_rounded, '${d.foundedYear} kuruluş'),
                if (d.location != null)
                  _line(ink, Icons.location_on_rounded, d.location!),
                if ((d.address ?? '').isNotEmpty)
                  _line(ink, Icons.home_work_rounded, d.address!),
                if ((d.phone ?? '').isNotEmpty)
                  _line(ink, Icons.phone_rounded, d.phone!, copyable: true),
                if ((d.email ?? '').isNotEmpty)
                  _line(ink, Icons.mail_rounded, d.email!, copyable: true),
                if ((d.website ?? '').isNotEmpty)
                  _line(ink, Icons.language_rounded, d.website!, copyable: true),
                if ((d.instagram ?? '').isNotEmpty)
                  _line(ink, Icons.camera_alt_rounded,
                      d.instagram!.startsWith('@')
                          ? d.instagram!
                          : '@${d.instagram!}',
                      copyable: true),
              ] else if (d.canManage) ...[
                const SizedBox(height: 12),
                Text(
                    'Künye boş. Adres, telefon ve kuruluş yılını eklersen '
                    'kulübünü arayanlar sana ulaşabilir.',
                    style: jakarta(
                        11.5, FontWeight.w500, SwanColors.textSecondary)),
              ],
            ]),
          ),
        ],
      ),
    );
  }

  Widget _count(Color ink, String value, String label) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: sora(19, FontWeight.w800, ink)),
            const SizedBox(height: 2),
            Text(label,
                style:
                    jakarta(10.5, FontWeight.w600, SwanColors.textSecondary)),
          ],
        ),
      );

  /// Künye satırı. Kopyalanabilir olanlar (telefon, e-posta) dokununca panoya
  /// alınır — telefonda elle yazmak zahmetli.
  Widget _line(Color ink, IconData icon, String value,
      {bool copyable = false}) {
    return Builder(builder: (context) {
      final row = Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 15, color: SwanColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(value, style: jakarta(12.5, FontWeight.w600, ink)),
          ),
          if (copyable)
            const Icon(Icons.copy_rounded,
                size: 13, color: SwanColors.textSecondary),
        ]),
      );
      if (!copyable) return row;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Clipboard.setData(ClipboardData(text: value));
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Kopyalandı'), backgroundColor: kTeal));
        },
        child: row,
      );
    });
  }

  Future<void> _edit(
      BuildContext context, WidgetRef ref, ClubDetails d) async {
    final district = FormField_('İlçe', hint: 'Selçuklu', required: false)
      ..controller.text = d.district ?? '';
    final address = FormField_('Adres', hint: 'Mahalle, cadde, no',
        required: false)
      ..controller.text = d.address ?? '';
    final phone = FormField_('Telefon', hint: '0332 000 00 00', required: false)
      ..controller.text = d.phone ?? '';
    final email = FormField_('E-posta', hint: 'kulup@ornek.com', required: false)
      ..controller.text = d.email ?? '';
    final website = FormField_('Web sitesi', hint: 'ornekkulup.com',
        required: false)
      ..controller.text = d.website ?? '';
    final insta = FormField_('Instagram', hint: 'kullaniciadi', required: false)
      ..controller.text = d.instagram ?? '';
    final founded = FormField_('Kuruluş yılı', hint: '1998', required: false)
      ..controller.text = d.foundedYear?.toString() ?? '';

    final ok = await showQuickForm(
      context,
      title: 'Kulüp künyesi',
      note: 'Boş bıraktığın alan temizlenir.',
      fields: [district, address, phone, email, website, insta, founded],
      onSubmit: () => ref.read(clubProfileServiceProvider).updateDetails(
            d.id,
            district: district.value,
            address: address.value,
            phone: phone.value,
            email: email.value,
            website: website.value,
            instagram: insta.value,
            foundedYear: int.tryParse(founded.value),
          ),
    );
    if (ok == true) ref.invalidate(clubDetailsProvider(d.id));
  }
}

/// Antrenör kadrosu — kulüp sayfasında kimlerin çalıştırdığı görünsün.
class ClubCoachesSection extends ConsumerWidget {
  const ClubCoachesSection({super.key, required this.clubId});
  final String clubId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(clubCoachesProvider(clubId)).valueOrNull ?? const [];
    if (list.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TEKNİK KADRO',
              style: jakarta(11, FontWeight.w700, SwanColors.textSecondary,
                  ls: 1.2)),
          const SizedBox(height: 10),
          for (final c in list)
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/profil',
                  arguments: c.profileId),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: surf,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: c.isAdmin ? kTeal.withValues(alpha: .35) : line),
                ),
                child: Row(children: [
                  SocialAvatar(
                      initials: c.initials,
                      imageUrl: c.avatarUrl,
                      size: 38,
                      gradientIndex: c.profileId.hashCode.abs() % 4),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: jakarta(13, FontWeight.w700, ink)),
                        Text(c.title,
                            style: jakarta(10.5, FontWeight.w600,
                                c.isAdmin ? kTeal : SwanColors.textSecondary)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      size: 17, color: SwanColors.textSecondary),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

/// Kulüp başarıları — vitrin.
class ClubAchievementsSection extends ConsumerWidget {
  const ClubAchievementsSection({super.key, required this.clubId});
  final String clubId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list =
        ref.watch(clubAchievementsProvider(clubId)).valueOrNull ?? const [];
    final canManage =
        ref.watch(clubDetailsProvider(clubId)).valueOrNull?.canManage ?? false;
    if (list.isEmpty && !canManage) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text('BAŞARILAR',
                  style: jakarta(11, FontWeight.w700, SwanColors.textSecondary,
                      ls: 1.2)),
            ),
            if (canManage)
              GestureDetector(
                onTap: () => _add(context, ref),
                child:
                    Text('Ekle', style: jakarta(11.5, FontWeight.w800, kTeal)),
              ),
          ]),
          const SizedBox(height: 10),
          if (list.isEmpty)
            Text('Henüz başarı eklenmemiş.',
                style:
                    jakarta(11.5, FontWeight.w500, SwanColors.textSecondary))
          else
            for (final a in list)
              GestureDetector(
                onLongPress: a.canManage ? () => _remove(context, ref, a) : null,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: surf,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: line),
                  ),
                  child: Row(children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9B949).withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(Icons.emoji_events_rounded,
                          size: 18, color: Color(0xFFD9860B)),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.title,
                              style: jakarta(12.5, FontWeight.w700, ink)),
                          if ((a.rank ?? '').isNotEmpty ||
                              (a.note ?? '').isNotEmpty)
                            Text(
                                [
                                  if ((a.rank ?? '').isNotEmpty) a.rank!,
                                  if ((a.note ?? '').isNotEmpty) a.note!,
                                ].join(' · '),
                                style: jakarta(10.5, FontWeight.w500,
                                    SwanColors.textSecondary)),
                        ],
                      ),
                    ),
                    if (a.year != null)
                      Text('${a.year}',
                          style: jakarta(12, FontWeight.w800,
                              SwanColors.textSecondary)),
                  ]),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final title = FormField_('Başarı', hint: 'Konya İl Şampiyonası');
    final rank = FormField_('Derece', hint: 'Şampiyon / 2.', required: false);
    final year = FormField_('Yıl', hint: '2025', required: false);

    final ok = await showQuickForm(
      context,
      title: 'Başarı ekle',
      fields: [title, rank, year],
      onSubmit: () => ref.read(clubProfileServiceProvider).addAchievement(
            clubId,
            title.value,
            rank: rank.value,
            year: int.tryParse(year.value),
          ),
    );
    if (ok == true) ref.invalidate(clubAchievementsProvider(clubId));
  }

  Future<void> _remove(
      BuildContext context, WidgetRef ref, ClubAchievement a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Başarıyı sil'),
        content: Text('"${a.title}" kaydı silinecek.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sil')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(clubProfileServiceProvider).removeAchievement(a.id);
    ref.invalidate(clubAchievementsProvider(clubId));
  }
}
