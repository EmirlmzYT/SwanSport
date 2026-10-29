import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'pro_workspace.dart';

/// `SwanAccess` hesaplanırken kullanılan uzak kaynakların yükleme durumu.
///
/// `swanAccessProvider` kısmi verilerle güvenli biçimde `none` dönebildiği
/// için Pro giriş kapısı, kesin bir erişim reddi göstermeden önce bu
/// kaynakların tamamlanmasını ayrıca bekler.
final proAccessReadinessProvider = Provider<AsyncValue<void>>((ref) {
  final sources = <AsyncValue<dynamic>>[
    ref.watch(currentProfileProvider),
    ref.watch(isPlatformAdminProvider),
    ref.watch(myCredentialsProvider),
    ref.watch(myIdentityGateProvider),
    ref.watch(myAccountantClubIdsProvider),
    ref.watch(myManagedTurfFieldIdsProvider),
    ref.watch(delegatedTurfFieldIdsProvider),
    ref.watch(myFederationAppointmentsProvider),
    ref.watch(myFederationRolesProvider),
    ref.watch(myRefereeProfileProvider),
    ref.watch(myClubStaffRolesProvider),
    ref.watch(mySportsClubAuthorityProvider),
    ref.watch(myClubOperationsAuthorityProvider),
    ref.watch(guardianAthleteIdsProvider),
    ref.watch(myVenueVerificationTierProvider),
  ];

  for (final source in sources) {
    if (source.hasError) {
      return AsyncError(
        source.error!,
        source.stackTrace ?? StackTrace.current,
      );
    }
  }
  if (sources.any((source) => source.isLoading)) {
    return const AsyncLoading();
  }
  return const AsyncData(null);
});

/// Kullanıcının mevcut erişimine göre izin verilen çalışma alanları listesi.
///
/// Sunucu yetkilendirmesi [SwanAccess] temel belirleyicidir.
/// Güvenlik kuralı: `user_metadata` istemci tarafından değiştirilebilir olduğundan
/// hiçbir zaman çalışma alanı yetkisi veya preview erişimi açamaz.
/// Yalnızca sunucu tarafından yönetilen güvenilir `app_metadata` içerisindeki
/// `pro_preview_workspaces` listesi (varsa) eklenir.
final availableProWorkspacesProvider = Provider<List<ProWorkspace>>((ref) {
  final session = ref.watch(authSessionProvider).valueOrNull;
  if (session?.user.appMetadata['pro_workspace_preview'] == true) {
    return ProWorkspace.values;
  }
  final access = ref.watch(swanAccessProvider);
  final accessWorkspaces = proWorkspacesFor(access);
  if (accessWorkspaces.isNotEmpty) {
    return accessWorkspaces;
  }

  // Server-controlled app_metadata preview fallback (asla user_metadata kontrol edilmez)
  final appMeta = session?.user.appMetadata;
  if (appMeta != null) {
    final previewRaw =
        appMeta['pro_preview_workspaces'] ?? appMeta['preview_workspaces'];
    if (previewRaw is List) {
      final list = <ProWorkspace>[];
      for (final item in previewRaw) {
        final name = item.toString().toLowerCase().trim();
        for (final ws in ProWorkspace.values) {
          if (ws.name.toLowerCase() == name && !list.contains(ws)) {
            list.add(ws);
          }
        }
      }
      if (list.isNotEmpty) {
        return List.unmodifiable(list);
      }
    }
    if (appMeta['pro_preview'] == true || appMeta['preview'] == true) {
      return List.unmodifiable(ProWorkspace.values);
    }
  }

  return const [];
});

/// Aktif seçili profesyonel çalışma alanı.
///
/// Eğer kullanıcının tek bir çalışma alanı varsa otomatik olarak o seçilir.
/// Çoklu alanda kullanıcı manuel seçim yapabilir; erişim kaybedilirse
/// veya hesap değişirse ilk geçerli çalışma alanına sıfırlanır.
/// Hiç erişim yoksa `null` döner.
class SelectedProWorkspaceNotifier extends Notifier<ProWorkspace?> {
  String? _lastUserId;
  ProWorkspace? _selected;

  @override
  ProWorkspace? build() {
    final sessionAsync = ref.watch(authSessionProvider);
    final currentUserId = sessionAsync.valueOrNull?.user.id;

    if (currentUserId != _lastUserId) {
      _lastUserId = currentUserId;
      _selected = null;
    }

    final available = ref.watch(availableProWorkspacesProvider);
    if (available.isEmpty) {
      _selected = null;
      return null;
    }

    if (_selected != null && available.contains(_selected)) {
      return _selected;
    }

    _selected = available.first;
    return _selected;
  }

  void selectWorkspace(ProWorkspace workspace) {
    final available = ref.read(availableProWorkspacesProvider);
    if (available.contains(workspace)) {
      _selected = workspace;
      state = workspace;
    }
  }
}

final selectedProWorkspaceProvider =
    NotifierProvider<SelectedProWorkspaceNotifier, ProWorkspace?>(
  SelectedProWorkspaceNotifier.new,
);
