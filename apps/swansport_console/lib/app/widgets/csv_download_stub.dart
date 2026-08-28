/// Web dışı platformlar için yer tutucu.
///
/// Konsol yalnızca web'e derleniyor; bu dosya derlemeye girmiyor. Var olma
/// sebebi test: `flutter test` VM üzerinde koşuyor ve `package:web` orada
/// derlenmiyor. Koşullu import olmadan, dosya indirmeye hiç dokunmayan modül
/// görünürlüğü testleri bile yüklenemiyordu.
void saveTextFile({
  required String fileName,
  required String text,
  required String mimeType,
}) {
  throw UnsupportedError(
    'Dosya indirme yalnızca web derlemesinde çalışır.',
  );
}
