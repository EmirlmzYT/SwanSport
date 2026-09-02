import '../scoring/score_rules.dart';

/// Bir antrenman protokolünün yapılandırması.
///
/// MOTOR BRANŞA DEĞİL PROTOKOLE BAKIYOR. Alan adları bilerek branştan
/// bağımsız: okçulukta `unit` = ok, yüzmede kulvar tekrarı, atletizmde
/// deneme. Yeni branş eklemek yeni tablo değil yeni [config] demek.
///
/// Sunucudaki `valid_training_config` (0071) aynı sınırları şemada zorluyor;
/// bu sınıf onun istemci karşılığı ve yalnızca **okuma** yapıyor.
class TrainingProtocolConfig {
  const TrainingProtocolConfig({
    required this.setCount,
    required this.unitsPerSet,
    required this.prepSeconds,
    required this.shootSeconds,
    required this.collectSeconds,
    required this.restSeconds,
    required this.maxUnitScore,
    required this.entryMode,
    required this.mode,
  });

  /// Sunucudan gelen jsonb.
  ///
  /// Eksik alanda **çökmüyor**, güvenli varsayılana düşüyor: şema geçerli
  /// yapılandırmayı zaten garanti ediyor, ama bir gün bir alan eklenirse
  /// eski istemci beyaz ekran göstermemeli.
  factory TrainingProtocolConfig.fromMap(Map<String, Object?> m) {
    int i(String k, int fallback) {
      final v = m[k];
      return v is num ? v.toInt() : fallback;
    }

    num n(String k, num fallback) {
      final v = m[k];
      return v is num ? v : fallback;
    }

    return TrainingProtocolConfig(
      setCount: i('set_count', 1),
      unitsPerSet: i('units_per_set', 1),
      prepSeconds: i('prep_seconds', 0),
      shootSeconds: i('shoot_seconds', 0),
      collectSeconds: i('collect_seconds', 0),
      restSeconds: i('rest_seconds', 0),
      maxUnitScore: n('max_unit_score', 10),
      entryMode: ScoreEntryMode.parse(m['entry_mode'] as String?),
      mode: TrainingMode.parse(m['mode'] as String?),
    );
  }

  final int setCount;
  final int unitsPerSet;
  final int prepSeconds;
  final int shootSeconds;
  final int collectSeconds;
  final int restSeconds;
  final num maxUnitScore;
  final ScoreEntryMode entryMode;
  final TrainingMode mode;

  /// Aşama makinesine verilecek biçim.
  Map<String, Object?> toMap() => {
        'set_count': setCount,
        'units_per_set': unitsPerSet,
        'prep_seconds': prepSeconds,
        'shoot_seconds': shootSeconds,
        'collect_seconds': collectSeconds,
        'rest_seconds': restSeconds,
        'max_unit_score': maxUnitScore,
        'entry_mode': entryMode.name,
        'mode': mode.name,
      };

  /// Hedeflenen toplam atış — antrenör sonuç ekranındaki "kaydedilen /
  /// hedeflenen" karşılaştırmasının paydası.
  int get plannedUnits => setCount * unitsPerSet;

  /// Bir setten alınabilecek en yüksek puan.
  num get maxSetScore => unitsPerSet * maxUnitScore;

  /// Dinlenme aşaması var mı. 0 saniyeyse aşama hiç gösterilmiyor.
  bool get hasRest => restSeconds > 0;

  /// Ok toplama aşaması var mı.
  bool get hasCollect => collectSeconds > 0;
}

/// Antrenmanın amacı. Sonuç ekranı bunu okuyup uyarıları yumuşatıyor:
/// teknik çalışmada düşük puan bir sorun değil.
enum TrainingMode {
  technique,
  scored,
  simulation;

  static TrainingMode parse(String? raw) => switch (raw) {
        'scored' => TrainingMode.scored,
        'simulation' => TrainingMode.simulation,
        _ => TrainingMode.technique,
      };

  String get label => switch (this) {
        TrainingMode.technique => 'Teknik',
        TrainingMode.scored => 'Puanlı',
        TrainingMode.simulation => 'Müsabaka',
      };

  /// Puan bu modda anlamlı mı — teknik çalışmada skor ikincil.
  bool get scoreMatters => this != TrainingMode.technique;
}

/// Oturumun ritmi.
enum SessionRhythm {
  /// Antrenör aşamaları başlatır; herkes aynı sayaçla ilerler.
  shared,

  /// Sporcu kendi setini ve sayacını kendi başlatır.
  individual,

  /// Antrenör genel aşamayı başlatır; sporcu kendi set sonucunu tamamlar.
  mixed;

  static SessionRhythm parse(String? raw) => switch (raw) {
        'individual' => SessionRhythm.individual,
        'mixed' => SessionRhythm.mixed,
        _ => SessionRhythm.shared,
      };

  String get label => switch (this) {
        SessionRhythm.shared => 'Ortak ritim',
        SessionRhythm.individual => 'Kişisel ritim',
        SessionRhythm.mixed => 'Karma ritim',
      };

  /// Sporcu aşamayı kendi ilerletebiliyor mu.
  bool get athleteControlsPhase => this == SessionRhythm.individual;
}
