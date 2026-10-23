import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/modules/console_module.dart';
import '../../app/theme/console_theme.dart';
import 'disciplinary_board_screen.dart';
import 'referee_assignments_screen.dart';

/// Federation Command Center View (1. Ekran - Gerçek Veri Bağlantılı)
/// Mock/sahte veri içermez; doğrudan `swansport_data` sağlayıcılarına bağlanır:
/// - `federationConsoleScopesProvider` (Yetkili federasyon/il kapsamları)
/// - `federationConsoleMatchesProvider` (Resmi müsabakalar & atama durumu)
/// - `federationDisciplinaryReportsProvider` (İmzalı disiplin rapor kuyruğu)
class FederationCommandCenterView extends ConsumerStatefulWidget {
  const FederationCommandCenterView({
    super.key,
    required this.access,
    required this.profile,
    required this.now,
  });

  final SwanAccess access;
  final AsyncValue<ProfileInfo?> profile;
  final DateTime now;

  @override
  ConsumerState<FederationCommandCenterView> createState() =>
      _FederationCommandCenterViewState();
}

class _FederationCommandCenterViewState
    extends ConsumerState<FederationCommandCenterView> {
  String _filter = 'all'; // all, pending, excuse
  final _searchController = TextEditingController();
  String? _selectedCity;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;

    final bgCard = isDark ? const Color(0xFF131A2B) : Colors.white;
    final bgInput = isDark ? const Color(0xFF090D15) : const Color(0xFFF1F5F9);
    final borderColor = isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
    const cyanColor = Color(0xFF06B6D4);
    const amberColor = Color(0xFFF59E0B);
    const roseColor = Color(0xFFF43F5E);
    const emeraldColor = Color(0xFF10B981);

    // 1. Gerçek Federasyon Kapsamları
    final scopesAsync = ref.watch(federationConsoleScopesProvider);
    final scopes = scopesAsync.asData?.value ?? const <FederationConsoleScope>[];

    // 2. Gerçek Resmi Müsabaka Sorgusu
    final q = FederationMatchQuery(
      cityCode: _selectedCity,
      offset: 0,
      search: _searchController.text.trim(),
    );
    final matchesAsync = ref.watch(federationConsoleMatchesProvider(q));
    final matchesPage = matchesAsync.asData?.value;
    final allMatches = matchesPage?.rows ?? const <FederationConsoleMatch>[];

    // Filtreleme (Tümü, Bekleyenler, Mazeretli)
    final filteredMatches = allMatches.where((m) {
      if (_filter == 'pending') {
        // En az 1 ataması yapılmamış veya yanıt bekleyen
        return m.officials.isEmpty || m.officials.any((o) => o.status == 'assigned');
      }
      if (_filter == 'excuse') {
        // Reddedilmiş / mazeretli görevlisi olan
        return m.officials.any((o) => o.status == 'declined');
      }
      return true;
    }).toList();

    // 3. Gerçek Disiplin Raporları Kuyruğu
    final disciplinaryAsync = ref.watch(federationDisciplinaryReportsProvider(0));
    final disciplinaryPage = disciplinaryAsync.asData?.value;
    final disciplinaryReports = disciplinaryPage?.rows ?? const <FederationDisciplinaryReport>[];

    // Sayısal özetler (Gerçek veritabanından)
    final totalMatchesCount = matchesPage?.total ?? allMatches.length;
    final pendingCount = allMatches.where((m) => m.officials.isEmpty || m.officials.any((o) => o.status == 'assigned')).length;
    final excuseCount = allMatches.where((m) => m.officials.any((o) => o.status == 'declined')).length;
    final disciplinaryCount = disciplinaryPage?.total ?? disciplinaryReports.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. ÜST FEDERASYON BAŞLIĞI
        _buildHeaderBanner(
          context,
          t,
          scopes,
          bgCard,
          bgInput,
          borderColor,
          cyanColor,
        ),
        const SizedBox(height: ConsoleDensity.lg),

        // 2. KAPSAM & FİLTRE ÇUBUĞU
        _buildContextBar(
          context,
          t,
          scopes,
          totalMatchesCount,
          pendingCount,
          excuseCount,
          bgCard,
          borderColor,
          cyanColor,
          emeraldColor,
          amberColor,
        ),
        const SizedBox(height: ConsoleDensity.xl),

        // 3. KPI KARTLARI (GERÇEK VERİLER)
        _buildKpiCards(
          scopes.length,
          totalMatchesCount,
          pendingCount,
          disciplinaryCount,
          bgCard,
          borderColor,
          cyanColor,
          amberColor,
          roseColor,
        ),
        const SizedBox(height: ConsoleDensity.xl),

        // 4. ANA İÇERİK IZGARASI (SOL %70 / SAĞ %30)
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1080;
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sol Kolon: %70 (Müsabakalar & Atama)
                  Expanded(
                    flex: 7,
                    child: _buildAssignmentTableCard(
                      context,
                      t,
                      scopes,
                      filteredMatches,
                      matchesAsync.isLoading,
                      matchesAsync.hasError,
                      totalMatchesCount,
                      pendingCount,
                      excuseCount,
                      bgCard,
                      bgInput,
                      borderColor,
                      cyanColor,
                      emeraldColor,
                      amberColor,
                      roseColor,
                    ),
                  ),
                  const SizedBox(width: ConsoleDensity.xl),
                  // Sağ Kolon: %30 (Disiplin Kuyruğu & Yetki Kapsamı)
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        _buildDisciplinaryFeedCard(
                          context,
                          t,
                          disciplinaryReports,
                          disciplinaryAsync.isLoading,
                          disciplinaryAsync.hasError,
                          disciplinaryCount,
                          bgCard,
                          bgInput,
                          borderColor,
                          cyanColor,
                          roseColor,
                          amberColor,
                        ),
                        const SizedBox(height: ConsoleDensity.lg),
                        _buildAuthorizedScopeCard(
                          t,
                          scopes,
                          bgCard,
                          bgInput,
                          borderColor,
                          cyanColor,
                          emeraldColor,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            } else {
              // Dar ekranlar için alt alta
              return Column(
                children: [
                  _buildAssignmentTableCard(
                    context,
                    t,
                    scopes,
                    filteredMatches,
                    matchesAsync.isLoading,
                    matchesAsync.hasError,
                    totalMatchesCount,
                    pendingCount,
                    excuseCount,
                    bgCard,
                    bgInput,
                    borderColor,
                    cyanColor,
                    emeraldColor,
                    amberColor,
                    roseColor,
                  ),
                  const SizedBox(height: ConsoleDensity.xl),
                  _buildDisciplinaryFeedCard(
                    context,
                    t,
                    disciplinaryReports,
                    disciplinaryAsync.isLoading,
                    disciplinaryAsync.hasError,
                    disciplinaryCount,
                    bgCard,
                    bgInput,
                    borderColor,
                    cyanColor,
                    roseColor,
                    amberColor,
                  ),
                  const SizedBox(height: ConsoleDensity.lg),
                  _buildAuthorizedScopeCard(
                    t,
                    scopes,
                    bgCard,
                    bgInput,
                    borderColor,
                    cyanColor,
                    emeraldColor,
                  ),
                ],
              );
            }
          },
        ),
      ],
    );
  }

  // --- BİLEŞENLER ---

  Widget _buildHeaderBanner(
    BuildContext context,
    ThemeData t,
    List<FederationConsoleScope> scopes,
    Color bgCard,
    Color bgInput,
    Color borderColor,
    Color cyanColor,
  ) {
    final fedName = scopes.isNotEmpty
        ? scopes.map((s) => s.name).toSet().join(' / ')
        : 'Türkiye Spor Federasyonu';

    final userRoleTitle = widget.access.isFederationPresident
        ? 'Federasyon Başkanı'
        : widget.access.isRefereeCommitteeMember
            ? 'MHK Üyesi'
            : widget.access.isDisciplinaryBoardMember
                ? 'Disiplin Kurulu'
                : 'İl Müsabaka Temsilcisi';

    final userFullName = widget.profile.valueOrNull?.fullName.isNotEmpty == true
        ? widget.profile.valueOrNull!.fullName
        : 'Federasyon Görevlisi';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ConsoleDensity.xl,
        vertical: ConsoleDensity.lg,
      ),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(ConsoleDensity.radius),
        border: Border.all(color: borderColor),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: ConsoleDensity.xl,
        runSpacing: ConsoleDensity.md,
        children: [
          // Sol: Arma & Başlık
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cyanColor.withValues(alpha: 0.25),
                      Colors.blue.shade700.withValues(alpha: 0.35),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cyanColor.withValues(alpha: 0.6)),
                ),
                child: Icon(Icons.shield_rounded, color: cyanColor, size: 24),
              ),
              const SizedBox(width: ConsoleDensity.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'TSF • MHK MERKEZİ',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: cyanColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: cyanColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: cyanColor.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'CANLI SİSTEM',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: cyanColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$fedName · Komuta Merkezi',
                    style: t.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Orta: Arama
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => setState(() {}),
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Müsabaka Kodu, Takım veya Salon Ara…',
                hintStyle: TextStyle(color: t.colorScheme.onSurface.withValues(alpha: 0.4)),
                prefixIcon: const Icon(Icons.search_rounded, size: 16),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 14),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: bgInput,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: cyanColor),
                ),
              ),
            ),
          ),

          // Sağ: Kullanıcı Rozeti & Yenileme
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: bgInput,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_outline_rounded, size: 14, color: cyanColor),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          userFullName,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          userRoleTitle,
                          style: TextStyle(
                            fontSize: 9,
                            color: cyanColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: ConsoleDensity.sm),
              IconButton(
                tooltip: 'Verileri Yenile',
                icon: const Icon(Icons.refresh_rounded, size: 18),
                onPressed: () {
                  ref.invalidate(federationConsoleScopesProvider);
                  ref.invalidate(federationConsoleMatchesProvider);
                  ref.invalidate(federationDisciplinaryReportsProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Federasyon veri akışı güncellendi.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContextBar(
    BuildContext context,
    ThemeData t,
    List<FederationConsoleScope> scopes,
    int totalCount,
    int pendingCount,
    int excuseCount,
    Color bgCard,
    Color borderColor,
    Color cyanColor,
    Color emeraldColor,
    Color amberColor,
  ) {
    final availableCities = scopes.map((s) => s.cityCode).whereType<String>().toSet();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: ConsoleDensity.xl, vertical: ConsoleDensity.md),
      decoration: BoxDecoration(
        color: bgCard.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(ConsoleDensity.radius),
        border: Border.all(color: borderColor),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: ConsoleDensity.xl,
        runSpacing: ConsoleDensity.sm,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Yetkili Branşlar: ', style: TextStyle(color: t.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: t.colorScheme.surface,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: borderColor),
                ),
                child: Text(
                  scopes.isEmpty ? 'Kapsam bekleniyor' : scopes.map((s) => s.sportCode.toUpperCase()).toSet().join(', '),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: ConsoleDensity.lg),
              Text('Müsabakalar: ', style: TextStyle(color: t.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12)),
              RichText(
                text: TextSpan(
                  style: TextStyle(color: t.colorScheme.onSurface, fontSize: 12),
                  children: [
                    TextSpan(text: '$totalCount', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const TextSpan(text: ' Toplam / '),
                    TextSpan(text: '$pendingCount', style: TextStyle(color: amberColor, fontWeight: FontWeight.bold)),
                    const TextSpan(text: ' Bekleyen / '),
                    TextSpan(text: '$excuseCount', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    const TextSpan(text: ' Mazeret'),
                  ],
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (availableCities.isNotEmpty) ...[
                DropdownButton<String?>(
                  value: _selectedCity,
                  hint: const Text('Tüm Yetkili İller', style: TextStyle(fontSize: 11)),
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Tüm Yetkili İller', style: TextStyle(fontSize: 11))),
                    for (final c in availableCities)
                      DropdownMenuItem<String?>(value: c, child: Text('İl Kodu: $c', style: const TextStyle(fontSize: 11))),
                  ],
                  onChanged: (val) => setState(() => _selectedCity = val),
                ),
                const SizedBox(width: ConsoleDensity.md),
              ],
              OutlinedButton.icon(
                icon: const Icon(Icons.sports_rounded, size: 14),
                label: const Text('Tüm Atama Matrisi', style: TextStyle(fontSize: 11)),
                onPressed: () => context.go('/mhk-atamalar'),
              ),
              const SizedBox(width: ConsoleDensity.sm),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: cyanColor.withValues(alpha: 0.2),
                  foregroundColor: cyanColor,
                  side: BorderSide(color: cyanColor.withValues(alpha: 0.5)),
                ),
                icon: const Icon(Icons.event_note_rounded, size: 15),
                label: const Text('İl Ligleri & Fikstür', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: () => context.go('/il-ligleri'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCards(
    int scopeCount,
    int matchCount,
    int pendingCount,
    int disciplinaryCount,
    Color bgCard,
    Color borderColor,
    Color cyanColor,
    Color amberColor,
    Color roseColor,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 900 ? 4 : 2;
        final w = (constraints.maxWidth - ConsoleDensity.md * (cols - 1)) / cols;

        return Wrap(
          spacing: ConsoleDensity.md,
          runSpacing: ConsoleDensity.md,
          children: [
            // KPI 1: Yetki Kapsamı
            SizedBox(
              width: w,
              child: _KpiStatCard(
                title: 'YETKİLİ FEDERASYON KAPSAMI',
                value: '$scopeCount',
                subtitle: 'aktif branş / il',
                badgeText: 'Doğrulanmış Görevler',
                tagText: 'Resmi RLS',
                icon: Icons.verified_user_outlined,
                accentColor: cyanColor,
                bgCard: bgCard,
                borderColor: borderColor,
              ),
            ),
            // KPI 2: Bekleyen Hakem Atamaları
            SizedBox(
              width: w,
              child: _KpiStatCard(
                title: 'BEKLEYEN HAKEM ATAMALARI',
                value: '$pendingCount',
                subtitle: 'müsabaka',
                badgeText: pendingCount == 0 ? 'Tüm atamalar tamamlandı' : '$pendingCount maç onay bekliyor',
                tagText: 'MHK Masası',
                icon: Icons.warning_amber_rounded,
                accentColor: amberColor,
                bgCard: bgCard,
                borderColor: pendingCount > 0 ? amberColor.withValues(alpha: 0.5) : borderColor,
              ),
            ),
            // KPI 3: Disiplin Sevkleri
            SizedBox(
              width: w,
              child: _KpiStatCard(
                title: 'DİSİPLİN SEVKLERİ & RAPORLAR',
                value: '$disciplinaryCount',
                subtitle: 'imzalı rapor',
                badgeText: disciplinaryCount == 0 ? 'İncelenecek dosya yok' : '$disciplinaryCount dosya incelemede',
                tagText: 'Kurul Kararı',
                icon: Icons.gavel_rounded,
                accentColor: roseColor,
                bgCard: bgCard,
                borderColor: disciplinaryCount > 0 ? roseColor.withValues(alpha: 0.5) : borderColor,
              ),
            ),
            // KPI 4: Toplam Resmi Müsabaka
            SizedBox(
              width: w,
              child: _KpiStatCard(
                title: 'RESMİ MÜSABAKA FİKSTÜRÜ',
                value: '$matchCount',
                subtitle: 'müsabaka',
                badgeText: 'Kayıtlı fikstürler',
                tagText: 'Fikstür',
                icon: Icons.sports_score_rounded,
                accentColor: cyanColor,
                bgCard: bgCard,
                borderColor: borderColor,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAssignmentTableCard(
    BuildContext context,
    ThemeData t,
    List<FederationConsoleScope> scopes,
    List<FederationConsoleMatch> matches,
    bool isLoading,
    bool hasError,
    int totalCount,
    int pendingCount,
    int excuseCount,
    Color bgCard,
    Color bgInput,
    Color borderColor,
    Color cyanColor,
    Color emeraldColor,
    Color amberColor,
    Color roseColor,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ConsoleDensity.radius),
        side: BorderSide(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Başlık ve Filtre Düğmeleri
          Padding(
            padding: const EdgeInsets.all(ConsoleDensity.lg),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: ConsoleDensity.md,
              runSpacing: ConsoleDensity.sm,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: cyanColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: ConsoleDensity.sm),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MHK Müsabaka Atama Çizelgesi',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Resmi veritabanı müsabakaları ve atanan hakemlerin durumları',
                          style: TextStyle(
                            fontSize: 11,
                            color: t.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Filtre Sekmeleri
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: bgInput,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _FilterPill(
                        label: 'Tüm Müsabakalar ($totalCount)',
                        selected: _filter == 'all',
                        onTap: () => setState(() => _filter = 'all'),
                        cyanColor: cyanColor,
                      ),
                      _FilterPill(
                        label: 'Bekleyenler ($pendingCount)',
                        selected: _filter == 'pending',
                        onTap: () => setState(() => _filter = 'pending'),
                        cyanColor: cyanColor,
                      ),
                      _FilterPill(
                        label: 'Mazeretliler ($excuseCount)',
                        selected: _filter == 'excuse',
                        onTap: () => setState(() => _filter = 'excuse'),
                        cyanColor: cyanColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1),

          // İçerik: Yükleniyor / Hata / Boş / Veri Tablosu
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(ConsoleDensity.xxl),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (hasError)
            Padding(
              padding: const EdgeInsets.all(ConsoleDensity.xxl),
              child: Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Müsabaka verisi alınamadı. Yeniden denemek için tıklayın.'),
                  onPressed: () => ref.invalidate(federationConsoleMatchesProvider),
                ),
              ),
            )
          else if (matches.isEmpty)
            Padding(
              padding: const EdgeInsets.all(ConsoleDensity.xxl),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inbox_outlined, size: 36, color: t.colorScheme.onSurface.withValues(alpha: 0.3)),
                    const SizedBox(height: ConsoleDensity.sm),
                    Text(
                      _searchController.text.isNotEmpty
                          ? 'Arama kriterine uygun resmi müsabaka bulunamadı.'
                          : 'Bu yetki kapsamında kayıtlı resmi müsabaka bulunmuyor.',
                      style: TextStyle(fontSize: 12, color: t.colorScheme.onSurface.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 38,
                dataRowMinHeight: 48,
                dataRowMaxHeight: 56,
                columnSpacing: 18,
                headingRowColor: WidgetStateProperty.all(bgInput),
                columns: const [
                  DataColumn(label: Text('MÜSABAKA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('BRANŞ / LİG', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('TARİH / SAAT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('TESİS / SAHA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('GÖREVLİ HAKEMLER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('DURUM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('İŞLEM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                ],
                rows: matches.map((m) {
                  final canAssign = scopes.any((s) =>
                      s.sportCode == m.sportCode &&
                      widget.access.canAssignOfficialsForFederation(s.federationId));

                  final hasDeclined = m.officials.any((o) => o.status == 'declined');
                  final hasUnassigned = m.officials.isEmpty || m.officials.any((o) => o.status == 'assigned');

                  return DataRow(
                    cells: [
                      // Müsabaka / Katılımcılar
                      DataCell(
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${m.homeName ?? 'Ev Sahibi'} — ${m.awayName ?? 'Deplasman'}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                            Text(
                              'Maç ID: ${m.id.substring(0, m.id.length > 8 ? 8 : m.id.length)}',
                              style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: cyanColor),
                            ),
                          ],
                        ),
                      ),
                      // Branş & Lig
                      DataCell(
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.sportCode.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            Text(m.program, style: TextStyle(fontSize: 10, color: t.colorScheme.onSurface.withValues(alpha: 0.6))),
                          ],
                        ),
                      ),
                      // Tarih / Saat
                      DataCell(
                        Text(
                          federationDate(m.startsAt),
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                        ),
                      ),
                      // Tesis / Salon
                      DataCell(
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.facilityName ?? m.location ?? 'Tesis belirlenmedi', style: const TextStyle(fontSize: 11)),
                            if (m.cityCode != null)
                              Text('İl: ${m.cityCode}', style: TextStyle(fontSize: 10, color: t.colorScheme.onSurface.withValues(alpha: 0.5))),
                          ],
                        ),
                      ),
                      // Görevli Hakemler
                      DataCell(
                        m.officials.isEmpty
                            ? Text('Görevli atanmadı', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: amberColor))
                            : Wrap(
                                spacing: 4,
                                children: [
                                  for (final o in m.officials)
                                    officialPill(o),
                                ],
                              ),
                      ),
                      // Durum
                      DataCell(
                        _buildRealMatchStatusBadge(m, emeraldColor, amberColor, roseColor),
                      ),
                      // İşlem Butonları (Gerçek Dialog)
                      DataCell(
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasDeclined
                                ? roseColor
                                : hasUnassigned
                                    ? cyanColor
                                    : bgInput,
                            foregroundColor: hasDeclined || hasUnassigned ? Colors.black : t.colorScheme.onSurface,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: Icon(
                            hasDeclined ? Icons.swap_horiz_rounded : Icons.person_add_rounded,
                            size: 13,
                          ),
                          label: Text(hasDeclined ? 'Yeni Ata' : canAssign ? 'Hakem Ata' : 'Detay'),
                          onPressed: () {
                            showDialog<void>(
                              context: context,
                              builder: (_) => RefereeAssignDialog(
                                key: ValueKey(m.id),
                                match: m,
                                canAssign: canAssign,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),

          const Divider(height: 1, thickness: 1),

          // Alt Bilgi
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ConsoleDensity.lg, vertical: ConsoleDensity.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Toplam $totalCount müsabakadan ${matches.length} adedi listeleniyor',
                  style: TextStyle(fontSize: 11, color: t.colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.open_in_new_rounded, size: 13),
                  label: const Text('MHK Atama Matrisini Tam Ekranda Aç', style: TextStyle(fontSize: 11)),
                  onPressed: () => context.go('/mhk-atamalar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealMatchStatusBadge(
    FederationConsoleMatch m,
    Color emeraldColor,
    Color amberColor,
    Color roseColor,
  ) {
    if (m.officials.any((o) => o.status == 'declined')) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: roseColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: roseColor.withValues(alpha: 0.4)),
        ),
        child: Text('Mazeret / Ret', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: roseColor)),
      );
    }

    if (m.officials.isEmpty || m.officials.any((o) => o.status == 'assigned')) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: amberColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: amberColor.withValues(alpha: 0.4)),
        ),
        child: Text('Onay Bekliyor', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: amberColor)),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: emeraldColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: emeraldColor.withValues(alpha: 0.4)),
      ),
      child: Text('Kabul Edildi', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: emeraldColor)),
    );
  }

  Widget _buildDisciplinaryFeedCard(
    BuildContext context,
    ThemeData t,
    List<FederationDisciplinaryReport> reports,
    bool isLoading,
    bool hasError,
    int count,
    Color bgCard,
    Color bgInput,
    Color borderColor,
    Color cyanColor,
    Color roseColor,
    Color amberColor,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ConsoleDensity.radius),
        side: BorderSide(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Başlık
          Padding(
            padding: const EdgeInsets.all(ConsoleDensity.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: roseColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DİSİPLİN KURULU & RAPOR KUYRUĞU', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        Text('İmzalı hakem raporları ve sevkler', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: roseColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: roseColor.withValues(alpha: 0.4)),
                  ),
                  child: Text('$count AKTİF RAPOR', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: roseColor)),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1),

          // Raporlar listesi
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(ConsoleDensity.lg),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (hasError)
            Padding(
              padding: const EdgeInsets.all(ConsoleDensity.lg),
              child: Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(federationDisciplinaryReportsProvider),
                  child: const Text('Raporlar alınamadı. Yenile', style: TextStyle(fontSize: 11)),
                ),
              ),
            )
          else if (reports.isEmpty)
            Padding(
              padding: const EdgeInsets.all(ConsoleDensity.xl),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.gavel_outlined, size: 28, color: t.colorScheme.onSurface.withValues(alpha: 0.3)),
                    const SizedBox(height: 6),
                    Text(
                      'İncelenmeyi bekleyen imzalı disiplin raporu yok.',
                      style: TextStyle(fontSize: 11, color: t.colorScheme.onSurface.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(ConsoleDensity.md),
              child: Column(
                children: [
                  for (final r in reports.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: ConsoleDensity.sm),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: bgInput,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${r.program} · ${r.sportCode.toUpperCase()}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                if (r.redCardAthleteIds.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: roseColor.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${r.redCardAthleteIds.length} Kırmızı Kart',
                                      style: TextStyle(fontSize: 9, color: roseColor, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              r.notes.isNotEmpty ? r.notes : 'Hakem ek notu girilmemiş.',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'İmzalandı: ${federationDate(r.signedAt)}',
                                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                                ),
                                if (r.canDecide)
                                  InkWell(
                                    onTap: () {
                                      showDialog<void>(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (_) => DisciplinaryDecisionDialog(report: r),
                                      );
                                    },
                                    child: Text(
                                      'Ceza Kararı Gir →',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cyanColor),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

          const Divider(height: 1, thickness: 1),

          // Alt Buton
          Padding(
            padding: const EdgeInsets.all(ConsoleDensity.md),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.gavel_rounded, size: 14),
                label: const Text('Disiplin Kurulunu Aç', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: () => context.go('/disiplin-kurulu'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthorizedScopeCard(
    ThemeData t,
    List<FederationConsoleScope> scopes,
    Color bgCard,
    Color bgInput,
    Color borderColor,
    Color cyanColor,
    Color emeraldColor,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ConsoleDensity.radius),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ConsoleDensity.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: emeraldColor, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    const Text('Yetkili Federasyon Görevleri', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                Text('${scopes.length} Kapsam', style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: cyanColor)),
              ],
            ),
            const SizedBox(height: ConsoleDensity.sm),

            if (scopes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Tanımlı federasyon görevi bulunamadı.', style: TextStyle(fontSize: 11, color: Colors.grey)),
              )
            else
              for (final s in scopes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: bgInput,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            Text(
                              '${s.sportCode.toUpperCase()}${s.cityCode == null ? ' · Ulusal Kapsam' : ' · İl Kodu: ${s.cityCode}'}',
                              style: const TextStyle(fontSize: 9, color: Colors.grey),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: cyanColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: cyanColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            s.role.toUpperCase(),
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: cyanColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _KpiStatCard extends StatelessWidget {
  const _KpiStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.badgeText,
    required this.tagText,
    required this.icon,
    required this.accentColor,
    required this.bgCard,
    required this.borderColor,
  });

  final String title;
  final String value;
  final String subtitle;
  final String badgeText;
  final String tagText;
  final IconData icon;
  final Color accentColor;
  final Color bgCard;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ConsoleDensity.lg),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(ConsoleDensity.radius),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, size: 16, color: accentColor),
              ),
            ],
          ),
          const SizedBox(height: ConsoleDensity.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 6),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: ConsoleDensity.md),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: ConsoleDensity.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  badgeText,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(tagText, style: TextStyle(fontSize: 9, fontFamily: 'monospace', color: accentColor)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.cyanColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color cyanColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? cyanColor.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: selected ? Border.all(color: cyanColor.withValues(alpha: 0.5)) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? cyanColor : Colors.grey,
          ),
        ),
      ),
    );
  }
}
