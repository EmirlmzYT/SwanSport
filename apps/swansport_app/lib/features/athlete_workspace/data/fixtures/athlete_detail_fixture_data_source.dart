import 'package:swansport_models/swansport_models.dart';

import '../../domain/models/athlete_detail.dart';

class AthleteDetailFixtureDataSource {
  const AthleteDetailFixtureDataSource();

  AthleteDetail? findById(SwanId athleteId) => _fixtures[athleteId.value];

  static final Map<String, AthleteDetail> _fixtures = {
    'athlete_can_yilmaz': _buildFixture(
      id: 'athlete_can_yilmaz',
      name: 'Can Yılmaz',
      initials: 'CY',
      jersey: '#10',
      position: 'Point Guard',
      licenseNumber: 'TR-2026-8842',
      guardianName: 'Mehmet Yılmaz',
      statusLabel: 'Lisans Aktif',
      rateLabel: '%94',
      scoreLabel: '8.8',
    ),
    'athlete_efe_kaya': _buildFixture(
      id: 'athlete_efe_kaya',
      name: 'Efe Kaya',
      initials: 'EK',
      jersey: '#07',
      position: 'Shooting Guard',
      licenseNumber: 'TR-2026-9018',
      guardianName: 'Selin Kaya',
      statusLabel: 'Eksik Evrak',
      rateLabel: '%81',
      scoreLabel: '7.9',
    ),
    'athlete_arda_sen': _buildFixture(
      id: 'athlete_arda_sen',
      name: 'Arda Şen',
      initials: 'AŞ',
      jersey: '#12',
      position: 'Forward',
      licenseNumber: 'TR-2026-7751',
      guardianName: 'Murat Şen',
      statusLabel: 'Lisans Aktif',
      rateLabel: '%91',
      scoreLabel: '8.4',
    ),
  };

  static AthleteDetail _buildFixture({
    required String id,
    required String name,
    required String initials,
    required String jersey,
    required String position,
    required String licenseNumber,
    required String guardianName,
    required String statusLabel,
    required String rateLabel,
    required String scoreLabel,
  }) {
    return AthleteDetail(
      profile: AthleteProfile(
        athlete: Athlete(
          id: SwanId(id),
          displayName: name,
          statusLabel: statusLabel,
        ),
        initials: initials,
        position: position,
        birthDateLabel: '14.05.2010',
        licenseNumber: licenseNumber,
        jerseyNumber: jersey,
        teamName: 'U-16 Erkek',
        seasonLabel: '2025-2026 Sezonu',
      ),
      guardian: GuardianSummary(
        displayName: guardianName,
        relationship: 'Veli',
        canContact: true,
      ),
      membership: TeamMembership(
        teamId: const SwanId('team_u16_male'),
        teamName: 'U-16 Erkek Basketbol',
        seasonId: const SwanId('season_2025_2026'),
        seasonLabel: '2025-2026 Sezonu',
        jerseyNumber: jersey,
      ),
      season: const SeasonContext(
        seasonId: SwanId('season_2025_2026'),
        label: '2025-2026 Sezonu',
        isActive: true,
      ),
      attendance: AttendanceSummary(
        rateLabel: rateLabel,
        scoreLabel: scoreLabel,
        scoreUnit: '/10',
        recentItems: const [
          AttendanceHistoryItem(
            dateLabel: '22 Temmuz 2026',
            sessionLabel: 'Antrenman  •  Caferağa Spor Salonu',
            statusLabel: 'Katıldı',
          ),
          AttendanceHistoryItem(
            dateLabel: '20 Temmuz 2026',
            sessionLabel: 'Taktik Şut  •  Caferağa Spor Salonu',
            statusLabel: 'Katıldı',
          ),
          AttendanceHistoryItem(
            dateLabel: '18 Temmuz 2026',
            sessionLabel: 'Kuvvet Antrenmanı  •  Salon B',
            statusLabel: 'Mazeretli',
          ),
        ],
      ),
      medical: const MedicalRestrictionSummary(
        status: MedicalRestrictionStatus.clear,
        title: 'Sağlık Raporu Geçerli',
        summary: 'Son Geçerlilik: 15 Kasım 2026  •  🔒 Veli İzin Belgesi Tam',
      ),
      documents: const [
        AthleteDocumentSummary(
          id: SwanId('doc_guardian_consent'),
          title: 'Veli İzin Muvafakatnamesi',
          statusLabel: 'Onaylı',
        ),
        AthleteDocumentSummary(
          id: SwanId('doc_license'),
          title: 'Sporcu Lisans Belgesi (2025-26)',
          statusLabel: 'Aktif',
        ),
        AthleteDocumentSummary(
          id: SwanId('doc_medical'),
          title: 'Sağlık Raporu & EK-1 Belgesi',
          statusLabel: 'Geçerli',
        ),
      ],
      notes: const [
        CoachNote(
          id: SwanId('note_1'),
          authorName: 'Ahmet Koç (Başantrenör)',
          dateLabel: '18 Temmuz 2026',
          body:
              'Bilek burkulması sonrası fizik tedavi süreci iyi geçti. Tam tempo antrenmana hazır.',
        ),
        CoachNote(
          id: SwanId('note_2'),
          authorName: 'Ahmet Koç (Başantrenör)',
          dateLabel: '10 Temmuz 2026',
          body:
              'Savunma ribaundlarında pozisyon alması geliştirilmeli. Bireysel çalışma yazıldı.',
        ),
      ],
      timeline: [
        AthleteTimelineEntry(
          id: SwanId('timeline_${id}_1'),
          type: AthleteTimelineEntryType.attendance,
          timeLabel: 'Bugün 17:30',
          title: '🟢 Antrenmana Katıldı',
          summary: 'Caferağa Spor Salonu • Yoklama Kaydı',
        ),
        AthleteTimelineEntry(
          id: SwanId('timeline_${id}_2'),
          type: AthleteTimelineEntryType.document,
          timeLabel: '20 Temmuz 18:00',
          title: '📄 Veli Muvafakatnamesi Onaylandı',
          summary: 'Veli: $guardianName • Dijital İmza',
        ),
        AthleteTimelineEntry(
          id: SwanId('timeline_${id}_3'),
          type: AthleteTimelineEntryType.note,
          timeLabel: '18 Temmuz 19:15',
          title: '📝 Antrenör Notu Eklendi',
          summary: 'Ahmet Koç: "Şut yüzdesi son 3 antrenmandır artışta."',
        ),
        AthleteTimelineEntry(
          id: SwanId('timeline_${id}_4'),
          type: AthleteTimelineEntryType.medical,
          timeLabel: '15 Temmuz 11:00',
          title: '🩺 Sağlık Raporu Yenilendi',
          summary: 'Geçerlilik tarihi 15.11.2026 olarak güncellendi.',
        ),
      ],
      lastSyncedLabel: 'Az önce',
    );
  }
}
