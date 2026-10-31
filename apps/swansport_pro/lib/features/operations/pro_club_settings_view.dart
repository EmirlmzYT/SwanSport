import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../widgets/pro_ui_components.dart';

class ProClubSettingsView extends ConsumerStatefulWidget {
  const ProClubSettingsView({super.key});

  @override
  ConsumerState<ProClubSettingsView> createState() =>
      _ProClubSettingsViewState();
}

class _ProClubSettingsViewState extends ConsumerState<ProClubSettingsView> {
  final _name = TextEditingController();
  final _shortName = TextEditingController();
  final _city = TextEditingController();
  final _district = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _website = TextEditingController();
  final _address = TextEditingController();
  final _bio = TextEditingController();
  String? _loadedClubId;
  List<String> _sections = const [];
  bool _dirty = false;
  bool _sportsDirty = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _shortName,
      _city,
      _district,
      _phone,
      _email,
      _website,
      _address,
      _bio,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _load(ClubIdentity identity) {
    if (_loadedClubId == identity.id) return;
    _loadedClubId = identity.id;
    _name.text = identity.name;
    _shortName.text = identity.shortName ?? '';
    _city.text = identity.city ?? '';
    _district.text = identity.district ?? '';
    _phone.text = identity.phone ?? '';
    _email.text = identity.email ?? '';
    _website.text = identity.website ?? '';
    _address.text = identity.address ?? '';
    _bio.text = identity.bio ?? '';
    _sections = List<String>.of(identity.effectiveSections);
    _dirty = false;
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  Widget build(BuildContext context) {
    final clubAsync = ref.watch(activeClubProvider);
    final identityAsync = ref.watch(clubIdentityProvider);
    if (clubAsync.isLoading || identityAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (clubAsync.hasError || identityAsync.hasError) {
      return ProErrorState(
        message: 'Kulüp ayarları yüklenemedi.',
        onRetry: _refresh,
      );
    }
    final club = clubAsync.valueOrNull;
    final identity = identityAsync.valueOrNull;
    if (club == null || identity == null) {
      return const ProEmptyState(
        icon: Icons.apartment_outlined,
        title: 'Aktif kulüp bulunamadı',
        subtitle: 'Ayarları görmek için yetkili olduğun bir kulübü seç.',
      );
    }
    _load(identity);
    final isAdmin = club.role == 'club_admin';
    final canManageOperations = isAdmin || club.role == 'coach';

    return PopScope(
      canPop: !_dirty && !_sportsDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !mounted) return;
        final shouldDiscard = await _confirmDiscard();
        if (!mounted || !shouldDiscard) return;
        setState(() {
          _dirty = false;
          _sportsDirty = false;
        });
        Navigator.of(this.context).pop();
      },
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          key: const Key('club-settings-list'),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            if (!isAdmin)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.lock_outline_rounded),
                  title: Text('Sınırlı operasyon yetkisi'),
                  subtitle: Text(
                    'Antrenörler kulüp kimliği, sezon ve personel rollerini '
                    'değiştiremez; yalnızca yetkili operasyon alanlarını yönetir.',
                  ),
                ),
              ),
            _section(
              title: 'Kulüp temel bilgileri',
              subtitle: isAdmin
                  ? 'Kurumsal kimlik ve iletişim alanları'
                  : 'Kulüp yöneticisi tarafından düzenlenir',
              child: _identityForm(enabled: isAdmin),
            ),
            _section(
              title: 'Kulüp operasyon tercihleri',
              subtitle: 'Kulüp profilinde gösterilecek bölümler',
              child: _sectionPreferences(enabled: isAdmin),
            ),
            if (isAdmin)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    key: const Key('save-club-settings'),
                    onPressed: _dirty && !_saving ? _saveIdentity : null,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _saving ? 'Kaydediliyor…' : 'Değişiklikleri kaydet',
                    ),
                  ),
                ),
              ),
            _section(
              title: 'Aktif sezon ve sezon yönetimi',
              subtitle: isAdmin
                  ? 'Sezon oluştur, etkinleştir veya kaldır'
                  : 'Sezon bilgileri salt okunur',
              child: _SeasonsSettings(canEdit: isAdmin),
            ),
            _section(
              title: 'Branş ayarları',
              subtitle: canManageOperations
                  ? 'Kulübün antrenman branşlarını belirle'
                  : 'Branş bilgileri salt okunur',
              child: _SportsSettings(
                clubId: club.id,
                canEdit: canManageOperations,
                onDirtyChanged: (value) {
                  if (mounted && _sportsDirty != value) {
                    setState(() => _sportsDirty = value);
                  }
                },
              ),
            ),
            _section(
              title: 'Takım ve kategori ayarları',
              subtitle: canManageOperations
                  ? 'Yaş grubu ve kategoriyle takım oluştur'
                  : 'Takım bilgileri salt okunur',
              child: _TeamsSettings(
                clubId: club.id,
                canEdit: canManageOperations,
              ),
            ),
            _section(
              title: 'Yetkili personel',
              subtitle: isAdmin
                  ? 'Personel rollerini incele ve yönet'
                  : 'Personel görünümü salt okunur',
              child: _PersonnelSettings(canEdit: isAdmin),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required String subtitle,
    required Widget child,
  }) =>
      Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProSectionHeader(title: title, subtitle: subtitle),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      );

  Widget _identityForm({required bool enabled}) => LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth >= 680
              ? (constraints.maxWidth - 12) / 2
              : constraints.maxWidth;
          final fields = <(TextEditingController, String, int)>[
            (_name, 'Kulüp adı', 1),
            (_shortName, 'Kısa ad', 1),
            (_city, 'Şehir', 1),
            (_district, 'İlçe', 1),
            (_phone, 'Telefon', 1),
            (_email, 'E-posta', 1),
            (_website, 'Web sitesi', 1),
            (_address, 'Adres', 2),
            (_bio, 'Kulüp açıklaması', 3),
          ];
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final field in fields)
                SizedBox(
                  width: field.$3 > 1 ? constraints.maxWidth : width,
                  child: TextField(
                    controller: field.$1,
                    enabled: enabled,
                    maxLines: field.$3,
                    onChanged: (_) => _markDirty(),
                    decoration: InputDecoration(labelText: field.$2),
                  ),
                ),
            ],
          );
        },
      );

  Widget _sectionPreferences({required bool enabled}) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final key in ClubSection.defaults)
            FilterChip(
              label: Text(ClubSection.label(key)),
              selected: _sections.contains(key),
              onSelected: enabled
                  ? (selected) {
                      setState(() {
                        selected ? _sections.add(key) : _sections.remove(key);
                        _dirty = true;
                      });
                    }
                  : null,
            ),
        ],
      );

  Future<void> _saveIdentity() async {
    if (_name.text.trim().isEmpty) {
      _message('Kulüp adı boş bırakılamaz.');
      return;
    }
    final club = ref.read(activeClubProvider).valueOrNull;
    if (club == null || club.role != 'club_admin') return;
    setState(() => _saving = true);
    try {
      await ref.read(clubConfigServiceProvider).updateIdentity(
            club.id,
            name: _name.text,
            shortName: _shortName.text,
            city: _city.text,
            district: _district.text,
            phone: _phone.text,
            email: _email.text,
            website: _website.text,
            address: _address.text,
            bio: _bio.text,
            sections: List<String>.of(_sections),
          );
      ref.invalidate(clubIdentityProvider);
      ref.invalidate(myClubsProvider);
      if (mounted) setState(() => _dirty = false);
      _message('Kulüp ayarları kaydedildi.');
    } catch (error) {
      _message(
        'Ayarlar kaydedilemedi: ${classifyOperationError(error).userMessage}',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(clubIdentityProvider);
    ref.invalidate(clubMembersAdminProvider);
    ref.invalidate(clubSeasonsProvider);
    ref.invalidate(teamsProvider);
    final clubId = ref.read(activeClubProvider).valueOrNull?.id;
    if (clubId != null) ref.invalidate(clubTrainingSportsProvider(clubId));
    await ref.read(clubIdentityProvider.future);
  }

  Future<bool> _confirmDiscard() async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Kaydedilmemiş değişiklikler'),
          content: const Text(
            'Değişiklikleri kaydetmeden çıkmak istiyor musun?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Düzenlemeye devam et'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Kaydetmeden çık'),
            ),
          ],
        ),
      ) ??
      false;

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SeasonsSettings extends ConsumerWidget {
  const _SeasonsSettings({required this.canEdit});
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(clubSeasonsProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ProErrorState(
              message: 'Sezonlar yüklenemedi.',
              onRetry: () => ref.invalidate(clubSeasonsProvider),
            ),
            data: (rows) => Column(
              children: [
                if (canEdit)
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => _add(context, ref),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Sezon ekle'),
                    ),
                  ),
                if (rows.isEmpty)
                  const ProEmptyState(
                    icon: Icons.calendar_month_outlined,
                    title: 'Sezon tanımlı değil',
                    subtitle: 'Gerçek sezon kayıtları burada görünür.',
                  ),
                for (final row in rows)
                  ListTile(
                    leading: Icon(
                      row.isActive
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                    ),
                    title: Text(row.label),
                    subtitle: Text(_dates(row)),
                    trailing: canEdit
                        ? PopupMenuButton<String>(
                            onSelected: (action) =>
                                _act(context, ref, row, action),
                            itemBuilder: (_) => [
                              if (!row.isActive)
                                const PopupMenuItem(
                                  value: 'activate',
                                  child: Text('Aktif sezon yap'),
                                ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Sezonu sil'),
                              ),
                            ],
                          )
                        : null,
                  ),
              ],
            ),
          );

  String _dates(SeasonRow row) =>
      '${_date(row.startsOn)} — ${_date(row.endsOn)}${row.isActive ? ' · Aktif' : ''}';
  String _date(DateTime? value) => value == null
      ? 'Tarih yok'
      : '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Yeni sezon'),
        content: TextField(
          key: const Key('new-season-label'),
          controller: controller,
          decoration: const InputDecoration(labelText: 'Sezon adı'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
    final club = ref.read(activeClubProvider).valueOrNull;
    if (save != true || controller.text.trim().isEmpty || club == null) return;
    try {
      await ref
          .read(clubConfigServiceProvider)
          .createSeason(club.id, controller.text);
      ref.invalidate(clubSeasonsProvider);
    } catch (error) {
      if (context.mounted) _snack(context, error);
    }
  }

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    SeasonRow row,
    String action,
  ) async {
    final club = ref.read(activeClubProvider).valueOrNull;
    if (club == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          action == 'delete'
              ? 'Sezon silinsin mi?'
              : 'Aktif sezon değiştirilsin mi?',
        ),
        content: Text(
          action == 'delete'
              ? '${row.label} geri alınamaz biçimde silinecek.'
              : '${row.label} aktif sezon olacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final service = ref.read(clubConfigServiceProvider);
      if (action == 'delete') {
        await service.removeSeason(row.id);
      } else {
        await service.activateSeason(club.id, row.id);
      }
      ref.invalidate(clubSeasonsProvider);
    } catch (error) {
      if (context.mounted) _snack(context, error);
    }
  }
}

