import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'pro_workspace.dart';

/// Kullanıcının mevcut erişimine göre izin verilen çalışma alanları listesi.
final availableProWorkspacesProvider = Provider<List<ProWorkspace>>((ref) {
  final access = ref.watch(swanAccessProvider);
  return proWorkspacesFor(access);
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
