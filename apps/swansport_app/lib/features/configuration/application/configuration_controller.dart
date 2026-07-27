import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/club_configuration.dart';

class FixtureConfigurationRepository {
  final settings = <ConfigurationSetting>[
    const ConfigurationSetting(
      id: 'club_name',
      module: 'Kulüp Profili',
      category: ConfigurationCategory.operational,
      label: 'Kulüp Adı',
      value: 'Kadıköy SK',
    ),
    const ConfigurationSetting(
      id: 'club_code',
      module: 'Kulüp Profili',
      category: ConfigurationCategory.operational,
      label: 'Kısa Kod',
      value: 'KSK',
    ),
    const ConfigurationSetting(
      id: 'contact',
      module: 'Kulüp Profili',
      category: ConfigurationCategory.operational,
      label: 'İletişim, Adres, Web, Sosyal Medya ve Acil İletişim',
      value: 'info@kadikoysk.test',
    ),
    const ConfigurationSetting(
      id: 'branding',
      module: 'Markalama',
      category: ConfigurationCategory.branding,
      label: 'Ana/İkincil Renk, Açık/Koyu Tema, Baskı, Logo ve Kapak',
      value: '#008C95 / #063337',
    ),
    const ConfigurationSetting(
      id: 'branches',
      module: 'Spor Yapısı',
      category: ConfigurationCategory.sports,
      label: 'Branşlar, Yaş Kategorileri ve Yarışma Seviyeleri',
      value: '3 branş',
    ),
    const ConfigurationSetting(
      id: 'season',
      module: 'Spor Yapısı',
      category: ConfigurationCategory.sports,
      label: 'Sezonlar ve Takım Şablonları',
      value: '2025-2026',
    ),
    const ConfigurationSetting(
      id: 'training',
      module: 'Antrenman Varsayılanları',
      category: ConfigurationCategory.operational,
      label: 'Süre, Isınma, Soğuma, Yoklama, İptal ve Tekrar',
      value: '90 dk / 15 dk / 10 dk',
    ),
    const ConfigurationSetting(
      id: 'match',
      module: 'Maç Varsayılanları',
      category: ConfigurationCategory.operational,
      label: 'Süre, Tesis, Hakem, Ekipman ve Seyahat Listeleri',
      value: '40 dk',
    ),
    const ConfigurationSetting(
      id: 'notifications',
      module: 'Bildirim Ayarları',
      category: ConfigurationCategory.notifications,
      label: 'Push, E-posta, SMS, Hatırlatma ve Acil Bildirim',
      value: 'Etkin',
    ),
    const ConfigurationSetting(
      id: 'legal',
      module: 'Yasal & Uyumluluk',
      category: ConfigurationCategory.legal,
      label: 'KVKK, GDPR, Onay, Gizlilik, Koşullar ve Saklama',
      value: 'Güncel',
    ),
    const ConfigurationSetting(
      id: 'policies',
      module: 'Organizasyon Politikaları',
      category: ConfigurationCategory.operational,
      label: 'Katılım, Geç Kalma, Kayıt, Sağlık ve Sona Erme',
      value: '%80 katılım',
    ),
    const ConfigurationSetting(
      id: 'system',
      module: 'Sistem Tercihleri',
      category: ConfigurationCategory.system,
      label: 'Dil, Saat Dilimi, Tarih/Saat, Hafta ve Ölçü Birimi',
      value: 'Türkçe / Europe-Istanbul',
    ),
  ];
  final profiles = <ConfigurationProfile>[
    const ConfigurationProfile(
      id: 'profile_default',
      name: 'Varsayılan Kulüp',
      values: {'training': '90 dk / 15 dk / 10 dk'},
    ),
  ];
  final history = <ConfigurationHistoryEntry>[];
  ConfigurationHealth get health => const ConfigurationHealth(
        activeSeason: '2025-2026',
        branches: 3,
        teams: 12,
        brandingReady: true,
        notificationsHealthy: true,
        legalCompliant: true,
        score: 94,
      );
  List<ConfigurationValidation> validate() => const [
        ConfigurationValidation(
          settingId: 'contact',
          severity: ValidationSeverity.information,
          message: 'Acil iletişim telefonu eklenebilir.',
        ),
        ConfigurationValidation(
          settingId: 'legal',
          severity: ValidationSeverity.warning,
          message: 'KVKK şablonu 30 gün içinde gözden geçirilmeli.',
        ),
      ];
  void update(String id, String value) {
    final index = settings.indexWhere((s) => s.id == id);
    final old = settings[index];
    settings[index] = old.copyWith(value: value);
    history.add(
      ConfigurationHistoryEntry(
        settingId: id,
        previousValue: old.value,
        newValue: value,
        changedBy: 'Kulüp Yöneticisi',
        timestamp: DateTime(2026, 7, 23, 17),
        reason: 'Yapılandırma güncellemesi',
      ),
    );
  }
}

