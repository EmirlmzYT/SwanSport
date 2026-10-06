import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';
import '../post_composer_sheet.dart';

/// Google Stitch: Top App Bar
class StitchFeedTopBar extends StatelessWidget implements PreferredSizeWidget {
  const StitchFeedTopBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final user = Supabase.instance.client.auth.currentUser;

    return Container(
      height: preferredSize.height,
      padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: c.isDark ? 0.94 : 0.98),
        border: Border(
          bottom: BorderSide(
            color: c.line.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        top: false,
        child: Row(
          children: [
            // Brand Logo (Google Stitch Grand Hotel cursive wordmark)
            Text(
              'SwanSport',
              style: GoogleFonts.grandHotel(
                fontSize: 30,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            // Notifications Favorite Button with Unread Ping Dot
            IconButton(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.favorite_border_rounded,
                    color: c.inkMuted,
                    size: 24,
                  ),
                  Positioned(
                    top: 1,
                    right: 1,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF7A59),
                        shape: BoxShape.circle,
                        border: Border.all(color: c.surface, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
              onPressed: () => Navigator.pushNamed(context, '/bildirimler'),
              tooltip: 'Bildirimler',
            ),
            // Messages Button
            IconButton(
              icon: Icon(
                Icons.send_rounded,
                color: c.inkMuted,
                size: 22,
              ),
              onPressed: () => Navigator.pushNamed(context, '/mesajlar'),
              tooltip: 'Mesajlar',
            ),
            const SizedBox(width: 4),
            // If Guest: Quick Login Button
            if (user == null)
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.accent,
                  side: BorderSide(color: c.accent.withValues(alpha: 0.6)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: const Size(0, 32),
                ),
                onPressed: () => Navigator.pushNamed(context, '/auth'),
                child: const Text(
                  'Giriş Yap',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Google Stitch: Stories Bar (Minimalist Circular Rings connected to real clubs and athletes)
class StitchStoriesBar extends ConsumerWidget {
  const StitchStoriesBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.swan;
    final clubs = ref.watch(myClubsProvider).valueOrNull ?? const [];
    final suggestions = ref.watch(suggestionsProvider).valueOrNull ?? const [];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: c.line.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
      ),
      child: SizedBox(
        height: 84,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
          children: [
            // User Story Add Item
            _buildUserStoryAdd(context, c),
            const SizedBox(width: 14),

            // Enrolled Clubs Stories
            for (final club in clubs) ...[
              _buildClubStoryItem(context, club, c),
              const SizedBox(width: 14),
            ],

            // Suggested Athletes / Coaches Stories
            for (final s in suggestions.take(6)) ...[
              _buildSuggestionStoryItem(context, s, c),
              const SizedBox(width: 14),
            ],

            // If empty, explore prompt
            if (clubs.isEmpty && suggestions.isEmpty)
              _buildExploreStoryItem(context, c),
          ],
        ),
      ),
    );
  }

  Widget _buildUserStoryAdd(BuildContext context, SwanPalette c) {
    return GestureDetector(
      onTap: () => showPostComposer(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 60,
                height: 60,
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: c.accent.withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: c.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child:
                        Icon(Icons.person_rounded, color: c.accent, size: 28),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: c.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.surface, width: 2),
                  ),
                  child: const Center(
                    child: Icon(Icons.add, size: 12, color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 62,
            child: Text(
              'Hikayen',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: SwanType.caption(c.inkMuted, w: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClubStoryItem(
      BuildContext context, ClubRef club, SwanPalette c) {
    final initials = club.name.trim().isNotEmpty
        ? club.name
            .trim()
            .split(' ')
            .map((e) => e.isNotEmpty ? e[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : 'KL';

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/kulupler'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [c.accent, const Color(0xFF008C95)],
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: c.surface,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initials,
                  style: SwanType.caption(c.accent, w: FontWeight.w800),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 62,
            child: Text(
              club.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: SwanType.caption(c.ink, w: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionStoryItem(
      BuildContext context, SuggestionRow s, SwanPalette c) {
    return GestureDetector(
      onTap: () =>
          Navigator.pushNamed(context, '/profil', arguments: {'id': s.id}),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [c.accent, const Color(0xFFFF7A59)],
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: c.surface,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: s.avatarUrl != null && s.avatarUrl!.isNotEmpty
                    ? Image.network(
                        s.avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(s.initials,
                              style: SwanType.caption(c.accent,
                                  w: FontWeight.w700)),
                        ),
                      )
                    : Center(
                        child: Text(s.initials,
                            style:
                                SwanType.caption(c.accent, w: FontWeight.w700)),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 62,
            child: Text(
              s.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: SwanType.caption(c.ink, w: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExploreStoryItem(BuildContext context, SwanPalette c) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/kesfet'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: c.line, width: 1.5),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: c.surface,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(Icons.explore_rounded, color: c.accent, size: 24),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 62,
            child: Text(
              'Keşfet',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: SwanType.caption(c.inkMuted, w: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
