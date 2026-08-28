import 'package:flutter/material.dart';

import '../../features/athletes/athletes_screen.dart';
import '../../features/schedule/attendance_screen.dart';
import '../../features/schedule/facilities_screen.dart';
import '../../features/platform/approvals_screen.dart';
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
    audience: ConsoleAudience.clubStaff,
    builder: _athletes,
  ),
  ConsoleModule(
    id: 'schedule',
    label: 'Takvim',
    icon: Icons.calendar_month_rounded,
    route: '/takvim',
    audience: ConsoleAudience.clubStaff,
    builder: _schedule,
  ),
  ConsoleModule(
    id: 'attendance',
    label: 'Yoklama',
    icon: Icons.fact_check_rounded,
    route: '/yoklama',
    audience: ConsoleAudience.clubStaff,
    builder: _attendance,
  ),
  ConsoleModule(
    id: 'facilities',
    label: 'Tesisler',
    icon: Icons.stadium_rounded,
    route: '/tesisler',
    audience: ConsoleAudience.clubStaff,
    // Tesis yönetimi mobilde 4. kademeden açılıyor; konsolda da aynı eşik.
    minCoachLevel: 4,
    builder: _facilities,
  ),

  // -------------------------------------------------------- platform
  ConsoleModule(
    id: 'approvals',
    label: 'Onaylar',
    icon: Icons.verified_rounded,
    route: '/onaylar',
    audience: ConsoleAudience.platformAdmin,
    builder: _approvals,
  ),
  ConsoleModule(
    id: 'users',
    label: 'Kullanıcılar',
    icon: Icons.badge_rounded,
    route: '/kullanicilar',
    audience: ConsoleAudience.platformAdmin,
    builder: _users,
  ),
  ConsoleModule(
    id: 'moderation',
    label: 'Moderasyon',
    icon: Icons.flag_rounded,
    route: '/moderasyon',
    audience: ConsoleAudience.platformAdmin,
    builder: _moderation,
  ),
  ConsoleModule(
    id: 'metrics',
    label: 'Metrikler',
    icon: Icons.insights_rounded,
    route: '/metrikler',
    audience: ConsoleAudience.platformAdmin,
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

Widget _schedule(BuildContext _) => const ScheduleScreen();

Widget _attendance(BuildContext _) => const AttendanceScreen();

Widget _facilities(BuildContext _) => const FacilitiesScreen();

Widget _approvals(BuildContext _) => const ApprovalsScreen();

Widget _users(BuildContext _) => const UsersScreen();

Widget _moderation(BuildContext _) => const ModerationScreen();

Widget _metrics(BuildContext _) => const MetricsScreen();
