import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

final proAuthorizedClubsProvider = Provider<AsyncValue<List<ClubRef>>>((ref) {
  final access = ref.watch(swanAccessProvider);
  final operationalClubIds = access.clubOperationsAuthority
      .map((authority) => authority.clubId)
      .toSet();
  return ref.watch(myClubsProvider).whenData(
        (clubs) => clubs
            .where(
              (club) =>
                  club.isActive &&
                  (const {'club_admin', 'coach'}.contains(club.role) ||
                      operationalClubIds.contains(club.id)),
            )
            .toList(growable: false),
      );
});

class ProClubContextSelector extends ConsumerWidget {
  const ProClubContextSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubs = ref.watch(proAuthorizedClubsProvider).valueOrNull ?? const [];
    if (clubs.isEmpty) return const SizedBox.shrink();
    final selectedId = ref.watch(selectedClubIdProvider);
    final selected =
        clubs.where((club) => club.id == selectedId).firstOrNull ?? clubs.first;
    if (selectedId != selected.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ref.read(selectedClubIdProvider.notifier).state = selected.id;
        }
      });
    }
    if (clubs.length == 1) {
      return Text(selected.name, overflow: TextOverflow.ellipsis);
    }
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        key: const Key('pro-club-selector'),
        value: selected.id,
        dropdownColor: const Color(0xFF1C2541),
        items: [
          for (final club in clubs)
            DropdownMenuItem(value: club.id, child: Text(club.name)),
        ],
        onChanged: (id) async {
          if (id == null || !clubs.any((club) => club.id == id)) return;
          final coordinator = ref.read(proDirtyStateCoordinatorProvider);
          await coordinator.runGuardedTransition(
            confirmDiscard: () => _confirmDiscard(context),
            invalidate: () => invalidateProFeatureState(ref),
            transition: () {
              ref.read(selectedClubIdProvider.notifier).state = id;
            },
          );
        },
      ),
    );
  }

  Future<bool> _confirmDiscard(BuildContext context) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Kaydedilmemiş değişiklikler var'),
          content: const Text(
            'Kulüp değiştirildiğinde kaydedilmemiş işlemler bırakılır.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Kulübü değiştir'),
            ),
          ],
        ),
      ) ??
      false;
}