class _SportsSettings extends ConsumerStatefulWidget {
  const _SportsSettings({
    required this.clubId,
    required this.canEdit,
    required this.onDirtyChanged,
  });
  final String clubId;
  final bool canEdit;
  final ValueChanged<bool> onDirtyChanged;

  @override
  ConsumerState<_SportsSettings> createState() => _SportsSettingsState();
}

class _SportsSettingsState extends ConsumerState<_SportsSettings> {
  Set<String>? selected;
  bool saving = false;

  @override
  void didUpdateWidget(covariant _SportsSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clubId != widget.clubId) {
      selected = null;
    }
  }

  @override
  Widget build(BuildContext context) =>
      ref.watch(clubTrainingSportsProvider(widget.clubId)).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ProErrorState(
              message: 'Branşlar yüklenemedi.',
              onRetry: () =>
                  ref.invalidate(clubTrainingSportsProvider(widget.clubId)),
            ),
            data: (codes) {
              selected ??= codes.toSet();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final sport in SportsCatalog.all)
                        FilterChip(
                          label: Text(sport.name),
                          selected: selected!.contains(sport.code),
                          onSelected: widget.canEdit
                              ? (value) {
                                  setState(
                                    () => value
                                        ? selected!.add(sport.code)
                                        : selected!.remove(sport.code),
                                  );
                                  widget.onDirtyChanged(true);
                                }
                              : null,
                        ),
                    ],
                  ),
                  if (widget.canEdit) ...[
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: saving ? null : _save,
                      child:
                          Text(saving ? 'Kaydediliyor…' : 'Branşları kaydet'),
                    ),
                  ],
                ],
              );
            },
          );

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await ref.read(clubTrainingSportsServiceProvider).setClubTrainingSports(
            clubId: widget.clubId,
            sportCodes: selected!.toList(),
          );
      widget.onDirtyChanged(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Branş ayarları kaydedildi.')),
        );
      }
    } catch (error) {
      if (mounted) _snack(context, error);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

class _TeamsSettings extends ConsumerWidget {
  const _TeamsSettings({required this.clubId, required this.canEdit});
  final String clubId;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(teamsProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ProErrorState(
              message: 'Takımlar yüklenemedi.',
              onRetry: () => ref.invalidate(teamsProvider),
            ),
            data: (rows) => Column(
              children: [
                if (canEdit)
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => _add(context, ref),
                      icon: const Icon(Icons.group_add_outlined),
                      label: const Text('Takım ekle'),
                    ),
                  ),
                if (rows.isEmpty)
                  const ProEmptyState(
                    icon: Icons.groups_outlined,
                    title: 'Takım tanımlı değil',
                    subtitle: 'Gerçek takım kayıtları burada görünür.',
                  ),
                for (final row in rows)
                  ListTile(
                    leading: const Icon(Icons.groups_2_outlined),
                    title: Text(row.name),
                    subtitle: Text(
                      [
                        if (row.ageGroup?.isNotEmpty ?? false) row.ageGroup!,
                        if (row.gender?.isNotEmpty ?? false) row.gender!,
                      ].join(' · '),
                    ),
                  ),
              ],
            ),
          );

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final age = TextEditingController();
    final category = TextEditingController();
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Takım oluştur'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Takım adı'),
            ),
            TextField(
              controller: age,
              decoration: const InputDecoration(labelText: 'Yaş grubu'),
            ),
            TextField(
              controller: category,
              decoration: const InputDecoration(labelText: 'Kategori'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
    if (save != true || name.text.trim().isEmpty) return;
    try {
      await ref.read(clubDataServiceProvider).addTeam(
            clubId,
            name.text,
            ageGroup: age.text,
            gender: category.text,
          );
      ref.invalidate(teamsProvider);
    } catch (error) {
      if (context.mounted) _snack(context, error);
    }
  }
}

