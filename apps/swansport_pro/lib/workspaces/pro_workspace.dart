import 'package:flutter/material.dart';
import 'package:swansport_data/swansport_data.dart';

/// SwanSport Pro bünyesinde desteklenen yetkili profesyonel çalışma alanları.
/// Sıralama sabittir ve öncelik sırasını temsil eder.
enum ProWorkspace {
  club('Kulüp'),
  coaching('Antrenörlük'),
  federation('Federasyon'),
  referee('Hakemlik'),
  accounting('Muhasebe'),
  facility('Tesis'),
  platform('Platform');

  const ProWorkspace(this.label);

  final String label;

  String get description => switch (this) {
        ProWorkspace.club => 'Takım, sporcu kadrosu ve yoklama yönetimi',
        ProWorkspace.coaching => 'Antrenman oturumları ve sporcu gelişimi',
        ProWorkspace.federation => 'Ligler, fikstür, hakem atama ve bültenler',
        ProWorkspace.referee => 'Maç görevleri, esame onayı ve canlı kokpit',
        ProWorkspace.accounting =>
          'Gelir/gider defteri, kasa, bütçe ve mutabakat',
        ProWorkspace.facility => 'Saha rezervasyonları ve tesis görevleri',
        ProWorkspace.platform => 'Sistem ayarları, planlar ve denetim logları',
      };

  IconData get icon => switch (this) {
        ProWorkspace.club => Icons.shield_outlined,
        ProWorkspace.coaching => Icons.sports_outlined,
        ProWorkspace.federation => Icons.account_balance_outlined,
        ProWorkspace.referee => Icons.sports_score_outlined,
        ProWorkspace.accounting => Icons.receipt_long_outlined,
        ProWorkspace.facility => Icons.stadium_outlined,
        ProWorkspace.platform => Icons.admin_panel_settings_outlined,
      };

  bool get supportsClubOperations =>
      this == ProWorkspace.club || this == ProWorkspace.coaching;

  bool get supportsFederationOperations => this == ProWorkspace.federation;

  bool get supportsRefereeOperations => this == ProWorkspace.referee;

  bool get supportsAccountingOperations => this == ProWorkspace.accounting;

  bool get supportsFacilityOperations => this == ProWorkspace.facility;

  bool get supportsPlatformOperations => this == ProWorkspace.platform;
}

/// SwanAccess yetki sonucunu Pro çalışma alanları listesine dönüştürür.
///
/// Yalnızca bu onaylanmış koşulları kullanır:
/// - Kulüp: hasActiveClubStaffMembership || hasOperationalClubRole
/// - Antrenörlük: coachLevel > 0 || clubRole == 'coach'
/// - Federasyon: canOpenFederationOperations
/// - Hakemlik: isReferee
/// - Muhasebe: isAccountant
/// - Tesis: canOpenTurfCenter
/// - Platform: isPlatformAdmin
///
/// Sonuç ProWorkspace enum sırasını korur ve her çalışma alanı en fazla bir kez yer alır.
List<ProWorkspace> proWorkspacesFor(SwanAccess access) {
  final workspaces = <ProWorkspace>[];

  if (access.hasActiveClubStaffMembership || access.hasOperationalClubRole) {
    workspaces.add(ProWorkspace.club);
  }

  if (access.coachLevel > 0 || access.clubRole == 'coach') {
    workspaces.add(ProWorkspace.coaching);
  }

  if (access.canOpenFederationOperations) {
    workspaces.add(ProWorkspace.federation);
  }

  if (access.isReferee) {
    workspaces.add(ProWorkspace.referee);
  }

  if (access.isAccountant) {
    workspaces.add(ProWorkspace.accounting);
  }

  if (access.canOpenTurfCenter) {
    workspaces.add(ProWorkspace.facility);
  }

  if (access.isPlatformAdmin) {
    workspaces.add(ProWorkspace.platform);
  }

  return List.unmodifiable(workspaces);
}
