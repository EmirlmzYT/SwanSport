import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_scope.dart';
import 'supabase_athletes.dart';

/// ---------------------------------------------------------------------------
/// Belge kasası — dosya, tür ve geçerlilik takibi.
///
/// Kimlik doğrulama ekleri (`verification_documents`) ayrı kalıyor: o, başvuru
/// sürecine ait geçici bir ek; bu ise kulübün ve sporcunun kalıcı arşivi.
/// ---------------------------------------------------------------------------

/// Belge türleri — spor kulübünde gerçekten tutulan evraklar.
const Map<String, String> kDocTypes = {
  'lisans': 'Sporcu lisansı',
  'saglik': 'Sağlık raporu',
  'kademe': 'Antrenörlük belgesi',
  'tescil': 'Kulüp tescil belgesi',
  'sertifika': 'Sertifika',
  'sozlesme': 'Sözleşme',
  'diger': 'Diğer',
};

class VaultDoc {
  const VaultDoc({
    required this.id,
    required this.name,
    required this.ownerType,
    required this.verified,
    required this.state,
    required this.createdAt,
    this.docType,
    this.storagePath,
    this.ownerId,
    this.ownerName,
    this.issuedOn,
    this.expiresOn,
    this.daysLeft,
  });

  final String id;
  final String name;
  final String ownerType; // club | athlete | person
  final bool verified;

  /// 'geçerli' | 'yakında doluyor' | 'süresi doldu' | 'süresiz'
  final String state;
  final DateTime createdAt;
  final String? docType;
  final String? storagePath;
  final String? ownerId;
  final String? ownerName;
  final DateTime? issuedOn;
  final DateTime? expiresOn;
  final int? daysLeft;

  bool get isExpired => state == 'süresi doldu';
  bool get isExpiring => state == 'yakında doluyor';

  String get typeLabel => kDocTypes[docType] ?? 'Belge';

  String get ownerLabel => switch (ownerType) {
        'athlete' => ownerName ?? 'Sporcu',
        'person' => ownerName ?? 'Kişisel',
        _ => 'Kulüp',
      };

  factory VaultDoc.fromMap(Map<String, dynamic> m) => VaultDoc(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        docType: m['doc_type'] as String?,
        storagePath: m['storage_path'] as String?,
        ownerType: (m['owner_type'] as String?) ?? 'club',
        ownerId: m['owner_id'] as String?,
        ownerName: m['owner_name'] as String?,
        issuedOn: m['issued_on'] == null
            ? null
            : DateTime.tryParse('${m['issued_on']}'),
        expiresOn: m['expires_on'] == null
            ? null
            : DateTime.tryParse('${m['expires_on']}'),
        verified: (m['verified'] as bool?) ?? false,
        daysLeft: m['days_left'] as int?,
        state: (m['state'] as String?) ?? 'süresiz',
        createdAt:
            DateTime.tryParse('${m['created_at']}')?.toLocal() ?? DateTime.now(),
      );
}

class VaultService {
  VaultService(this._c);
  final SupabaseClient _c;

  /// Belgeler özel bir kovada durur; bağlantılar imzalıdır ve süreyle sınırlıdır.
  static const String bucket = 'verification-docs';

  Future<List<VaultDoc>> list(String clubId,
      {String? ownerType, String? ownerId}) async {
    final rows = await _c.rpc<List<dynamic>>('document_list', params: {
      'p_club': clubId,
      if (ownerType != null) 'p_owner_type': ownerType,
      if (ownerId != null) 'p_owner_id': ownerId,
    });
    return rows
        .map((r) => VaultDoc.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<String> upload(Uint8List bytes, String fileName) async {
    final uid = _c.auth.currentUser?.id ?? 'anon';
    final dot = fileName.lastIndexOf('.');
    final ext = dot >= 0 ? fileName.substring(dot + 1).toLowerCase() : 'pdf';
    final path = '$uid/belge_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _c.storage.from(bucket).uploadBinary(path, bytes,
        fileOptions: const FileOptions(upsert: true));
    return path;
  }

  /// İmzalı bağlantı — belge herkese açık değil.
  Future<String> signedUrl(String path) =>
      _c.storage.from(bucket).createSignedUrl(path, 3600);

  Future<void> add({
    required String clubId,
    required String name,
    String ownerType = 'club',
    String? ownerId,
    String? docType,
    String? path,
    DateTime? issued,
    DateTime? expires,
    String? note,
  }) async {
    await _c.rpc<void>('add_document', params: {
      'p_club': clubId,
      'p_name': name.trim(),
      'p_owner_type': ownerType,
      if (ownerId != null) 'p_owner_id': ownerId,
      if (docType != null) 'p_doc_type': docType,
      if (path != null) 'p_path': path,
      if (issued != null)
        'p_issued': issued.toIso8601String().split('T').first,
      if (expires != null)
        'p_expires': expires.toIso8601String().split('T').first,
      if (note != null && note.trim().isNotEmpty) 'p_note': note.trim(),
    });
  }

  Future<void> verify(String id, bool verified) =>
      _c.rpc<void>('verify_document',
          params: {'p_document': id, 'p_verified': verified});

  Future<void> remove(String id) async {
    await _c.from('documents').delete().eq('id', id);
  }
}

// =============================== Provider'lar ==============================

final vaultServiceProvider = Provider<VaultService>((ref) {
  return VaultService(ref.watch(supabaseClientProvider));
});

final vaultDocsProvider = FutureProvider.autoDispose<List<VaultDoc>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  return ref.watch(vaultServiceProvider).list(club.id);
});
