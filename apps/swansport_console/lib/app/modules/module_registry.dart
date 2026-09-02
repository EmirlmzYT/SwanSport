import 'package:flutter/material.dart';

import '../../features/athletes/athletes_screen.dart';
import '../../features/athletes/eligibility_screen.dart';
import '../../features/schedule/attendance_screen.dart';
import '../../features/schedule/facilities_screen.dart';
import '../../features/finance/accounts_screen.dart';
import '../../features/finance/ledger_screen.dart';
import '../../features/finance/budget_screen.dart';
import '../../features/finance/collections_screen.dart';
import '../../features/finance/commitments_screen.dart';
import '../../features/finance/operations_screen.dart';
import '../../features/finance/period_close_screen.dart';
import '../../features/finance/reconciliation_screen.dart';
import '../../features/finance/report_screen.dart';
import '../../features/platform/approvals_screen.dart';
import '../../features/platform/support_screen.dart';
import '../../features/platform/feature_flags_screen.dart';
import '../../features/platform/marketplace_admin_screen.dart';
import '../../features/platform/courts_screen.dart';
import '../../features/platform/turf_fields_screen.dart';
import '../../features/platform/platform_screens.dart';
import '../../features/schedule/schedule_screen.dart';
import 'console_module.dart';

/// Konsolun tüm modülleri — tek liste.
///
/// Kenar çubuğu da yönlendirici de burayı okur. İki yerde ayrı liste tutmak,
/// menüde görünüp açılmayan (ya da tersi) modüller demekti.
///
/// Yeni modül eklemek = buraya bir satır. Yeni **kitle** eklemek de öyle:
/// `ConsoleAudience`'ta yuvası zaten var.
const List<ConsoleModule> kConsoleModules = [
  // ----------------------------------------------------------- kulüp
  ConsoleModule(
    id: 'athletes',
    label: 'Sporcular',
    icon: Icons.groups_rounded,
    route: '/sporcular',
    audience: {ConsoleAudience.clubStaff},
    builder: _athletes,
  ),
  ConsoleModule(
    id: 'eligibility',
    label: 'Uygunluk ve Risk',
    icon: Icons.health_and_safety_rounded,
    route: '/uygunluk',
    audience: {ConsoleAudience.clubStaff},
    builder: _eligibility,
  ),
  ConsoleModule(
    id: 'schedule',
    label: 'Takvim',
    icon: Icons.calendar_month_rounded,
    route: '/takvim',
    audience: {ConsoleAudience.clubStaff},
    builder: _schedule,
  ),
  ConsoleModule(
    id: 'attendance',
    label: 'Yoklama',
    icon: Icons.fact_check_rounded,
    route: '/yoklama',
    audience: {ConsoleAudience.clubStaff},
    builder: _attendance,
  ),
  ConsoleModule(
    id: 'facilities',
    label: 'Tesisler',
    icon: Icons.stadium_rounded,
    route: '/tesisler',
    audience: {ConsoleAudience.clubStaff},
    // Tesis yönetimi mobilde 4. kademeden açılıyor; konsolda da aynı eşik.
    minCoachLevel: 4,
    builder: _facilities,
  ),

  // ------------------------------------------------------------ mali
  // Hem kulüp yetkilisine hem muhasebeciye açık. İkisi aynı defteri görür;
  // fark, aidat satırlarında sporcu adının görünüp görünmemesi — o ayrım
  // veritabanındaki RPC'lerde yapılıyor, burada değil.
  ConsoleModule(
    id: 'finance_operations',
    label: 'Mali İş Kuyruğu',
    icon: Icons.playlist_add_check_rounded,
    route: '/mali-isler',
    audience: {ConsoleAudience.clubStaff, ConsoleAudience.accountant},
    builder: _financeOperations,
  ),
  ConsoleModule(
    id: 'ledger',
    label: 'Gelir–Gider',
    icon: Icons.receipt_long_rounded,
    route: '/defter',
    audience: {ConsoleAudience.clubStaff, ConsoleAudience.accountant},
    builder: _ledger,
  ),
  ConsoleModule(
    id: 'accounts',
    label: 'Kasa & Banka',
    icon: Icons.account_balance_rounded,
    route: '/kasa',
    audience: {ConsoleAudience.clubStaff, ConsoleAudience.accountant},
    builder: _accounts,
  ),
  // Mali operasyon modülleri. Hepsi hem kulüp yetkilisine hem muhasebeciye
  // açık: ikisi aynı defteri görüyor, fark sporcu adının görünüp
  // görünmemesi ve o ayrım veritabanındaki RPC'lerde yapılıyor.
  //
  // `finance_operations_center` bayrağı kapalıyken bunların hiçbiri
  // görünmüyor. Bayrak güvenlik değil — koruma RLS ve RPC'de; bayrak
  // yalnızca kademeli yayını yönetiyor.
  ConsoleModule(
    id: 'collections',
    label: 'Tahsilat',
    icon: Icons.request_quote_rounded,
    route: '/tahsilat',
    audience: {ConsoleAudience.clubStaff, ConsoleAudience.accountant},
    builder: _collections,
  ),
  ConsoleModule(
    id: 'commitments',
    label: 'Tedarikçi ve Taahhüt',
    icon: Icons.event_repeat_rounded,
    route: '/taahhutler',
    audience: {ConsoleAudience.clubStaff, ConsoleAudience.accountant},
    builder: _commitments,
  ),
  ConsoleModule(
    id: 'reconciliation',
    label: 'Banka Mutabakatı',
    icon: Icons.compare_arrows_rounded,
    route: '/mutabakat',
    audience: {ConsoleAudience.clubStaff, ConsoleAudience.accountant},
    builder: _reconciliation,
  ),
  ConsoleModule(
    id: 'budget',
    label: 'Bütçe ve Nakit',
    icon: Icons.savings_rounded,
    route: '/butce',
    audience: {ConsoleAudience.clubStaff, ConsoleAudience.accountant},
    builder: _budget,
  ),
  ConsoleModule(
    id: 'period_close',
    label: 'Dönem Kapanışı',
    icon: Icons.lock_clock_rounded,
    route: '/donem-kapanis',
    audience: {ConsoleAudience.clubStaff, ConsoleAudience.accountant},
    builder: _periodClose,
  ),
  ConsoleModule(
    id: 'report',
    label: 'Mali Rapor',
    icon: Icons.query_stats_rounded,
    route: '/mali-rapor',
    audience: {ConsoleAudience.clubStaff, ConsoleAudience.accountant},
    builder: _report,
  ),

  // -------------------------------------------------------- platform
  ConsoleModule(
    id: 'approvals',
    label: 'Onaylar',
    icon: Icons.verified_rounded,
    route: '/onaylar',
    audience: {ConsoleAudience.platformAdmin},
    builder: _approvals,
  ),
  ConsoleModule(
    id: 'users',
    label: 'Kullanıcılar',
    icon: Icons.badge_rounded,
    route: '/kullanicilar',
    audience: {ConsoleAudience.platformAdmin},
    builder: _users,
  ),
  ConsoleModule(
    id: 'moderation',
    label: 'Moderasyon',
    icon: Icons.flag_rounded,
    route: '/moderasyon',
    audience: {ConsoleAudience.platformAdmin},
    builder: _moderation,
  ),
  ConsoleModule(
    id: 'courts',
    label: 'Kortlar',
    icon: Icons.sports_tennis_rounded,
    route: '/kortlar',
    audience: {ConsoleAudience.platformAdmin},
    builder: _courts,
  ),
  ConsoleModule(
    id: 'turf_fields',
    label: 'Halı Sahalar',
    icon: Icons.grass_rounded,
    route: '/halisahalar',
    audience: {ConsoleAudience.platformAdmin},
    builder: _turfFields,
  ),
  ConsoleModule(
    id: 'marketplace',
    label: 'Pazaryeri',
    icon: Icons.storefront_rounded,
    route: '/pazaryeri',
    audience: {ConsoleAudience.platformAdmin},
    builder: _marketplace,
  ),
  ConsoleModule(
    id: 'support',
    label: 'Destek',
    icon: Icons.support_agent_rounded,
    route: '/destek',
    audience: {ConsoleAudience.platformAdmin},
    builder: _support,
  ),
  ConsoleModule(
    id: 'flags',
    label: 'Özellik bayrakları',
    icon: Icons.toggle_on_rounded,
    route: '/bayraklar',
    audience: {ConsoleAudience.platformAdmin},
    builder: _flags,
  ),
  ConsoleModule(
    id: 'metrics',
    label: 'Metrikler',
    icon: Icons.insights_rounded,
    route: '/metrikler',
    audience: {ConsoleAudience.platformAdmin},
    builder: _metrics,
  ),
];

