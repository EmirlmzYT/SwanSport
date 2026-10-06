import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'athlete_profile_service.dart';
import 'club_data.dart';
import 'supabase_scope.dart';

class AthleteEquipment {
  const AthleteEquipment({
    required this.id,
    required this.athleteId,
    this.clubId,
    required this.name,
    required this.category,
    this.brandModel,
    this.serialNo,
    this.tuningParams = const {},
    this.status = 'active',
    this.lastServicedAt,
    this.notes,
    required this.createdAt,
  });

  final String id;
  final String athleteId;
  final String? clubId;
  final String name;
  final String category;
  final String? brandModel;
  final String? serialNo;
  final Map<String, dynamic> tuningParams;
  final String status;
  final DateTime? lastServicedAt;
  final String? notes;
  final DateTime createdAt;

  String get categoryLabel {
    switch (category) {
      case 'bow':
        return 'Okçuluk & Yay';
      case 'racket':
        return 'Raket';
      case 'footwear':
        return 'Ayakkabı';
      case 'apparel':
        return 'Kıyafet & Koruma';
      case 'ball':
        return 'Top & Ekipman';
      default:
        return 'Genel Malzeme';
    }
  }

  String get statusLabel {
    switch (status) {
      case 'maintenance':
        return 'Bakımda';
      case 'retired':
        return 'Arşivlendi';
      default:
        return 'Kullanımda';
    }
  }

  factory AthleteEquipment.fromMap(Map<String, dynamic> m) => AthleteEquipment(
        id: m['id'] as String,
        athleteId: m['athlete_id'] as String,
        clubId: m['club_id'] as String?,
        name: (m['name'] as String?) ?? '',
        category: (m['category'] as String?) ?? 'other',
        brandModel: m['brand_model'] as String?,
        serialNo: m['serial_no'] as String?,
        tuningParams: (m['tuning_params'] as Map?)?.cast<String, dynamic>() ?? const {},
        status: (m['status'] as String?) ?? 'active',
        lastServicedAt: m['last_serviced_at'] != null
            ? DateTime.tryParse(m['last_serviced_at'].toString())
            : null,
        notes: m['notes'] as String?,
        createdAt: m['created_at'] != null
            ? DateTime.tryParse(m['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );
}

class EquipmentService {
  EquipmentService(this._db);
  final SupabaseClient _db;

  Future<List<AthleteEquipment>> listEquipment(String athleteId) async {
    final rows = await _db
        .from('athlete_equipment')
        .select('*')
        .eq('athlete_id', athleteId)
        .order('created_at', ascending: false);
    return [
      for (final r in rows as List)
        AthleteEquipment.fromMap((r as Map).cast<String, dynamic>()),
    ];
  }

  Future<void> saveEquipment({
    String? id,
    required String athleteId,
    String? clubId,
    required String name,
    required String category,
    String? brandModel,
    String? serialNo,
    Map<String, dynamic> tuningParams = const {},
    String status = 'active',
    String? notes,
  }) async {
    final data = {
      'athlete_id': athleteId,
      if (clubId != null) 'club_id': clubId,
      'name': name.trim(),
      'category': category,
      if (brandModel != null && brandModel.trim().isNotEmpty)
        'brand_model': brandModel.trim(),
      if (serialNo != null && serialNo.trim().isNotEmpty)
        'serial_no': serialNo.trim(),
      'tuning_params': tuningParams,
      'status': status,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    };

    if (id != null) {
      await _db.from('athlete_equipment').update(data).eq('id', id);
    } else {
      await _db.from('athlete_equipment').insert(data);
    }
  }

  Future<void> updateTuning({
    required String equipmentId,
    required Map<String, dynamic> tuningParams,
    String? notes,
  }) async {
    await _db.from('athlete_equipment').update({
      'tuning_params': tuningParams,
      'last_serviced_at': DateTime.now().toIso8601String(),
      if (notes != null) 'notes': notes.trim(),
    }).eq('id', equipmentId);
  }

  Future<void> deleteEquipment(String equipmentId) async {
    await _db.from('athlete_equipment').delete().eq('id', equipmentId);
  }
}

// ------------------------------ Sağlayıcılar ---------------------------------

final equipmentServiceProvider = Provider<EquipmentService>((ref) {
  return EquipmentService(ref.watch(supabaseClientProvider));
});

final myEquipmentProvider =
    FutureProvider.autoDispose<List<AthleteEquipment>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  if (profile == null) return const [];
  final athlete = await ref.watch(athleteByProfileProvider(profile.id).future);
  if (athlete == null) return const [];
  return ref.watch(equipmentServiceProvider).listEquipment(athlete.id);
});