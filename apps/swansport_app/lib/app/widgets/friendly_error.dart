/// PostgreSQL 42501, RLS, internet kopması, zaman aşımı ve oturum hatalarını
/// kullanıcı dostu Türkçe metinlere dönüştürür.
String friendlyErrorMessage(Object? error, {String? defaultMessage}) {
  if (error == null) return defaultMessage ?? 'Beklenmedik bir sorun oluştu.';
  final str = error.toString().toLowerCase();

  // 1. Yetki ve Oturum (42501, permission denied, RLS kısıtları)
  if (str.contains('42501') ||
      str.contains('permission denied') ||
      str.contains('row-level security') ||
      str.contains('oturum gerekli') ||
      str.contains('giriş gerekli') ||
      str.contains('yetki gerekli') ||
      str.contains('insufficient_privilege')) {
    return 'Bu içeriği görüntülemek için giriş yapmanız veya yetkinizin olması gerekiyor.';
  }

  // 2. Oturum düşmesi / JWT süresi dolumu
  if (str.contains('jwt') ||
      str.contains('token expired') ||
      str.contains('unauthorized') ||
      str.contains('auth/invalid') ||
      str.contains('session_expired')) {
    return 'Oturum süreniz dolmuş olabilir. Lütfen yeniden giriş yapın.';
  }

  // 3. İnternet ve bağlantı kopmaları
  if (str.contains('socketexception') ||
      str.contains('failed host lookup') ||
      str.contains('network') ||
      str.contains('connection refused') ||
      str.contains('connection reset') ||
      str.contains('clientexception') ||
      str.contains('handshakeexception')) {
    return 'İnternet bağlantısı kurulamadı. Lütfen bağlantınızı kontrol edip tekrar deneyin.';
  }

  // 4. Zaman aşımı
  if (str.contains('timeoutexception') ||
      str.contains('timed out') ||
      str.contains('deadline exceeded')) {
    return 'Sunucu yanıt vermedi. Lütfen biraz sonra tekrar deneyin.';
  }

  // 5. Kayıt bulunamadı (404)
  if (str.contains('pgrst116') ||
      str.contains('not found') ||
      str.contains('bulunamadı')) {
    return 'Aradığınız kayıt bulunamadı veya kaldırılmış olabilir.';
  }

  // 6. Genel Supabase/PostgREST hatası
  if (str.contains('postgrestexception') || str.contains('pgrst')) {
    return 'Sunucuyla iletişim kurulurken bir sorun oluştu. Lütfen tekrar deneyin.';
  }

  return defaultMessage ?? 'Bir sorun oluştu. Lütfen tekrar deneyin.';
}
