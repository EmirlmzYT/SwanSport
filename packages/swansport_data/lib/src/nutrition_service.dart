import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'athlete_profile_service.dart';
import 'club_data.dart';
import 'supabase_scope.dart';

class NutritionLog {
  const NutritionLog({
    required this.id,
    required this.athleteId,
    required this.logDate,
    required this.mealType,
    required this.title,
    required this.calories,
    required this.proteinG,
    required this.carbG,
    required this.fatG,
    required this.waterMl,
    required this.createdAt,
  });

  final String id;
  final String athleteId;
  final DateTime logDate;
  final String mealType;
  final String title;
  final int calories;
  final double proteinG;
  final double carbG;
  final double fatG;
  final int waterMl;
  final DateTime createdAt;

  factory NutritionLog.fromMap(Map<String, dynamic> m) => NutritionLog(
        id: m['id'] as String,
        athleteId: m['athlete_id'] as String,
        logDate: DateTime.parse(m['log_date'].toString()),
        mealType: (m['meal_type'] as String?) ?? 'snack',
        title: (m['title'] as String?) ?? '',
        calories: (m['calories'] as num?)?.toInt() ?? 0,
        proteinG: (m['protein_g'] as num?)?.toDouble() ?? 0.0,
        carbG: (m['carb_g'] as num?)?.toDouble() ?? 0.0,
        fatG: (m['fat_g'] as num?)?.toDouble() ?? 0.0,
        waterMl: (m['water_ml'] as num?)?.toInt() ?? 0,
        createdAt: m['created_at'] != null
            ? DateTime.parse(m['created_at'].toString())
            : DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'athlete_id': athleteId,
        'log_date': logDate.toIso8601String().substring(0, 10),
        'meal_type': mealType,
        'title': title,
        'calories': calories,
        'protein_g': proteinG,
        'carb_g': carbG,
        'fat_g': fatG,
        'water_ml': waterMl,
      };
}

class DailyNutritionSummary {
  const DailyNutritionSummary({
    required this.date,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarb,
    required this.totalFat,
    required this.totalWaterMl,
    this.targetCalories = 2500,
    this.targetWaterMl = 3000,
    this.logs = const [],
  });

  final DateTime date;
  final int totalCalories;
  final double totalProtein;
  final double totalCarb;
  final double totalFat;
  final int totalWaterMl;
  final int targetCalories;
  final int targetWaterMl;
  final List<NutritionLog> logs;

  static DailyNutritionSummary empty(DateTime date) =>
      DailyNutritionSummary(
        date: date,
        totalCalories: 0,
        totalProtein: 0.0,
        totalCarb: 0.0,
        totalFat: 0.0,
        totalWaterMl: 0,
        logs: const [],
      );
}

class NutritionService {
  NutritionService(this._db);
  final SupabaseClient _db;

  Future<List<NutritionLog>> logsForDate({
    required String athleteId,
    required DateTime date,
  }) async {
    final dateStr = date.toIso8601String().substring(0, 10);
    final rows = await _db
        .from('athlete_nutrition_logs')
        .select('*')
        .eq('athlete_id', athleteId)
        .eq('log_date', dateStr)
        .order('created_at');
    return [
      for (final r in rows as List)
        NutritionLog.fromMap((r as Map).cast<String, dynamic>()),
    ];
  }

  Future<void> addMeal({
    required String athleteId,
    required DateTime date,
    required String mealType,
    required String title,
    required int calories,
    double proteinG = 0.0,
    double carbG = 0.0,
    double fatG = 0.0,
  }) async {
    final dateStr = date.toIso8601String().substring(0, 10);
    await _db.from('athlete_nutrition_logs').insert({
      'athlete_id': athleteId,
      'log_date': dateStr,
      'meal_type': mealType,
      'title': title.trim(),
      'calories': calories.clamp(0, 10000),
      'protein_g': proteinG.clamp(0.0, 1000.0),
      'carb_g': carbG.clamp(0.0, 1000.0),
      'fat_g': fatG.clamp(0.0, 1000.0),
      'water_ml': 0,
    });
  }

  Future<void> logWater({
    required String athleteId,
    required DateTime date,
    required int deltaMl,
  }) async {
    final dateStr = date.toIso8601String().substring(0, 10);
    // Varsa bugünkü water logunu güncelle veya ekle
    final existing = await _db
        .from('athlete_nutrition_logs')
        .select('id, water_ml')
        .eq('athlete_id', athleteId)
        .eq('log_date', dateStr)
        .eq('meal_type', 'water')
        .maybeSingle();

    if (existing != null) {
      final current = (existing['water_ml'] as num?)?.toInt() ?? 0;
      final nextVal = (current + deltaMl).clamp(0, 15000);
      await _db
          .from('athlete_nutrition_logs')
          .update({'water_ml': nextVal})
          .eq('id', existing['id'] as String);
    } else {
      final val = deltaMl.clamp(0, 15000);
      await _db.from('athlete_nutrition_logs').insert({
        'athlete_id': athleteId,
        'log_date': dateStr,
        'meal_type': 'water',
        'title': 'Su Tüketimi',
        'calories': 0,
        'protein_g': 0.0,
        'carb_g': 0.0,
        'fat_g': 0.0,
        'water_ml': val,
      });
    }
  }

  Future<void> deleteLog(String logId) async {
    await _db.from('athlete_nutrition_logs').delete().eq('id', logId);
  }
}

// ------------------------------ Sağlayıcılar ---------------------------------

final nutritionServiceProvider = Provider<NutritionService>((ref) {
  return NutritionService(ref.watch(supabaseClientProvider));
});

final dailyNutritionSummaryProvider = FutureProvider.autoDispose
    .family<DailyNutritionSummary, DateTime>((ref, date) async {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return DailyNutritionSummary.empty(date);
  }
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  if (profile == null) return DailyNutritionSummary.empty(date);

  final athlete = await ref.watch(athleteByProfileProvider(profile.id).future);
  if (athlete == null) return DailyNutritionSummary.empty(date);

  final logs = await ref
      .watch(nutritionServiceProvider)
      .logsForDate(athleteId: athlete.id, date: date);

  int cals = 0;
  double p = 0.0;
  double c = 0.0;
  double f = 0.0;
  int water = 0;

  for (final l in logs) {
    if (l.mealType == 'water') {
      water += l.waterMl;
    } else {
      cals += l.calories;
      p += l.proteinG;
      c += l.carbG;
      f += l.fatG;
    }
  }

  return DailyNutritionSummary(
    date: date,
    totalCalories: cals,
    totalProtein: p,
    totalCarb: c,
    totalFat: f,
    totalWaterMl: water,
    logs: logs,
  );
});