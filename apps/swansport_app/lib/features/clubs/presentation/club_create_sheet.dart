import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/action_gate.dart';
import '../../../app/widgets/swan_city_picker.dart';

/// Yeni kulüp oluşturma bottom sheet'i.
Future<ClubRef?> showClubCreateSheet(BuildContext context) =>
    showModalBottomSheet<ClubRef?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ClubCreateSheet(),
    );

class _ClubCreateSheet extends ConsumerStatefulWidget {
  const _ClubCreateSheet();

  @override
  ConsumerState<_ClubCreateSheet> createState() => _ClubCreateSheetState();
}

class _ClubCreateSheetState extends ConsumerState<_ClubCreateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _shortNameController = TextEditingController();
  CityRow? _selectedCity;

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _shortNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final hasVerifiedIdentity =
        ref.read(swanAccessProvider).hasVerifiedIdentity;
    final creds = ref.read(myCredentialsProvider).valueOrNull;
    final isApprovedCoach = creds?.any((cr) =>
            cr.isCoach && cr.status == 'approved' && (cr.coachLevel ?? 0) >= 2) ??
        false;

    // Doğrulanmış hesap kontrolü (Yönlendirmeli uyarı)
    if (!hasVerifiedIdentity || !isApprovedCoach) {
      final req = !hasVerifiedIdentity
          ? const VerificationRequirement(
              title: 'Doğrulanmış Hesap Gerekli',
              description:
                  'Resmi kulüp kurma başvurusu yapabilmek için T.C. Kimlik doğrulamanızı tamamlamanız ve hesabınızın onaylanmış olması gerekmektedir.',
              targetMode: 2,
              actionLabel: 'Kimlik Doğrulamaya Git',
            )
          : const VerificationRequirement(
              title: '2. Kademe Antrenör Belgesi Gerekli',
              description:
                  'Kulüp kurabilmek ve federasyona bağlı kadro oluşturabilmek için en az 2. kademe onaylı antrenör belgenizin doğrulanmış olması gerekir.',
              targetMode: 0,
              actionLabel: 'Antrenör Belgesi Yükle',
            );

      await showVerificationRequiredSheet(context, requirement: req);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final name = _nameController.text.trim();
      final shortName = _shortNameController.text.trim();
      final city = _selectedCity?.name;

      final club = await ref.read(athleteServiceProvider).createClub(
            name,
            shortName: shortName.isNotEmpty ? shortName : null,
            city: city != null && city.isNotEmpty ? city : null,
          );

      ref.invalidate(myClubsProvider);
      ref.invalidate(activeClubProvider);
      ref.invalidate(swanAccessProvider);

      if (!mounted) return;
      Navigator.pop(context, club);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${club.name} kulübü başarıyla oluşturuldu!'),
          backgroundColor: context.swan.accent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);

      final req = VerificationRequirement.detect(e);
      if (req != null) {
        showVerificationRequiredSheet(context, requirement: req);
      } else {
        final cleanMsg = cleanPostgresMessage(e);
        setState(() {
          _error = 'Kulüp oluşturulamadı: $cleanMsg';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final creds = ref.watch(myCredentialsProvider).valueOrNull;
    final hasVerifiedIdentity =
        ref.watch(swanAccessProvider).hasVerifiedIdentity;
    final isApprovedCoach = creds?.any((cr) =>
            cr.isCoach && cr.status == 'approved' && (cr.coachLevel ?? 0) >= 2) ??
        false;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(SwanRadius.lg),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            SwanSpace.lg,
            SwanSpace.md,
            SwanSpace.lg,
            SwanSpace.xl,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: SwanSpace.md),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: c.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(SwanRadius.md),
                      ),
                      child: Icon(
                        Icons.add_business_rounded,
                        color: c.accent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: SwanSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Yeni Kulüp Kur', style: SwanType.h2(c.ink)),
                          Text(
                            'Kulübünü oluştur, kadronu kur ve yönet.',
                            style: SwanType.caption(c.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: c.inkMuted),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: SwanSpace.lg),

                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(SwanSpace.sm),
                    decoration: BoxDecoration(
                      color: c.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(SwanRadius.md),
                      border: Border.all(color: c.danger.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.error_outline_rounded,
                                color: c.danger, size: 20),
                            const SizedBox(width: SwanSpace.xs),
                            Expanded(
                              child: Text(
                                _error!,
                                style: SwanType.caption(c.danger),
                              ),
                            ),
                          ],
                        ),
                        if (_error!.contains('doğrula') ||
                            _error!.contains('antrenör') ||
                            _error!.contains('kimlik')) ...[
                          const SizedBox(height: SwanSpace.xs),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.pushNamed(context, '/dogrulama');
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: c.danger,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                              ),
                              icon: const Icon(Icons.arrow_forward_rounded,
                                  size: 14),
                              label: Text(
                                'Doğrulama Sayfasına Git',
                                style: SwanType.caption(c.danger,
                                    w: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: SwanSpace.md),
                ],

                // Bilgilendirme / Yönlendirmeli Yetki Kartı
                Container(
                  padding: const EdgeInsets.all(SwanSpace.md),
                  decoration: BoxDecoration(
                    color: isApprovedCoach && hasVerifiedIdentity
                        ? c.accent.withValues(alpha: 0.08)
                        : c.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(SwanRadius.md),
                    border: Border.all(
                      color: isApprovedCoach && hasVerifiedIdentity
                          ? c.accent.withValues(alpha: 0.25)
                          : c.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isApprovedCoach && hasVerifiedIdentity
                                ? Icons.verified_rounded
                                : Icons.verified_user_rounded,
                            color: isApprovedCoach && hasVerifiedIdentity
                                ? c.accent
                                : c.warning,
                            size: 22,
                          ),
                          const SizedBox(width: SwanSpace.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isApprovedCoach && hasVerifiedIdentity
                                      ? 'Yetkili Antrenör Profili'
                                      : 'Doğrulanmış Hesap Gerekli',
                                  style: SwanType.bodySm(
                                    isApprovedCoach && hasVerifiedIdentity
                                        ? c.accent
                                        : c.warning,
                                    w: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isApprovedCoach && hasVerifiedIdentity
                                      ? 'Onaylı antrenör belgeniz mevcut. Kulüp kurulduğunda kurucu ve yönetici olarak atanacaksınız.'
                                      : !hasVerifiedIdentity
                                          ? 'Resmi mevzuat gereği kulüp kurmak için T.C. Kimlik doğrulaması ve en az 2. kademe antrenör belgesi aranır.'
                                          : 'Kulüp kurabilmek için federasyon onaylı en az 2. kademe antrenör belgenizin doğrulanmış olması gerekir.',
                                  style: SwanType.caption(c.ink),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (!isApprovedCoach || !hasVerifiedIdentity) ...[
                        const SizedBox(height: SwanSpace.sm),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.pushNamed(
                                context,
                                '/dogrulama',
                                arguments: !hasVerifiedIdentity ? 2 : 0,
                              );
                            },
                            style: TextButton.styleFrom(
                              backgroundColor:
                                  c.warning.withValues(alpha: 0.15),
                              padding: const EdgeInsets.symmetric(
                                horizontal: SwanSpace.sm,
                                vertical: 6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(SwanRadius.sm),
                              ),
                            ),
                            icon: Icon(
                              Icons.arrow_forward_rounded,
                              size: 15,
                              color: c.ink,
                            ),
                            label: Text(
                              !hasVerifiedIdentity
                                  ? 'Kimlik Doğrulamaya Git'
                                  : 'Antrenör Belgesi Yükle',
                              style: SwanType.caption(c.ink,
                                  w: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: SwanSpace.md),

                // Kulüp Adı
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Kulüp Adı *',
                    hintText: 'Örn: Kadıköy Basketbol Spor Kulübü',
                    prefixIcon: const Icon(Icons.business_rounded, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(SwanRadius.md),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Lütfen kulüp adını giriniz';
                    }
                    if (v.trim().length < 3) {
                      return 'Kulüp adı en az 3 karakter olmalıdır';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: SwanSpace.md),

                // Kısa Ad ve Şehir
                TextFormField(
                  controller: _shortNameController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Kısa Ad / Kod (opsiyonel)',
                    hintText: 'Örn: KBSK',
                    prefixIcon: const Icon(Icons.tag_rounded, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(SwanRadius.md),
                    ),
                  ),
                ),
                const SizedBox(height: SwanSpace.md),

                // Şehir Seçici (81 il ekosistemi)
                SwanCityFormField(
                  label: 'Kulüp Şehri (81 İl)',
                  hint: 'Şehir seçiniz (örn: 34 İstanbul)',
                  selectedCity: _selectedCity?.name,
                  selectedCode: _selectedCity?.code,
                  onChanged: (city) => setState(() => _selectedCity = city),
                ),
                const SizedBox(height: SwanSpace.lg),

                // Kur butonu
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(SwanRadius.md),
                      ),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Kulübü Kur',
                            style: SwanType.bodySm(Colors.white,
                                w: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
