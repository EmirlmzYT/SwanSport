import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../../app/widgets/premium.dart';
import 'social_widgets.dart';
import '../../../../app/design/swan_type.dart';

/// Takip akışı boşken gösterilen "kimi takip etsem?" bölümü.
class FollowSuggestions extends ConsumerWidget {
  const FollowSuggestions({super.key, this.onExplore});

  /// "Keşfet'e bak" bağlantısına dokunulduğunda çağrılır.
  final VoidCallback? onExplore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final async = ref.watch(suggestionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        Center(
          child: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [kTealBright, kTealDeep],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.group_add_rounded,
                color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text('Akışını doldur',
              style: SwanType.h2(ink)),
        ),
        const SizedBox(height: 6),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Kulüpleri ve antrenörleri takip et; paylaşımları burada görünsün.',
              textAlign: TextAlign.center,
              style: SwanType.caption(SwanColors.textSecondary),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text('Önerilenler', style: SwanType.h3(ink)),
        const SizedBox(height: 10),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(color: kTeal)),
          ),
          error: (e, _) => Text('Öneriler yüklenemedi: $e',
              style:
                  SwanType.caption(SwanColors.textSecondary)),
          data: (list) {
            if (list.isEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Şimdilik önerilecek kimse yok. Keşfet sekmesinden '
                      'paylaşımlara göz atabilirsin.',
                      style: SwanType.caption(SwanColors.textSecondary)),
                  const SizedBox(height: 14),
                  if (onExplore != null) _exploreButton(isDark, ink),
                ],
              );
            }
            return Column(
              children: [
                ...list.map((s) => _SuggestionTile(suggestion: s)),
                if (onExplore != null) ...[
                  const SizedBox(height: 8),
                  _exploreButton(isDark, ink),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _exploreButton(bool isDark, Color ink) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    return GestureDetector(
      onTap: onExplore,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: line),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.explore_rounded, size: 18, color: kTeal),
            const SizedBox(width: 8),
            Text('Keşfet’e göz at',
                style: SwanType.bodySm(ink, w: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _SuggestionTile extends ConsumerStatefulWidget {
  const _SuggestionTile({required this.suggestion});
  final SuggestionRow suggestion;

  @override
  ConsumerState<_SuggestionTile> createState() => _SuggestionTileState();
}

class _SuggestionTileState extends ConsumerState<_SuggestionTile> {
  bool _following = false;
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;
    final next = !_following;
    setState(() {
      _busy = true;
      _following = next;
    });
    try {
      await ref.read(socialServiceProvider).setFollow(
            widget.suggestion.targetType,
            widget.suggestion.id,
            next,
          );
      ref.invalidate(feedProvider);
    } catch (_) {
      if (mounted) setState(() => _following = !next);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final s = widget.suggestion;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        s.isClub ? '/kulup-profil' : '/profil',
        arguments: s.id,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: line),
        ),
        child: Row(children: [
          SocialAvatar(
            initials: s.initials,
            imageUrl: s.avatarUrl,
            size: 44,
            gradientIndex: s.name.length % 4,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SwanType.bodySm(ink, w: FontWeight.w800)),
                  ),
                  const SizedBox(width: 4),
                  const VerifiedBadge(size: 13),
                ]),
                if (s.subtitle != null)
                  Text(s.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SwanType.caption(SwanColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _toggle,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
              decoration: BoxDecoration(
                gradient: _following
                    ? null
                    : const LinearGradient(colors: [kTealBright, kTeal]),
                color: _following ? Colors.transparent : null,
                borderRadius: BorderRadius.circular(12),
                border: _following ? Border.all(color: line) : null,
              ),
              child: Text(_following ? 'Takiptesin' : 'Takip Et',
                  style: SwanType.caption(_following ? SwanColors.textSecondary : Colors.white, w: FontWeight.w800)),
            ),
          ),
        ]),
      ),
    );
  }
}