class _PersonnelSettings extends ConsumerWidget {
  const _PersonnelSettings({required this.canEdit});
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(clubMembersAdminProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ProErrorState(
              message: 'Yetkili personel yüklenemedi.',
              onRetry: () => ref.invalidate(clubMembersAdminProvider),
            ),
            data: (rows) {
              final staff = rows
                  .where(
                    (row) => const {
                      'club_admin',
                      'coach',
                      'official',
                    }.contains(row.role),
                  )
                  .toList();
              if (staff.isEmpty) {
                return const ProEmptyState(
                  icon: Icons.badge_outlined,
                  title: 'Yetkili personel yok',
                  subtitle: 'Gerçek personel kayıtları burada görünür.',
                );
              }
              final adminCount = staff.where((member) => member.isAdmin).length;
              return Column(
                children: [
                  for (final member in staff)
                    ListTile(
                      leading: CircleAvatar(child: Text(member.initials)),
                      title: Text(member.name),
                      subtitle: Text(member.roleLabel),
                      trailing: canEdit && !(member.isAdmin && adminCount <= 1)
                          ? PopupMenuButton<String>(
                              onSelected: (role) =>
                                  _setRole(context, ref, member, role),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'club_admin',
                                  child: Text('Kulüp Yöneticisi'),
                                ),
                                PopupMenuItem(
                                  value: 'coach',
                                  child: Text('Antrenör'),
                                ),
                                PopupMenuItem(
                                  value: 'official',
                                  child: Text('Görevli'),
                                ),
                              ],
                            )
                          : member.isAdmin && adminCount <= 1
                              ? const Tooltip(
                                  message:
                                      'Tek kulüp yöneticisinin rolü değiştirilemez',
                                  child: Icon(Icons.lock_outline_rounded),
                                )
                              : null,
                    ),
                ],
              );
            },
          );

  Future<void> _setRole(
    BuildContext context,
    WidgetRef ref,
    ClubMember member,
    String role,
  ) async {
    if (member.role == role) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Personel rolü değiştirilsin mi?'),
        content: Text('${member.name} için yeni rol kaydedilecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(clubConfigServiceProvider)
          .setMemberRole(member.membershipId, role);
      ref.invalidate(clubMembersAdminProvider);
      ref.invalidateSwanAccess();
    } catch (error) {
      if (context.mounted) _snack(context, error);
    }
  }
}

void _snack(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(classifyOperationError(error).userMessage)),
  );
}
