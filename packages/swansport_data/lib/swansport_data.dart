/// SwanSport veri katmanı.
///
/// Supabase sorguları, satır modelleri ve Riverpod sağlayıcıları. Mobil
/// uygulama (`swansport_app`) ile masaüstü konsolu (`swansport_console`) bu
/// paketi paylaşır: aynı sorgu tek yerde durur, bir hata tek yerde düzelir.
///
/// Bu paket **arayüze bağlanmaz**. `IconData`, `Color`, widget ve tema burada
/// yer almaz; onlar tüketen uygulamanın sunum katmanına aittir.
library;

export 'src/sport_context_service.dart';
export 'src/club_staff_operations.dart';
export 'src/federation_console.dart';
export 'src/federation_center_service.dart';
export 'src/federation_bulletin_models.dart';
export 'src/federation_bulletin_service.dart';

// Antrenman oturumu modelleri `SessionPhase`, `SessionRhythm` ve
// `TrainingProtocolConfig` tiplerini DONDURUYOR. Bunlari yeniden
// disa vurmazsak yalnizca swansport_data'yi alan bir tuketici kendi
// aldigi degeri adlandiramaz.
export 'package:swansport_branch_engine/swansport_branch_engine.dart';

export 'src/access.dart';
export 'src/admin_service.dart';
export 'src/athlete_profile_service.dart';
export 'src/club_application_service.dart';
export 'src/club_config_service.dart';
export 'src/club_data.dart';
export 'src/club_dashboard.dart';
export 'src/club_lifecycle_service.dart';
export 'src/club_ops_service.dart';
export 'src/club_profile_service.dart';
export 'src/community_service.dart';
export 'src/court_service.dart';
export 'src/development_report.dart';
export 'src/diagnostics.dart';
export 'src/equipment_service.dart';
export 'src/expense_service.dart';
export 'src/feature_flags.dart';
export 'src/federation_records.dart';
export 'src/finance_ops_service.dart';
export 'src/finance_service.dart';
export 'src/marketplace_service.dart';
export 'src/moderation_service.dart';
export 'src/money.dart';
export 'src/network_service.dart';
export 'src/news_service.dart';
export 'src/notification_service.dart';
export 'src/nutrition_service.dart';
export 'src/offline_attendance.dart';
export 'src/operation_error.dart';
export 'src/parent_actions.dart';
export 'src/platform_mission_control.dart';
export 'src/performance_service.dart';
export 'src/saha_operations.dart';
export 'src/season_setup.dart';
export 'src/social_service.dart';
export 'src/social_share_service.dart';
export 'src/sports_catalog.dart';
export 'src/sports_roles_models.dart';
export 'src/sports_roles_service.dart';
export 'src/referee_cockpit.dart';
export 'src/supabase_athletes.dart';
export 'src/swan_experience.dart';
export 'src/supabase_scope.dart';
export 'src/training_session_service.dart';
export 'src/training_cockpit.dart';
export 'src/turf_service.dart';
export 'src/vault_service.dart';
export 'src/verification_service.dart';
export 'src/public_program_service.dart';
export 'src/unified_calendar.dart';
export 'src/coach_guardian_results.dart';
export 'src/live_match_models.dart';
export 'src/live_match_service.dart';
export 'src/league_standings_models.dart';
export 'src/league_standings_service.dart';
export 'src/match_following_models.dart';
export 'src/match_following_service.dart';
export 'src/local_test_accounts.dart';
