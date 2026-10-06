import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/shared_content_card.dart';
import '../../../app/push/push_service.dart';
import '../../../app/widgets/premium.dart';
import 'widgets/social_widgets.dart';
import '../../../app/widgets/swan_bottom_nav.dart';

/// Sohbet listesi — gruplar ve birebir sohbetler tek akışta (Google Stitch Screen 21).
///
/// Google Stitch "SwanSport - Mesajlar & Antrenman Grupları" tasarımını uygular:
/// - Canlı Kulvar (Aktif sporcular / Story rayı)
/// - Segment kategori filtreleri (Tüm Mesajlar, Antrenörler, Kulüp Grupları)
/// - Sabitlenmiş Koç Kartı & Antrenman Grupları
/// - Toplu Antrenman Odası Hızlı Aksiyon Kartı
class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({this.initialTab = 0, super.key});

  final int initialTab;

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _Entry {
  const _Entry.group(CommunityRow this.group) : dm = null;
  const _Entry.dm(ConversationRow this.dm) : group = null;

  final CommunityRow? group;
  final ConversationRow? dm;

  DateTime? get at => group?.lastAt ?? dm?.lastAt;
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  int _selectedFilter = 0; // 0 = Tüm Mesajlar, 1 = Antrenörler, 2 = Kulüp Grupları

  final List<String> _filters = const ['Tüm Mesajlar', 'Antrenörler', 'Kulüp Grupları'];

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(communityServiceProvider).ensureMine();
      if (mounted) ref.invalidate(communityListProvider);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;

    ref.listen(dmChangesProvider, (_, next) {
      if (next is AsyncData) ref.invalidate(conversationsProvider);
    });

    final dms = ref.watch(conversationsProvider);
    final groups = ref.watch(communityListProvider).valueOrNull ?? const [];

    return Scaffold(
      extendBody: true,
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: RefreshIndicator(
              color: c.accent,
              backgroundColor: c.surface,
              onRefresh: () async {
                ref.invalidate(conversationsProvider);
                ref.invalidate(communityListProvider);
                await ref.read(conversationsProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 110),
                children: [
                  _buildHeader(c),
                  const SizedBox(height: SwanSpace.sm),

                  _buildSearchField(c),
                  const SizedBox(height: SwanSpace.md),

                  if (_query.isEmpty) ...[
                    _buildActiveAthletesReel(c),
                    const SizedBox(height: SwanSpace.sm),
                  ],

                  _buildCategoryFilters(c),
                  const SizedBox(height: SwanSpace.sm),

                  // Dynamic list or curated Stitch chat roster
                  dms.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(SwanSpace.lg),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => premiumError(context, '$e'),
                    data: (list) => _buildChatRoster(c, list, groups),
                  ),

                  if (_query.isEmpty) ...[
                    const SizedBox(height: SwanSpace.md),
                    _buildQuickCourtsideCard(c),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _buildHeader(SwanPalette c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(SwanSpace.md, SwanSpace.sm, SwanSpace.md, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'İLETİŞİM & KOÇLUK',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: c.accent,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                'Mesajlar',
                style: GoogleFonts.sora(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: c.ink,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/ara'),
            icon: const Icon(Icons.edit_square, size: 16, color: Colors.black),
            label: const Text('Yeni Sohbet'),
            style: FilledButton.styleFrom(
              backgroundColor: c.accent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SwanRadius.md)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(SwanPalette c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SwanSpace.md),
      child: Container(
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(SwanRadius.md),
          border: Border.all(color: c.line),
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _query = v.trim()),
          style: SwanType.bodySm(c.ink),
          decoration: InputDecoration(
            hintText: 'Sporcu, antrenör veya kulüp ara...',
            hintStyle: SwanType.bodySm(c.inkMuted),
            prefixIcon: Icon(Icons.search_rounded, size: 20, color: c.inkMuted),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: SwanSpace.md, vertical: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveAthletesReel(SwanPalette c) {
    final suggestions = ref.watch(suggestionsProvider).valueOrNull ?? const [];
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: SwanSpace.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Aktif Sporcular (${suggestions.length})',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                    ),
                  ),
                ],
              ),
              Text(
                'Tümü',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: c.accent,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 84,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: SwanSpace.md),
            scrollDirection: Axis.horizontal,
            itemCount: suggestions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final a = suggestions[i];
              return InkWell(
                onTap: () {
                  Navigator.pushNamed(context, '/profil', arguments: a.id);
                },
                borderRadius: BorderRadius.circular(999),
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: c.accent,
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: (a.avatarUrl != null && a.avatarUrl!.isNotEmpty)
                                ? Image.network(
                                    a.avatarUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: c.surfaceAlt,
                                      child: Icon(Icons.person, color: c.inkMuted),
                                    ),
                                  )
                                : Container(
                                    color: c.surfaceAlt,
                                    child: Icon(Icons.person, color: c.inkMuted),
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: c.surface,
                              shape: BoxShape.circle,
                            ),
                            child: const Text('⚡', style: TextStyle(fontSize: 11)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 56,
                      child: Text(
                        a.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: c.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryFilters(SwanPalette c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SwanSpace.md),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(SwanRadius.md),
        ),
        child: Row(
          children: _filters.asMap().entries.map((entry) {
            final idx = entry.key;
            final label = entry.value;
            final isSelected = _selectedFilter == idx;

            return Expanded(
              child: InkWell(
                onTap: () => setState(() => _selectedFilter = idx),
                borderRadius: BorderRadius.circular(SwanRadius.sm),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? c.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(SwanRadius.sm),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: c.accent.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                        color: isSelected ? Colors.black : c.inkMuted,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildChatRoster(SwanPalette c, List<ConversationRow> dms, List<CommunityRow> groups) {
    final filteredGroups = groups.where((g) => g.joined).toList();
    final entries = <_Entry>[
      for (final g in filteredGroups) _Entry.group(g),
      for (final dm in dms) _Entry.dm(dm),
    ];

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: SwanSpace.md, vertical: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(SwanRadius.lg),
            border: Border.all(color: c.line),
          ),
          child: Column(
            children: [
              Icon(Icons.chat_bubble_outline_rounded, size: 48, color: c.accent),
              const SizedBox(height: 12),
              Text(
                'Henüz mesajınız yok',
                style: GoogleFonts.sora(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Antrenörünüzle veya takım arkadaşlarınızla iletişime geçmek için yeni bir sohbet başlatın.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: c.inkMuted,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/ara'),
                icon: const Icon(Icons.search_rounded, size: 16, color: Colors.black),
                label: const Text('Kullanıcı Ara & Sohbet Başlat'),
                style: FilledButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SwanRadius.md)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SwanSpace.md),
      child: Column(
        children: [
          for (final e in entries)
            if (e.group != null && (_selectedFilter == 0 || _selectedFilter == 2))
              _buildRealGroupTile(c, e.group!)
            else if (e.dm != null && (_selectedFilter == 0 || _selectedFilter == 1))
              _buildRealDmTile(c, e.dm!),
        ],
      ),
    );
  }


  Widget _buildRealGroupTile(SwanPalette c, CommunityRow g) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.line),
      ),
      child: InkWell(
        onTap: () => Navigator.pushNamed(
          context,
          g.isFederation ? '/federasyon' : '/topluluk',
          arguments: {'id': g.id, 'name': g.name},
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: c.accentSoft,
                borderRadius: BorderRadius.circular(SwanRadius.md),
              ),
              child: Icon(
                g.isFederation ? Icons.campaign_rounded : Icons.forum_rounded,
                size: 24,
                color: c.accent,
              ),
            ),
            const SizedBox(width: SwanSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(g.name, style: SwanType.body(c.ink, w: FontWeight.w700)),
                      if (g.lastAt != null)
                        Text(shortAgo(g.lastAt!), style: SwanType.caption(c.inkMuted)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    g.lastBody?.trim().isNotEmpty == true
                        ? g.lastBody!
                        : '${g.memberCount} üye',
                    style: SwanType.caption(c.inkMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealDmTile(SwanPalette c, ConversationRow dm) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.line),
      ),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/sohbet', arguments: {
          'id': dm.otherId,
          'name': dm.otherName,
        }),
        child: Row(
          children: [
            SocialAvatar(
              initials: dm.initials,
              imageUrl: dm.otherAvatarUrl,
              size: 52,
              gradientIndex: dm.otherName.length % 4,
            ),
            const SizedBox(width: SwanSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(dm.otherName, style: SwanType.body(c.ink, w: FontWeight.w700)),
                      Text(shortAgo(dm.lastAt), style: SwanType.caption(c.inkMuted)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    dm.lastBody,
                    style: SwanType.caption(c.inkMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (dm.unread > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(999)),
                child: Text('${dm.unread}', style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickCourtsideCard(SwanPalette c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SwanSpace.md),
      child: Container(
        padding: const EdgeInsets.all(SwanSpace.md),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(SwanRadius.lg),
          border: Border.all(color: c.line),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(SwanRadius.md),
                  ),
                  child: Icon(Icons.fitness_center_rounded, size: 20, color: c.accent),
                ),
                const SizedBox(width: SwanSpace.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Toplu Antrenman Odası',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: c.ink,
                      ),
                    ),
                    Text(
                      'Bu akşam 19:30 · 14 sporcu katılıyor',
                      style: SwanType.caption(c.inkMuted),
                    ),
                  ],
                ),
              ],
            ),
            FilledButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Toplu Antrenman Odasına katılımınız kaydedildi.')),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: c.accent,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SwanRadius.sm)),
              ),
              child: Text(
                'Katıl',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Birebir sohbet ekranı (Google Stitch Screen 22).
///
/// Google Stitch "SwanSport - Sohbet Detayı (Mert Koç)" tasarımını uygular:
/// - Instagram DM / Sporcu sohbet üst çubuğu
/// - Özel Antrenman Planı Kartı (A2 Kuvvet & Mobilite, RPE 8.5)
/// - Sesli Antrenör Mesajı & Simüle Dalga Formu
/// - Hızlı Etkileşim Hapları (Form Analizi İste, RPE Günlüğü, Makro Özeti)
/// - Medya, Antrenman ve Ses Kayıt Giriş Alanı
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.otherId, required this.otherName});

  final String otherId;
  final String otherName;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final List<MessageRow> _pending = [];
  final Set<String> _marked = {};
  bool _perMessageMarkUnavailable = false;
  bool _isRecordingVoice = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  String? _playingVoiceId;
  int _playbackSeconds = 0;
  Timer? _playbackTimer;

  @override
  void initState() {
    super.initState();
    OpenChat.open(widget.otherId, widget.otherName);
    Future.microtask(() async {
      await ref.read(notificationServiceProvider).markConversationRead(widget.otherId);
      if (mounted) ref.invalidate(conversationsProvider);
    });
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _playbackTimer?.cancel();
    OpenChat.close(widget.otherId);
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _markVisible(List<MessageRow> list) {
    final ids = list
        .where((m) => !m.isMine && !m.isRead && !_marked.contains(m.id))
        .map((m) => m.id)
        .toList();
    if (ids.isEmpty) return;
    _marked.addAll(ids);
    final svc = ref.read(notificationServiceProvider);

    Future.microtask(() async {
      try {
        if (_perMessageMarkUnavailable) {
          await svc.markConversationRead(widget.otherId);
        } else {
          await svc.markMessagesRead(ids);
        }
        if (mounted) ref.invalidate(conversationsProvider);
      } catch (_) {
        if (_perMessageMarkUnavailable) return;
        _perMessageMarkUnavailable = true;
        try {
          await svc.markConversationRead(widget.otherId);
          if (mounted) ref.invalidate(conversationsProvider);
        } catch (_) {}
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    await _deliver(text);
  }

  Future<void> _deliver(String text, {String? retryId}) async {
    final id = retryId ?? 'local-${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      _pending
        ..removeWhere((m) => m.id == id)
        ..add(MessageRow(
          id: id,
          body: text,
          createdAt: DateTime.now(),
          isMine: true,
          status: MessageStatus.sending,
        ));
    });
    _scrollToEnd();

    try {
      await ref.read(notificationServiceProvider).send(widget.otherId, text);
      if (mounted) setState(() => _pending.removeWhere((m) => m.id == id));
      ref.invalidate(conversationsProvider);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final i = _pending.indexWhere((m) => m.id == id);
        if (i >= 0) {
          _pending[i] = _pending[i].copyWith(status: MessageStatus.failed);
        }
      });
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _startVoiceRecording() {
    _recordTimer?.cancel();
    setState(() {
      _isRecordingVoice = true;
      _recordSeconds = 0;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _recordSeconds++);
    });
  }

  void _cancelVoiceRecording() {
    _recordTimer?.cancel();
    setState(() {
      _isRecordingVoice = false;
      _recordSeconds = 0;
    });
  }

  Future<void> _sendVoiceRecording() async {
    final duration = _recordSeconds == 0 ? 1 : _recordSeconds;
    _recordTimer?.cancel();
    setState(() {
      _isRecordingVoice = false;
      _recordSeconds = 0;
    });
    final minStr = (duration ~/ 60).toString();
    final secStr = (duration % 60).toString().padLeft(2, '0');
    await _deliver('🎙️ Sesli Mesaj ($minStr:$secStr)');
  }

  void _toggleVoicePlayback(String messageId, int totalDurationSec) {
    if (_playingVoiceId == messageId) {
      _playbackTimer?.cancel();
      setState(() {
        _playingVoiceId = null;
        _playbackSeconds = 0;
      });
      return;
    }

    _playbackTimer?.cancel();
    setState(() {
      _playingVoiceId = messageId;
      _playbackSeconds = 0;
    });

    _playbackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_playbackSeconds >= totalDurationSec) {
        timer.cancel();
        setState(() {
          _playingVoiceId = null;
          _playbackSeconds = 0;
        });
      } else {
        setState(() => _playbackSeconds++);
      }
    });
  }

  Future<void> _showAttachmentSheet(BuildContext context, SwanPalette c) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: 16),
              Text(
                'Ekle veya Paylaş',
                style: GoogleFonts.sora(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.photo_library_rounded, color: c.accent),
                ),
                title: Text('Fotoğraf / Belge', style: SwanType.body(c.ink, w: FontWeight.w600)),
                subtitle: Text('Görsel veya antrenman dokümanı seç', style: SwanType.caption(c.inkMuted)),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final f = await FilePicker.pickFile(type: FileType.any);
                    if (f != null) {
                      await _deliver('📎 [Ek: ${f.name}]');
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Dosya seçilemedi: $e')),
                      );
                    }
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.fitness_center_rounded, color: Color(0xFF6366F1)),
                ),
                title: Text('Antrenman Protokolü Paylaş', style: SwanType.body(c.ink, w: FontWeight.w600)),
                subtitle: Text('Aktif set, tekrar ve hedef şablonu gönder', style: SwanType.caption(c.inkMuted)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showWorkoutProtocolPicker(context, c);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bolt_rounded, color: Color(0xFF10B981)),
                ),
                title: Text('Hazırbulunuşluk & RPE Paylaş', style: SwanType.body(c.ink, w: FontWeight.w600)),
                subtitle: Text('Günlük toparlanma ve antrenman yükü özeti', style: SwanType.caption(c.inkMuted)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _deliver('⚡ Günlük Hazırbulunuşluk: %92 • Hedef RPE: 8.0 • Toparlanma: Optimum');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWorkoutProtocolPicker(BuildContext context, SwanPalette c) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Protokol Seçin',
                style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: c.ink),
              ),
              const SizedBox(height: 12),
              _protocolTile('A1 Kuvvet & Hipertrofi', '4 Set x 6-8 Tekrar • RPE 8.5 • 180s Dinlenme', ctx),
              _protocolTile('Mobilite & Dinamik Esneme', '15 Dk Kalça & Omuz Aktivasyonu • RPE 5.0', ctx),
              _protocolTile('Kondisyon & Laktat Eşiği', '6x400m Koşu • 90s Dinlenme • Zone 4', ctx),
            ],
          ),
        ),
      ),
    );
  }

  Widget _protocolTile(String title, String desc, BuildContext ctx) {
    final c = ctx.swan;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: SwanType.body(c.ink, w: FontWeight.w700)),
      subtitle: Text(desc, style: SwanType.caption(c.inkMuted)),
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: c.inkMuted),
      onTap: () {
        Navigator.pop(ctx);
        _deliver('🏋️ Antrenman Protokolü: $title\n$desc');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final async = ref.watch(chatProvider(widget.otherId));

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: [
                _buildChatHeader(c),
                Expanded(
                  child: async.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => premiumError(context, '$e'),
                    data: (list) {
                      _markVisible(list);
                      final all = [...list, ..._pending];

                      if (all.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: c.surfaceAlt,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.chat_bubble_outline_rounded, size: 28, color: c.accent),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Henüz Mesaj Yok',
                                  style: GoogleFonts.sora(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: c.ink,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${widget.otherName} ile antrenman veya program detaylarını konuşmaya başlayın.',
                                  textAlign: TextAlign.center,
                                  style: SwanType.bodySm(c.inkMuted),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scroll,
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                        itemCount: all.length,
                        itemBuilder: (_, i) => _bubble(c, all[all.length - 1 - i]),
                      );
                    },
                  ),
                ),

                // Interactive Quick Chips Row
                _buildQuickActionChips(c),

                // Bottom Message Input Bar
                _buildInputBar(c),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatHeader(SwanPalette c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SwanSpace.sm, vertical: 8),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: c.ink),
                tooltip: 'Geri',
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: c.accent.withValues(alpha: 0.15),
                    child: Text(
                      widget.otherName.isNotEmpty ? widget.otherName[0].toUpperCase() : '?',
                      style: GoogleFonts.sora(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: c.accent,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: c.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.surface, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.otherName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.verified_rounded, size: 14, color: c.accent),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Sporcu Sohbeti • Çevrim İçi',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: c.accent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sesli arama başlatılıyor...')),
                  );
                },
                icon: Icon(Icons.call_rounded, size: 20, color: c.ink),
                tooltip: 'Ara',
              ),
              IconButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Görüntülü arama başlatılıyor...')),
                  );
                },
                icon: Icon(Icons.videocam_rounded, size: 22, color: c.ink),
                tooltip: 'Görüntülü Ara',
              ),
              IconButton(
                onPressed: () => Navigator.pushNamed(context, '/profil', arguments: widget.otherId),
                icon: Icon(Icons.info_outline_rounded, size: 20, color: c.ink),
                tooltip: 'Profil',
              ),
            ],
          ),
        ],
      ),
    );
  }



  Widget _buildQuickActionChips(SwanPalette c) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: SwanSpace.md, vertical: 6),
      child: Row(
        children: [
          _buildActionChip(c, 'Form Analizi İste +', Icons.video_library_rounded, () {
            Navigator.pushNamed(context, '/antrenman-sonuc');
          }),
          const SizedBox(width: 6),
          _buildActionChip(c, 'RPE Günlüğü Paylaş', Icons.insert_chart_rounded, () {
            Navigator.pushNamed(context, '/hazirbulunusluk');
          }),
          const SizedBox(width: 6),
          _buildActionChip(c, 'Makro Özeti', Icons.restaurant_rounded, () {
            Navigator.pushNamed(context, '/beslenme');
          }),
        ],
      ),
    );
  }

  Widget _buildActionChip(SwanPalette c, String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: c.accent),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: c.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(SwanPalette c) {
    if (_isRecordingVoice) {
      final minStr = (_recordSeconds ~/ 60).toString();
      final secStr = (_recordSeconds % 60).toString().padLeft(2, '0');
      return Container(
        padding: const EdgeInsets.fromLTRB(SwanSpace.md, 10, SwanSpace.md, 14),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.line)),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: _cancelVoiceRecording,
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
              tooltip: 'İptal Et',
            ),
            const SizedBox(width: 6),
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$minStr:$secStr',
              style: GoogleFonts.sora(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: c.ink,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: SizedBox(
                height: 24,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(16, (i) {
                    final h = 6.0 + ((i * 7 + _recordSeconds * 5) % 18);
                    return Container(
                      width: 3,
                      height: h,
                      decoration: BoxDecoration(
                        color: c.accent.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: _sendVoiceRecording,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [kTealBright, kTeal]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(SwanSpace.md, 6, SwanSpace.md, 12),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _showAttachmentSheet(context, c),
            icon: Icon(Icons.add_circle_outline_rounded, size: 22, color: c.inkMuted),
            tooltip: 'Medya veya antrenman ekle',
          ),
          Expanded(
            child: TextField(
              controller: _ctrl,
              minLines: 1,
              maxLines: 4,
              style: SwanType.bodySm(c.ink),
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Mesaj yaz veya antrenman ekle...',
                hintStyle: SwanType.bodySm(c.inkMuted),
                filled: true,
                fillColor: c.surfaceAlt,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: _startVoiceRecording,
            icon: Icon(Icons.mic_rounded, size: 22, color: c.accent),
            tooltip: 'Sesli mesaj kaydet',
          ),
          InkWell(
            onTap: _send,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [kTealBright, kTeal]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(SwanPalette c, MessageRow m) {
    final isVoice = m.body.startsWith('🎙️ Sesli Mesaj');

    int durationSec = 8;
    if (isVoice) {
      final match = RegExp(r'\((\d+):(\d+)\)').firstMatch(m.body);
      if (match != null) {
        final min = int.tryParse(match.group(1) ?? '0') ?? 0;
        final sec = int.tryParse(match.group(2) ?? '8') ?? 8;
        durationSec = min * 60 + sec;
        if (durationSec == 0) durationSec = 8;
      }
    }

    final isPlaying = _playingVoiceId == m.id;
    final currentSec = isPlaying ? _playbackSeconds : 0;
    final curMinStr = (currentSec ~/ 60).toString();
    final curSecStr = (currentSec % 60).toString().padLeft(2, '0');
    final totMinStr = (durationSec ~/ 60).toString();
    final totSecStr = (durationSec % 60).toString().padLeft(2, '0');

    return Align(
      alignment: m.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: m.status == MessageStatus.failed ? () => _deliver(m.body, retryId: m.id) : null,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: m.isMine ? const LinearGradient(colors: [kTealBright, kTeal]) : null,
            color: m.isMine ? null : c.surfaceAlt,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(m.isMine ? 16 : 4),
              bottomRight: Radius.circular(m.isMine ? 4 : 16),
            ),
            border: m.isMine ? null : Border.all(color: c.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (m.isShare && m.sharedId != null)
                SharedContentCard(
                  kind: m.sharedKind ?? m.contentType,
                  id: m.sharedId!,
                  onDark: m.isMine,
                ),
              if (isVoice) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => _toggleVoicePlayback(m.id, durationSec),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: m.isMine ? Colors.white.withValues(alpha: 0.2) : c.accent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: m.isMine ? Colors.white : c.accent,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 130,
                          height: 20,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(14, (idx) {
                              final active = isPlaying && ((idx / 14) <= (currentSec / durationSec));
                              final h = 5.0 + ((idx * 6 + 3) % 15);
                              return Container(
                                width: 3,
                                height: h,
                                decoration: BoxDecoration(
                                  color: m.isMine
                                      ? (active ? Colors.white : Colors.white54)
                                      : (active ? c.accent : c.inkMuted.withValues(alpha: 0.4)),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isPlaying ? '$curMinStr:$curSecStr / $totMinStr:$totSecStr' : '$totMinStr:$totSecStr • Sesli Mesaj',
                          style: SwanType.caption(m.isMine ? Colors.white70 : c.inkMuted, w: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ] else if (m.body.isNotEmpty) ...[
                Text(
                  m.body,
                  style: SwanType.bodySm(m.isMine ? Colors.white : c.ink).copyWith(height: 1.35),
                ),
              ],
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    m.status == MessageStatus.failed
                        ? 'Gönderilemedi · dokun, tekrar dene'
                        : shortAgo(m.createdAt),
                    style: SwanType.caption(m.isMine ? Colors.white70 : c.inkMuted, w: FontWeight.w600),
                  ),
                  if (m.isMine) ...[
                    const SizedBox(width: 5),
                    _tick(m),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tick(MessageRow m) => switch (m.status) {
        MessageStatus.sending => const SizedBox(
            width: 11,
            height: 11,
            child: CircularProgressIndicator(strokeWidth: 1.4, color: Colors.white70),
          ),
        MessageStatus.failed => const Icon(Icons.refresh_rounded, size: 13, color: Colors.white),
        MessageStatus.sent => Icon(
            m.isRead ? Icons.done_all_rounded : Icons.done_rounded,
            size: 13,
            color: m.isRead ? Colors.white : Colors.white60,
          ),
      };
}
