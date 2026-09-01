/// SwanSport veri katmanı.
///
/// Supabase sorguları, satır modelleri ve Riverpod sağlayıcıları. Mobil
/// uygulama (`swansport_app`) ile masaüstü konsolu (`swansport_console`) bu
/// paketi paylaşır: aynı sorgu tek yerde durur, bir hata tek yerde düzelir.
///
/// Bu paket **arayüze bağlanmaz**. `IconData`, `Color`, widget ve tema burada
/// yer almaz; onlar tüketen uygulamanın sunum katmanına aittir.
library;

export 'src/access.dart';
export 'src/admin_service.dart';
export 'src/athlete_profile_service.dart';
export 'src/club_application_service.dart';
export 'src/club_config_service.dart';
export 'src/club_data.dart';
export 'src/club_ops_service.dart';
export 'src/club_profile_service.dart';
export 'src/community_service.dart';
export 'src/court_service.dart';
export 'src/feature_flags.dart';
export 'src/marketplace_service.dart';
export 'src/expense_service.dart';
export 'src/finance_service.dart';
export 'src/moderation_service.dart';
export 'src/money.dart';
export 'src/network_service.dart';
export 'src/news_service.dart';
export 'src/notification_service.dart';
export 'src/performance_service.dart';
export 'src/social_service.dart';
export 'src/supabase_athletes.dart';
export 'src/supabase_scope.dart';
export 'src/turf_service.dart';
export 'src/vault_service.dart';
export 'src/verification_service.dart';
