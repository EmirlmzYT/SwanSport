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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    child: Icon(Icons.person_rounded, color: c.accent, size: 28),
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

  Widget _buildClubStoryItem(BuildContext context, ClubRef club, SwanPalette c) {
    final initials = club.name.trim().isNotEmpty
        ? club.name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
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

  Widget _buildSuggestionStoryItem(BuildContext context, SuggestionRow s, SwanPalette c) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/profil', arguments: {'id': s.id}),
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
                          child: Text(s.initials, style: SwanType.caption(c.accent, w: FontWeight.w700)),
                        ),
                      )
                    : Center(
                        child: Text(s.initials, style: SwanType.caption(c.accent, w: FontWeight.w700)),
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



void _showStitchPostOptions(BuildContext context, SwanPalette c, {required String author}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: c.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: Icon(Icons.share_rounded, color: c.ink),
              title: Text('Gönderiyi Paylaş', style: SwanType.body(c.ink, w: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Paylaşım bağlantısı panoya kopyalandı!')),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.bookmark_add_outlined, color: c.ink),
              title: Text('Kaydet & Favorilere Ekle', style: SwanType.body(c.ink, w: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Gönderi koleksiyonunuza kaydedildi.')),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.person_add_alt_1_rounded, color: c.accent),
              title: Text('$author Profili', style: SwanType.body(c.ink, w: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/kesfet');
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Colors.redAccent),
              title: const Text('Bildir', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bildiriminiz incelenmek üzere alındı.')),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

void _showStitchCommentsSheet(BuildContext context, SwanPalette c) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: c.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: SizedBox(
          height: 380,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Yorumlar',
                style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: c.ink),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: c.accent.withValues(alpha: 0.2),
                        child: Text('M', style: TextStyle(color: c.accent, fontWeight: FontWeight.bold)),
                      ),
                      title: Text('Mert Koç', style: SwanType.caption(c.ink, w: FontWeight.w700)),
                      subtitle: Text('Harika tempo, form çok temiz! 🔥', style: SwanType.bodySm(c.inkMuted)),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                        child: const Text('E', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
                      ),
                      title: Text('Emre Sporcu', style: SwanType.caption(c.ink, w: FontWeight.w700)),
                      subtitle: Text('Haftalık PR gelmiş, tebrikler!', style: SwanType.bodySm(c.inkMuted)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Yorum yaz...',
                    hintStyle: SwanType.bodySm(c.inkMuted),
                    filled: true,
                    fillColor: c.surfaceAlt,
                    suffixIcon: IconButton(
                      icon: Icon(Icons.send_rounded, color: c.accent),
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Yorumunuz gönderildi!')),
                        );
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Google Stitch: Post 1 - Athletic Workout Session Post
class StitchWorkoutPostCard extends StatefulWidget {
  const StitchWorkoutPostCard({super.key});

  @override
  State<StitchWorkoutPostCard> createState() => _StitchWorkoutPostCardState();
}

class _StitchWorkoutPostCardState extends State<StitchWorkoutPostCard> {
  bool _isLiked = true;
  int _likeCount = 2840;
  bool _isSaved = false;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;

    return Container(
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: c.line.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg, vertical: 8),
            child: Row(
              children: [
                // Avatar with Ring
                Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [c.accent, const Color(0xFF2FBFB6)],
                    ),
                  ),
                  child: ClipOval(
                    child: Image.network(
                      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(Icons.person, color: c.inkMuted),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Caner Demir',
                            style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.verified_rounded,
                            color: c.accent,
                            size: 15,
                          ),
                        ],
                      ),
                      Text(
                        '@caner.fit • İstanbul • 2 saat önce',
                        style: SwanType.caption(c.inkMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.more_horiz_rounded, color: c.inkMuted),
                  onPressed: () => _showStitchPostOptions(context, c, author: '@caner.fit'),
                ),
              ],
            ),
          ),
          // Post Media with Floating Badges
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 4 / 3.2,
                child: Image.network(
                  'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?w=800',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: c.surfaceAlt,
                    child: const Center(
                      child: Icon(Icons.fitness_center, size: 48, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              // Floating Workout Stat Badge (Top Left)
              Positioned(
                top: 12,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF020F1F).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fitness_center_rounded, color: c.accent, size: 15),
                      const SizedBox(width: 6),
                      const Text(
                        'Kuvvet Seansı • 75 dk',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Floating Calories Badge (Bottom Right)
              Positioned(
                bottom: 12,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF020F1F).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_fire_department_rounded,
                          color: Color(0xFFFF7A59), size: 14),
                      SizedBox(width: 4),
                      Text(
                        '620 kcal',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFF7A59),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Action Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: _isLiked ? const Color(0xFFFF7A59) : c.ink,
                    size: 26,
                  ),
                  onPressed: () {
                    setState(() {
                      _isLiked = !_isLiked;
                      _likeCount += _isLiked ? 1 : -1;
                    });
                  },
                ),
                IconButton(
                  icon: Icon(Icons.chat_bubble_outline_rounded,
                      color: c.ink, size: 24),
                  onPressed: () => _showStitchCommentsSheet(context, c),
                ),
                IconButton(
                  icon: Icon(Icons.send_rounded, color: c.ink, size: 23),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Paylaşım bağlantısı panoya kopyalandı!')),
                    );
                  },
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: _isSaved ? c.accent : c.ink,
                    size: 24,
                  ),
                  onPressed: () {
                    setState(() => _isSaved = !_isSaved);
                  },
                ),
              ],
            ),
          ),
          // Likes, Caption & Hashtags
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: SwanType.caption(c.inkMuted),
                    children: [
                      const TextSpan(text: 'Beğenenler: '),
                      TextSpan(
                        text: 'emir.ylmz',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: c.ink,
                        ),
                      ),
                      const TextSpan(text: ' ve '),
                      TextSpan(
                        text: '$_likeCount diğer kişi',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: c.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                RichText(
                  text: TextSpan(
                    style: SwanType.bodySm(c.ink).copyWith(height: 1.45),
                    children: [
                      TextSpan(
                        text: 'caner.fit ',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: c.ink,
                        ),
                      ),
                      const TextSpan(
                        text:
                            'Gelişimin tek anahtarı aşamalı yükleme (progressive overload). Son setlerde zorlanmıyorsanız sınırlarınız genişlemiyor demektir. Bugün SwanSport antrenman planındaki 4x8 ağır squat ve dips kombinasyonunu eksiksiz tamamladık! 🚀🔥',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    Text('#SwanSport', style: TextStyle(color: c.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                    Text('#KuvvetAntrenmanı', style: TextStyle(color: c.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                    Text('#Calisthenics', style: TextStyle(color: c.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                    Text('#Disiplin', style: TextStyle(color: c.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '142 yorumun tümünü gör',
                  style: SwanType.caption(c.inkMuted, w: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Google Stitch: Post 2 - Official Sports News Briefing Card
class StitchNewsBriefingCard extends StatelessWidget {
  const StitchNewsBriefingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.swan;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: SwanSpace.lg, vertical: 12),
      decoration: BoxDecoration(
        color: c.surfaceAlt.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.line.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.accent.withValues(alpha: 0.3)),
                  ),
                  child: Icon(Icons.newspaper_rounded, color: c.accent, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Spor Gündemi & Bülten',
                            style: SwanType.bodySm(c.ink, w: FontWeight.w800),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: c.accent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'RESMİ',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: c.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Günün 3 Önemli Spor Haberi • 18 Nisan',
                        style: SwanType.caption(c.inkMuted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.share_rounded, color: c.inkMuted, size: 18),
              ],
            ),
          ),
          // Banner with Headlines
          Stack(
            children: [
              SizedBox(
                height: 140,
                width: double.infinity,
                child: Image.network(
                  'https://images.unsplash.com/photo-1461896836934-ffe607ba8211?w=800',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: c.surface),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        c.surface.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 10,
                left: 12,
                right: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: c.accentFill,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Günün Manşetleri',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '3 dk okuma',
                        style: TextStyle(fontSize: 10, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Bullet Items
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _bulletItem('1', 'Avrupa Yarı Maratonu:', 'Milli atletimiz rekor dereceyle kürsünün zirvesine çıktı.', c),
                const SizedBox(height: 10),
                _bulletItem('2', 'Bilim & Performans:', 'Yeni araştırma, sabah HIIT seanslarının insülin hassasiyetini %28 artırdığını kanıtladı.', c),
                const SizedBox(height: 10),
                _bulletItem('3', 'SwanSport Ligi:', 'Bahar sezonu maraton kulüp puanlamaları bu gece 00:00\'da güncelleniyor.', c),
                const SizedBox(height: 14),
                Divider(color: c.line.withValues(alpha: 0.5), height: 1),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('1.450 kişi okudu', style: SwanType.caption(c.inkMuted)),
                    Row(
                      children: [
                        Text(
                          'Detaylı Oku',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: c.accent,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 14, color: c.accent),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bulletItem(String num, String bold, String text, SwanPalette c) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: c.accent.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              num,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: c.accent,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: SwanType.caption(c.ink).copyWith(height: 1.35),
              children: [
                TextSpan(text: '$bold ', style: const TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: text),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Google Stitch: Post 3 - Transformation & Milestone Visual Card
class StitchTransformationPostCard extends StatelessWidget {
  const StitchTransformationPostCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.swan;

    return Container(
      padding: const EdgeInsets.only(top: 12, bottom: 20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: c.line.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(1.5),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFFF7A59), Color(0xFF2FBFB6)],
                    ),
                  ),
                  child: ClipOval(
                    child: Image.network(
                      'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(Icons.person, color: c.inkMuted),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Selin Kaya', style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: c.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Senin İçin Önerildi',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: c.accent),
                            ),
                          ),
                        ],
                      ),
                      Text('Ankara • 5 saat önce', style: SwanType.caption(c.inkMuted)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.more_horiz_rounded, color: c.inkMuted),
                  onPressed: () => _showStitchPostOptions(context, c, author: 'Selin Kaya'),
                ),
              ],
            ),
          ),
          // Transformation & Milestone Visual Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    c.surfaceAlt,
                    c.surface,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(SwanRadius.lg),
                border: Border.all(color: c.line.withValues(alpha: 0.6)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: c.accent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.workspace_premium_rounded, color: c.accent, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '90 Günlük Swan Definasyon Başarısı!',
                              style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                            ),
                            Text(
                              'Hedef Tamamlandı • %100 Başarı',
                              style: TextStyle(fontSize: 11, color: c.accent, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF020F1F),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFF7A59).withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          '-8.4 kg',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFFF7A59),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Comparison Grid
                  Row(
                    children: [
                      Expanded(
                        child: _statBox('YAĞ ORANI', '%26 → %18', '-%8 Değişim', c.accent, c),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _statBox('5K KOŞU PR', '29dk → 22dk', '-7 Dakika', c.accent, c),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _statBox('SERİ', '82 Gün', 'Aralıksız 🔥', const Color(0xFFFF7A59), c),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Progress Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Program İlerlemesi', style: SwanType.caption(c.inkMuted)),
                      Text('90/90 Gün Seansı',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.accent)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: 1.0,
                      backgroundColor: c.surface,
                      valueColor: AlwaysStoppedAnimation(c.accent),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Caption
          Padding(
            padding: const EdgeInsets.fromLTRB(SwanSpace.lg, 12, SwanSpace.lg, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'berk.fitness, caner.fit ve 892 kişi alkışladı 👏',
                  style: SwanType.caption(c.ink, w: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: SwanType.bodySm(c.ink).copyWith(height: 1.45),
                    children: [
                      TextSpan(text: 'selin.kaya ', style: TextStyle(fontWeight: FontWeight.w800, color: c.ink)),
                      const TextSpan(
                        text:
                            'İnanılmaz bir 3 ay geçti! SwanSport antrenörlerinin programına ve beslenme takipçisine sadık kalarak hayatımın en fit formuna ulaştım. Vazgeçmeyen herkese selam olsun! 🦢💪',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value, String change, Color changeColor, SwanPalette c) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF020F1F).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.line.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: c.inkMuted)),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c.ink)),
          const SizedBox(height: 3),
          Text(change, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: changeColor)),
        ],
      ),
    );
  }
}
