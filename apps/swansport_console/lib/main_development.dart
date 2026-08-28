import 'package:swansport_core/swansport_core.dart';

import 'app/console_bootstrap.dart';

/// Geliştirme girişi.
///
/// Üretimden tek farkı hangi env dosyasıyla derlendiği. Konsolda fixture modu
/// olmadığı için davranış aynı: bağlantı yoksa hata ekranı.
void main() {
  bootstrapConsole(supabaseConfig: SupabaseConfig.fromCompileTime());
}
