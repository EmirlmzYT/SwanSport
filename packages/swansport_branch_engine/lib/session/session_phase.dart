/// Antrenman oturumunun aşamaları.
///
/// SUNUCU TEK OTORİTE. Buradaki [nextPhase] yalnızca "sıradaki: Ok Toplama"
/// önizlemesi için; gerçek geçişi `advance_session_phase` (0072) yapıyor.
/// Ekran her zaman sunucudan gelen `current_phase` değerini çiziyor.
///
/// Bu ayrım önemli: iki tarafta iki ayrı otorite olsaydı, biri diğerinden
/// kayar ve sporcunun ekranı antrenörün ekranından farklı aşama gösterirdi.
library;

enum SessionPhase {
  /// Hazırlık/bekleme — sayaç değil, "başla" kapısı.
  prep,

  /// Atış.
  shoot,

  /// Ok toplama.
  collect,

  /// Skor girişi — bilerek süresiz.
  score,

  /// Setler arası dinlenme.
  rest,

  /// Oturum bitti.
  done;

  /// Sunucudaki metin değerinden okuma. Tanınmayan değer [done] değil
  /// [prep] veriyor: bilinmeyen bir aşamada oturumu "bitmiş" saymak,
  /// sporcunun ekranını sessizce kapatırdı.
  static SessionPhase parse(String? raw) {
    for (final p in SessionPhase.values) {
      if (p.name == raw) return p;
    }
    return SessionPhase.prep;
  }

  String get label => switch (this) {
        SessionPhase.prep => 'Hazırlık',
        SessionPhase.shoot => 'Atış',
        SessionPhase.collect => 'Ok toplama',
        SessionPhase.score => 'Skor girişi',
        SessionPhase.rest => 'Dinlenme',
        SessionPhase.done => 'Tamamlandı',
      };

  /// Sporcunun o an ne yapması gerektiği. Aşama adından daha yönlendirici.
  String get hint => switch (this) {
        SessionPhase.prep => 'Yerini al, antrenörün başlatmasını bekle',
        SessionPhase.shoot => 'Setini at',
        SessionPhase.collect => 'Oklarını topla',
        SessionPhase.score => 'Bu setin puanını gir',
        SessionPhase.rest => 'Dinlen, sonraki set birazdan',
        SessionPhase.done => 'Oturum tamamlandı',
      };

  /// Skor girişi bu aşamada açık mı.
  bool get acceptsScore =>
      this == SessionPhase.score || this == SessionPhase.rest;
}

/// Bir aşamanın kaç saniye sürdüğü. [SessionPhase.score] ve
/// [SessionPhase.done] için `null` — süresiz.
///
/// `training_phase_seconds` (0072) ile aynı tablo.
int? phaseSeconds(SessionPhase phase, Map<String, Object?> config) {
  final key = switch (phase) {
    SessionPhase.prep => 'prep_seconds',
    SessionPhase.shoot => 'shoot_seconds',
    SessionPhase.collect => 'collect_seconds',
    SessionPhase.rest => 'rest_seconds',
    SessionPhase.score || SessionPhase.done => null,
  };
  if (key == null) return null;
  final raw = config[key];
  return raw is num ? raw.toInt() : null;
}

/// Aşama geçişinin sonucu: sıradaki aşama ve o aşamanın ait olduğu set.
class PhaseStep {
  const PhaseStep(this.phase, this.setNo);

  final SessionPhase phase;
  final int setNo;

  @override
  bool operator ==(Object other) =>
      other is PhaseStep && other.phase == phase && other.setNo == setNo;

  @override
  int get hashCode => Object.hash(phase, setNo);

  @override
  String toString() => 'PhaseStep(${phase.name}, $setNo)';
}

/// Sıradaki aşamanın **önizlemesi**. `training_next_phase` (0072) ile aynı
/// tablo — testleri iki tarafı da aynı örneklerle sınıyor.
///
/// Süresi 0 olan `collect` ve `rest` atlanıyor: sıfır saniyelik bir aşama
/// ekranda bir kare titreyip geçen bir adım demek.
PhaseStep nextPhase(
  SessionPhase phase,
  int setNo,
  Map<String, Object?> config,
) {
  int intOf(String key, int fallback) {
    final v = config[key];
    return v is num ? v.toInt() : fallback;
  }

  final setCount = intOf('set_count', 1);
  final collect = intOf('collect_seconds', 0);
  final rest = intOf('rest_seconds', 0);

  return switch (phase) {
    SessionPhase.prep => PhaseStep(SessionPhase.shoot, setNo),
    SessionPhase.shoot => collect > 0
        ? PhaseStep(SessionPhase.collect, setNo)
        : PhaseStep(SessionPhase.score, setNo),
    SessionPhase.collect => PhaseStep(SessionPhase.score, setNo),
    SessionPhase.score => setNo >= setCount
        ? PhaseStep(SessionPhase.done, setNo)
        : rest > 0
            ? PhaseStep(SessionPhase.rest, setNo)
            : PhaseStep(SessionPhase.prep, setNo + 1),
    SessionPhase.rest => PhaseStep(SessionPhase.prep, setNo + 1),
    SessionPhase.done => PhaseStep(SessionPhase.done, setNo),
  };
}

/// Sayacın kalan süresi.
///
/// NEDEN ZAMAN DAMGASINDAN: geri sayan bir sayıcı tutsaydık uygulama arka
/// plana gidip geldiğinde yanlış devam ederdi — bu, sahada en sık görülen
/// kronometre hatası. İki zaman damgası arasındaki fark yanlış devam etmez.
///
/// Duraklatılmış oturumda [pausedAt] doluyken kalan süre donuyor.
Duration? remaining({
  required DateTime? endsAt,
  required DateTime now,
  DateTime? pausedAt,
}) {
  if (endsAt == null) return null;
  final reference = pausedAt ?? now;
  final left = endsAt.difference(reference);
  return left.isNegative ? Duration.zero : left;
}

/// Süre doldu mu. Dolduğunda sistem **kendiliğinden ilerlemiyor**; ekran
/// "süre doldu" deyip kararı insana bırakıyor.
bool phaseExpired({
  required DateTime? endsAt,
  required DateTime now,
  DateTime? pausedAt,
}) {
  if (endsAt == null) return false;
  if (pausedAt != null) return !endsAt.isAfter(pausedAt);
  return !endsAt.isAfter(now);
}

/// `04:35` biçimi. Saat gerekmiyor — en uzun aşama 3600 saniye.
String formatRemaining(Duration d) {
  final total = d.inSeconds;
  final m = (total ~/ 60).toString().padLeft(2, '0');
  final s = (total % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
