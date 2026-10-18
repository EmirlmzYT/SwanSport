import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';

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
  final _cityController = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _shortNameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final name = _nameController.text.trim();
      final shortName = _shortNameController.text.trim();
      final city = _cityController.text.trim();

      final club = await ref.read(athleteServiceProvider).createClub(
            name,
            shortName: shortName.isNotEmpty ? shortName : null,
            city: city.isNotEmpty ? city : null,
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
      setState(() {
        _loading = false;
        final raw = e.toString();
        if (raw.contains('Geçerli branşlı en az ikinci kademe belge') ||
            raw.contains('en az 2. kademe')) {
          _error =
              'Kulüp kurabilmek için federasyon onaylı en az 2. kademe antrenör belgenizin doğrulanmış olması gerekir.';
        } else {
          _error = 'Kulüp oluşturulamadı: $e';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final creds = ref.watch(myCredentialsProvider).valueOrNull;
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
                    child: Row(
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
                  ),
                  const SizedBox(height: SwanSpace.md),
                ],

                // Bilgilendirme / Yetki kartı
                Container(
                  padding: const EdgeInsets.all(SwanSpace.md),
                  decoration: BoxDecoration(
                    color: isApprovedCoach
                        ? c.accent.withValues(alpha: 0.08)
                        : c.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(SwanRadius.md),
                    border: Border.all(
                      color: isApprovedCoach
                          ? c.accent.withValues(alpha: 0.25)
                          : c.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isApprovedCoach
                            ? Icons.verified_rounded
                            : Icons.info_outline_rounded,
                        color: isApprovedCoach ? c.accent : c.warning,
                        size: 20,
                      ),
                      const SizedBox(width: SwanSpace.sm),
                      Expanded(
                        child: Text(
                          isApprovedCoach
                              ? 'Onaylı antrenör belgeniz mevcut. Kulüp kurulduğunda kurucu ve yönetici olarak atanacaksınız.'
                              : 'Resmi mevzuat gereği kulüp kurmak için en az 2. kademe onaylı antrenör belgesi aranır.',
                          style: SwanType.caption(c.ink),
                        ),
                      ),
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
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextFormField(
                        controller: _shortNameController,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Kısa Ad / Kod',
                          hintText: 'Örn: KBSK',
                          prefixIcon: const Icon(Icons.tag_rounded, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(SwanRadius.md),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: SwanSpace.sm),
                    Expanded(
                      flex: 6,
                      child: TextFormField(
                        controller: _cityController,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'Şehir',
                          hintText: 'Örn: İstanbul',
                          prefixIcon:
                              const Icon(Icons.location_city_rounded, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(SwanRadius.md),
                          ),
                        ),
                      ),
                    ),
                  ],
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