class ConfigurationState {
  const ConfigurationState({
    this.loading = true,
    this.settings = const [],
    this.profiles = const [],
    this.history = const [],
    this.validations = const [],
    this.query = '',
    this.category,
    required this.permissions,
    this.previewProfile,
  });
  final bool loading;
  final List<ConfigurationSetting> settings;
  final List<ConfigurationProfile> profiles;
  final List<ConfigurationHistoryEntry> history;
  final List<ConfigurationValidation> validations;
  final String query;
  final ConfigurationCategory? category;
  final ConfigurationPermissions permissions;
  final ConfigurationProfile? previewProfile;
  List<ConfigurationSetting> get filtered {
    final q = query.trim().toLowerCase();
    return settings
        .where(
          (s) =>
              (category == null || s.category == category) &&
              (q.isEmpty ||
                  '${s.module} ${s.label} ${s.category.name}'
                      .toLowerCase()
                      .contains(q)),
        )
        .toList();
  }

  ConfigurationState copyWith({
    bool? loading,
    List<ConfigurationSetting>? settings,
    List<ConfigurationProfile>? profiles,
    List<ConfigurationHistoryEntry>? history,
    List<ConfigurationValidation>? validations,
    String? query,
    ConfigurationCategory? category,
    bool clearCategory = false,
    ConfigurationProfile? previewProfile,
    bool clearPreview = false,
  }) =>
      ConfigurationState(
        loading: loading ?? this.loading,
        settings: settings ?? this.settings,
        profiles: profiles ?? this.profiles,
        history: history ?? this.history,
        validations: validations ?? this.validations,
        query: query ?? this.query,
        category: clearCategory ? null : category ?? this.category,
        permissions: permissions,
        previewProfile:
            clearPreview ? null : previewProfile ?? this.previewProfile,
      );
}

final configurationRepositoryProvider =
    Provider((ref) => FixtureConfigurationRepository());
final configurationControllerProvider = StateNotifierProvider.autoDispose<
    ConfigurationController, ConfigurationState>(
  (ref) => ConfigurationController(ref.watch(configurationRepositoryProvider)),
);

class ConfigurationController extends StateNotifier<ConfigurationState> {
  ConfigurationController(this.repository, {bool canEdit = true})
      : super(
          ConfigurationState(
            permissions:
                ConfigurationPermissions(canView: true, canEdit: canEdit),
          ),
        ) {
    load();
  }
  final FixtureConfigurationRepository repository;
  void load() => state = state.copyWith(
        loading: false,
        settings: List.of(repository.settings),
        profiles: List.of(repository.profiles),
        history: List.of(repository.history),
        validations: repository.validate(),
      );
  void search(String q) => state = state.copyWith(query: q);
  void filter(ConfigurationCategory? c) =>
      state = state.copyWith(category: c, clearCategory: c == null);
  void update(String id, String value) {
    if (!state.permissions.canEdit) return;
    repository.update(id, value);
    load();
  }

  void createProfile(String name) {
    if (!state.permissions.canEdit) return;
    repository.profiles.add(
      ConfigurationProfile(
        id: 'profile_${repository.profiles.length + 1}',
        name: name,
        values: {for (final s in repository.settings) s.id: s.value},
      ),
    );
    load();
  }

  void rename(ConfigurationProfile p, String name) {
    final i = repository.profiles.indexOf(p);
    repository.profiles[i] = p.copyWith(name: name);
    load();
  }

  void duplicate(ConfigurationProfile p) {
    repository.profiles
        .add(p.copyWith(id: '${p.id}_copy', name: '${p.name} Kopya'));
    load();
  }

  void archive(ConfigurationProfile p) {
    final i = repository.profiles.indexOf(p);
    repository.profiles[i] = p.copyWith(archived: true);
    load();
  }

  void preview(ConfigurationProfile p) =>
      state = state.copyWith(previewProfile: p);
  void apply(ConfigurationProfile p) {
    for (final e in p.values.entries) {
      if (repository.settings.any((s) => s.id == e.key)) {
        repository.update(e.key, e.value);
      }
    }
    load();
  }
}
