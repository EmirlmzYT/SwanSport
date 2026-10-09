/// Pure data contract for the atomic season-opening workflow.
class SeasonSetupDraft {
  const SeasonSetupDraft({
    required this.clubId,
    required this.label,
    required this.startsOn,
    required this.endsOn,
    required this.teamName,
    this.athleteIds = const [],
    this.activate = false,
    this.scheduleUntil,
    this.weekdays = const [],
    this.hour = 18,
    this.minute = 0,
    this.duration = 90,
    this.feeName,
    this.feeAmount,
    this.dueDay = 10,
  });
  final String clubId, label, teamName;
  final DateTime startsOn, endsOn;
  final List<String> athleteIds;
  final bool activate;
  final DateTime? scheduleUntil;
  final List<int> weekdays;
  final int hour, minute, duration, dueDay;
  final String? feeName;
  final num? feeAmount;

  static DateTime dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);
  static String dateText(DateTime d) =>
      dateOnly(d).toIso8601String().split('T').first;
  int get eventCount {
    if (scheduleUntil == null) return 0;
    final first = dateOnly(startsOn), last = dateOnly(scheduleUntil!);
    if (last.isBefore(first) || last.difference(first).inDays > 90) return 0;
    var count = 0;
    for (var d = first; !d.isAfter(last); d = d.add(const Duration(days: 1))) {
      if (weekdays.contains(d.weekday)) count++;
    }
    return count;
  }

  String? validate() {
    if (label.trim().isEmpty || label.trim().length > 80) {
      return 'Sezon adı 1–80 karakter olmalı.';
    }
    final span = dateOnly(endsOn).difference(dateOnly(startsOn)).inDays;
    if (span < 0 || span > 365) {
      return 'Sezon tarihleri sıralı ve en fazla 366 gün olmalı.';
    }
    if (teamName.trim().isEmpty || teamName.trim().length > 80) {
      return 'Takım adı 1–80 karakter olmalı.';
    }
    if (athleteIds.length > 200 ||
        athleteIds.toSet().length != athleteIds.length) {
      return 'En fazla 200 farklı sporcu seçilebilir.';
    }
    if (scheduleUntil != null) {
      if (dateOnly(scheduleUntil!).isAfter(dateOnly(endsOn)) ||
          dateOnly(scheduleUntil!).difference(dateOnly(startsOn)).inDays > 90 ||
          weekdays.isEmpty ||
          weekdays.any((d) => d < 1 || d > 7) ||
          weekdays.toSet().length != weekdays.length ||
          hour < 0 ||
          hour > 23 ||
          minute < 0 ||
          minute > 59 ||
          duration < 15 ||
          duration > 240 ||
          eventCount == 0) {
        return 'Program sezon içinde, en fazla 91 gün ve en az bir antrenman olmalı.';
      }
    }
    if (feeName != null &&
        (feeName!.trim().isEmpty ||
            feeName!.trim().length > 80 ||
            feeAmount == null ||
            !feeAmount!.isFinite ||
            feeAmount! <= 0 ||
            feeAmount! > 10000000 ||
            ((feeAmount! * 100) - (feeAmount! * 100).round()).abs() >
                0.000001 ||
            dueDay < 1 ||
            dueDay > 28)) {
      return 'Aidat adı, pozitif tutarı (en fazla iki ondalık) ve 1–28 arası ödeme günü gerekli.';
    }
    return null;
  }

  Map<String, dynamic> toMap() => {
        'label': label.trim(),
        'starts_on': dateText(startsOn),
        'ends_on': dateText(endsOn),
        'team_name': teamName.trim(),
        'athlete_ids': athleteIds,
        'activate': activate,
        if (scheduleUntil != null)
          'schedule': {
            'until': dateText(scheduleUntil!),
            'weekdays': weekdays,
            'hour': hour,
            'minute': minute,
            'minutes': duration,
          },
        if (feeName != null)
          'fee': {
            'name': feeName!.trim(),
            'amount': feeAmount,
            'due_day': dueDay,
          },
      };
}

class SeasonSetupResult {
  const SeasonSetupResult({
    required this.seasonId,
    required this.teamId,
    required this.rosterCount,
    required this.eventCount,
    this.feePlanId,
  });
  final String seasonId, teamId;
  final int rosterCount, eventCount;
  final String? feePlanId;
  factory SeasonSetupResult.fromMap(Map<String, dynamic> map) =>
      SeasonSetupResult(
        seasonId: map['season_id'] as String,
        teamId: map['team_id'] as String,
        rosterCount: (map['roster_count'] as num).toInt(),
        eventCount: (map['event_count'] as num).toInt(),
        feePlanId: map['fee_plan_id'] as String?,
      );
}
