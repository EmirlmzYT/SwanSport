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
