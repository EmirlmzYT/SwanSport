/// Honest status text derived only from measured counts. A saved attendance
/// mark is not proof that every athlete's attendance has been completed.
class ConsoleKpiStatus {
  const ConsoleKpiStatus(this.label, {this.progress});
  final String label;
  final double? progress;

  static ConsoleKpiStatus roster(int total, int active) {
    if (total < 0 || active < 0 || active > total) {
      return const ConsoleKpiStatus('Kadro sayıları kontrol edilmeli');
    }
    if (total == 0) return const ConsoleKpiStatus('Henüz kadro yok');
    final ratio = active / total;
    return ConsoleKpiStatus('%${(ratio * 100).round()} Aktif Kadro', progress: ratio);
  }

  static ConsoleKpiStatus attendance(int total, int marked) {
    if (total < 0 || marked < 0 || marked > total) {
      return const ConsoleKpiStatus('Oturum sayıları kontrol edilmeli');
    }
    if (total == 0) return const ConsoleKpiStatus('Bugün oturum yok');
    return ConsoleKpiStatus('$marked/$total oturumda kayıt', progress: marked / total);
  }

  static ConsoleKpiStatus risk(int restricted) => ConsoleKpiStatus(
      restricted == 0 ? 'Kayıtlı kısıt yok' : '$restricted uygunluk kısıtı');

  static ConsoleKpiStatus finance(int pending) => ConsoleKpiStatus(
      pending == 0 ? 'Bekleyen onay yok' : '$pending onay bekliyor');
}