ConsoleModule? moduleForRoute(String route) {
  for (final m in kConsoleModules) {
    if (m.route == route) return m;
  }
  return null;
}

// ------------------------------------------------------------------ ekranlar

Widget _athletes(BuildContext _) => const AthletesScreen();

Widget _eligibility(BuildContext _) => const EligibilityScreen();

Widget _support(BuildContext _) => const ConsoleSupportScreen();

Widget _schedule(BuildContext _) => const ScheduleScreen();

Widget _attendance(BuildContext _) => const AttendanceScreen();

Widget _facilities(BuildContext _) => const FacilitiesScreen();

Widget _ledger(BuildContext _) => const LedgerScreen();

Widget _financeOperations(BuildContext _) => const OperationsScreen();

Widget _collections(BuildContext _) => const CollectionsScreen();

Widget _commitments(BuildContext _) => const CommitmentsScreen();

Widget _reconciliation(BuildContext _) => const ReconciliationScreen();

Widget _budget(BuildContext _) => const BudgetScreen();

Widget _periodClose(BuildContext _) => const PeriodCloseScreen();

Widget _accounts(BuildContext _) => const AccountsScreen();

Widget _report(BuildContext _) => const ReportScreen();

Widget _approvals(BuildContext _) => const ApprovalsScreen();

Widget _users(BuildContext _) => const UsersScreen();

Widget _moderation(BuildContext _) => const ModerationScreen();

Widget _marketplace(BuildContext _) => const MarketplaceAdminScreen();
Widget _flags(BuildContext _) => const FeatureFlagsScreen();
Widget _metrics(BuildContext _) => const MetricsScreen();
Widget _courts(BuildContext _) => const ConsoleCourtsScreen();
Widget _turfFields(BuildContext _) => const ConsoleTurfFieldsScreen();
