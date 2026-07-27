import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/reports_models.dart';

class ReportsState {
  const ReportsState({
    required this.kpis,
    required this.templates,
    required this.alerts,
    this.selectedCategory,
    this.searchQuery = '',
    this.isLoading = false,
    this.metrics = const [],
    this.commentary = const [],
    this.decisions = const [],
    this.audit = const [],
    this.savedViews = const [],
  });

  final ExecutiveKpi kpis;
  final List<ReportTemplate> templates;
  final List<AnomalyAlert> alerts;
  final ReportDomainCategory? selectedCategory;
  final String searchQuery;
  final bool isLoading;
  final List<MetricDefinition> metrics;
  final List<InsightCommentary> commentary;
  final List<DecisionRecord> decisions;
  final List<ReportAuditEntry> audit;
  final List<SavedReportView> savedViews;

  List<ReportTemplate> get filteredTemplates {
    return templates.where((t) {
      final matchesCategory =
          selectedCategory == null || t.category == selectedCategory;
      final matchesSearch = searchQuery.isEmpty ||
          t.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
          t.description.toLowerCase().contains(searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  ReportsState copyWith({
    ExecutiveKpi? kpis,
    List<ReportTemplate>? templates,
    List<AnomalyAlert>? alerts,
    ReportDomainCategory? selectedCategory,
    bool clearCategory = false,
    String? searchQuery,
    bool? isLoading,
    List<MetricDefinition>? metrics,
    List<InsightCommentary>? commentary,
    List<DecisionRecord>? decisions,
    List<ReportAuditEntry>? audit,
    List<SavedReportView>? savedViews,
  }) {
    return ReportsState(
      kpis: kpis ?? this.kpis,
      templates: templates ?? this.templates,
      alerts: alerts ?? this.alerts,
      selectedCategory:
          clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      metrics: metrics ?? this.metrics,
      commentary: commentary ?? this.commentary,
      decisions: decisions ?? this.decisions,
      audit: audit ?? this.audit,
      savedViews: savedViews ?? this.savedViews,
    );
  }
}

class ReportsNotifier extends StateNotifier<ReportsState> {
  ReportsNotifier()
      : super(
          ReportsState(
            kpis: const ExecutiveKpi(
              totalActiveAthletes: 124,
              athleteGrowthPercentage: 4.2,
              overallAttendanceRate: 88.5,
              trainingCompletionRate: 94.0,
              facilityOccupancyRate: 78.0,
              medicalComplianceScore: 92.0,
              activeInjuriesCount: 3,
              clubHealthScore: 96,
            ),
            templates: [
              const ReportTemplate(
                id: 'rep-01',
                title: 'Kulüp Geneli Operasyonel Sağlık Raporu',
                description:
                    'Tüm şubeler, yoklama oranları ve idari uyum kartları.',
                category: ReportDomainCategory.executive,
                requiredRole: 'Kulüp Yöneticisi',
                lastGenerated: 'Bugün 14:30',
                isFavorite: true,
                isScheduled: true,
              ),
              const ReportTemplate(
                id: 'rep-02',
                title: 'Sporcu Demografisi & Retention Analizi',
                description:
                    'Yaş grupları dağılımı, devamlılık ve ayrılma oranları.',
                category: ReportDomainCategory.athlete,
                requiredRole: 'Şube Sorumlusu',
                lastGenerated: 'Dün 18:00',
                isFavorite: true,
              ),
              const ReportTemplate(
                id: 'rep-03',
                title: 'Tesis & Salon Doluluk Heatmap',
                description:
                    'Caferağa ve kuzey kampüs sahalarının yoğunluk saatleri.',
                category: ReportDomainCategory.facility,
                requiredRole: 'Tesis Yöneticisi',
                lastGenerated: '22 Temmuz',
                isScheduled: true,
              ),
              const ReportTemplate(
                id: 'rep-04',
                title: 'Tıbbi Uygunluk & Sakatlık Raporu (Anonim)',
                description:
                    'Sakatlık bölgeleri dağılımı ve EK-1 rapor süreleri.',
                category: ReportDomainCategory.medical,
                requiredRole: 'Sağlık Ekibi',
                lastGenerated: 'Bugün 09:15',
                isFavorite: true,
              ),
              const ReportTemplate(
                id: 'rep-05',
                title: 'İletişim & Duyuru Okunma Performansı',
                description: 'Veli duyuruları teslimat ve okunma oranları.',
                category: ReportDomainCategory.communication,
                requiredRole: 'Kulüp Yöneticisi',
                lastGenerated: '21 Temmuz',
              ),
            ],
            alerts: [
              const AnomalyAlert(
                id: 'alt-01',
                title: 'Cuma Akşamı Yoklama Düşüşü',
                description:
                    'U16 Basketbol takımında Cuma 18:30 seansında %18 yoklama kaybı.',
                severity: AlertSeverity.warning,
                timestamp: 'Bugün 15:10',
                affectedDomain: 'Attendance',
              ),
              const AnomalyAlert(
                id: 'alt-02',
                title: 'Saha Bakım Gecikmesi',
                description:
                    'Caferağa Fitness Alanı bakım iş emri 14 günü aştı.',
                severity: AlertSeverity.critical,
                timestamp: 'Dün 11:20',
                affectedDomain: 'Facility',
              ),
            ],
            metrics: [
              MetricDefinition(
                key: 'attendance_rate',
                name: 'Katılım Oranı',
                description: 'Katılınan seansların planlanan seanslara oranı.',
                calculation: 'katılım / planlanan × 100',
                source: 'Attendance',
                unit: '%',
                owner: 'Operasyon Analitiği',
                state: MetricDefinitionState.certified,
                version: '2.1',
                effectiveDate: DateTime(2026, 1, 1),
              ),
              MetricDefinition(
                key: 'facility_occupancy',
                name: 'Tesis Doluluk Oranı',
                description:
                    'Rezerve edilen sürenin kullanılabilir süreye oranı.',
                calculation: 'rezerve dakika / açık dakika × 100',
                source: 'Facilities',
                unit: '%',
                owner: 'Tesis Operasyonları',
                state: MetricDefinitionState.certified,
                version: '1.0',
                effectiveDate: DateTime(2026, 1, 1),
              ),
            ],
            commentary: [
              InsightCommentary(
                author: 'Selin Yılmaz',
                role: 'Yönetici',
                text: 'Cuma katılım düşüşü insan yorumu olarak incelenmelidir.',
                timestamp: DateTime(2026, 7, 24, 11),
              ),
            ],
            decisions: [
              DecisionRecord(
                title: 'Cuma seans saatini değerlendir',
                owner: 'Ahmet Koç',
                reason: 'Katılım düşüşü',
                action: 'Takım geri bildirimi topla',
                dueDate: DateTime(2026, 7, 31),
                status: DecisionStatus.inProgress,
              ),
            ],
            audit: [
              ReportAuditEntry(
                actor: 'BI Ekibi',
                role: 'Report Designer',
                action: 'Rapor üretildi',
                reportId: 'rep-01',
                timestamp: DateTime(2026, 7, 24, 14, 30),
                previousValue: 'Taslak',
                newValue: 'Generated',
              ),
            ],
            savedViews: [
              const SavedReportView(
                id: 'view_exec',
                name: 'Yönetici Varsayılanı',
                reportId: 'rep-01',
                isDefault: true,
              ),
            ],
          ),
        );

  ReportsState get current => state;

  void selectCategory(ReportDomainCategory? category) {
    if (category == null || category == state.selectedCategory) {
      state = state.copyWith(clearCategory: true);
    } else {
      state = state.copyWith(selectedCategory: category);
    }
  }

  void updateSearch(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void toggleFavorite(String reportId) {
    final updated = state.templates.map((t) {
      if (t.id == reportId) {
        return ReportTemplate(
          id: t.id,
          title: t.title,
          description: t.description,
          category: t.category,
          requiredRole: t.requiredRole,
          lastGenerated: t.lastGenerated,
          isFavorite: !t.isFavorite,
          isScheduled: t.isScheduled,
          certification: t.certification,
          freshness: t.freshness,
          owner: t.owner,
          sourceModules: t.sourceModules,
        );
      }
      return t;
    }).toList();

    state = state.copyWith(templates: updated);
  }

  void addCommentary(String text) {
    if (text.trim().isEmpty) return;
    state = state.copyWith(
      commentary: [
        ...state.commentary,
        InsightCommentary(
          author: 'Mevcut Kullanıcı',
          role: 'Analist',
          text: text.trim(),
          timestamp: DateTime(2026, 7, 24, 16),
        ),
      ],
    );
  }

  void addDecision(String title) {
    if (title.trim().isEmpty) return;
    state = state.copyWith(
      decisions: [
        ...state.decisions,
        DecisionRecord(
          title: title.trim(),
          owner: 'Mevcut Kullanıcı',
          reason: 'Rapor değerlendirmesi',
          action: 'Takip et',
          dueDate: DateTime(2026, 8, 1),
          status: DecisionStatus.proposed,
        ),
      ],
    );
  }

  void saveView(String reportId, String name) => state = state.copyWith(
        savedViews: [
          ...state.savedViews,
          SavedReportView(
            id: 'view_${state.savedViews.length + 1}',
            name: name,
            reportId: reportId,
          ),
        ],
      );
}

final reportsControllerProvider =
    StateNotifierProvider<ReportsNotifier, ReportsState>((ref) {
  return ReportsNotifier();
});
