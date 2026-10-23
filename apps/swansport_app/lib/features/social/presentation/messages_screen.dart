import '../../../app/navigation/app_routes.dart';
import '../../../app/navigation/swan_navigation.dart';
import '../../../app/widgets/swan_scaffold.dart';
import '../../../app/widgets/action_gate.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/shared_content_card.dart';
import '../../../app/push/push_service.dart';
import '../../../app/widgets/premium.dart';
import 'widgets/social_widgets.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../../app/widgets/swan_floating_header.dart';

/// Gruplar ve birebir sohbetler; katılım ve mesajlar gerçek kayıtlardan okunur.
class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({this.initialTab = 0, super.key});

  final int initialTab;

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _ChatItemDisplay {
  const _ChatItemDisplay({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.kind, // 'group', 'club', 'coach'
    this.unread = 0,
    this.avatarUrl,
    this.avatarWidget,
    this.initials = '',
    required this.onTap,
  });

  final String id;
  final String title;
  final String subtitle;
  final String time;
  final String kind;
  final int unread;
  final String? avatarUrl;
  final Widget? avatarWidget;
  final String initials;
  final VoidCallback onTap;
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  late int _selectedFilter;

  final List<String> _filters = const [
    'Tümü',
    'Gruplar',
    'Kulüpler',
    'Antrenörler',
  ];

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialTab == 1 ? 1 : 0;
    Future.microtask(() async {
      if (!mounted || !ref.read(isSupabaseEnabledProvider)) return;
      try {
        await ref.read(communityServiceProvider).ensureMine();
        if (mounted) ref.invalidate(communityListProvider);
      } catch (_) {
        // Existing conversations remain readable when channel enrollment fails.
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0 && now.day == dt.day) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } else if (diff.inDays < 2 && now.day - dt.day == 1) {
      return 'Dün';
    } else if (diff.inDays < 7) {
      const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
      return days[dt.weekday - 1];
    } else {
      const months = [
        'Oca',
        'Şub',
        'Mar',
        'Nis',
        'May',
        'Haz',
        'Tem',
        'Ağu',
        'Eyl',
        'Eki',
        'Kas',
        'Ara'
      ];
      return '${dt.day} ${months[dt.month - 1]}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;

    ref.listen(dmChangesProvider, (_, next) {
      if (next is AsyncData) ref.invalidate(conversationsProvider);
    });

    final dms = ref.watch(conversationsProvider);
    final groups = ref.watch(communityListProvider).valueOrNull ?? const [];

    return SwanScaffold(
      extendBody: true,
      scrollUnderHeader: true,
      backgroundColor: c.bg,
      header: _buildHeader(c),
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
                padding: const EdgeInsets.fromLTRB(0, 0, 0, SwanSpace.xl * 5),
                children: [
                  const SwanHeaderSpacer(),
                  const SizedBox(height: SwanSpace.xs),
                  _buildSearchField(c),
                  const SizedBox(height: 12),
                  _buildCategoryFilters(c),
                  const SizedBox(height: 10),
                  dms.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(SwanSpace.lg),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => premiumError(context, '$e'),
                    data: (list) => _buildChatRoster(c, list, groups),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _buildHeader(SwanPalette c) => SwanFloatingHeader(
        leading: Navigator.canPop(context)
            ? SwanHeaderIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                tooltip: 'Geri dön',
                onPressed: () => context.swanPop(),
              )
            : null,
        title: Text(
          'Mesajlar',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: SwanType.h2(c.ink).copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.person_add_alt_1_outlined,
                  size: 20, color: c.accent),
              tooltip: 'Yeni Grup veya Kişi',
              onPressed: () => context.swanPush(AppRoutes.search),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.edit_square, size: 19, color: c.accent),
              tooltip: 'Yeni Sohbet',
              onPressed: () => context.swanPush(AppRoutes.search),
            ),
          ),
        ],
      );

  Widget _buildSearchField(SwanPalette c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SwanSpace.md),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _query = v.trim()),
          style: SwanType.bodySm(c.ink),
          decoration: InputDecoration(
            hintText: 'Kişi, grup veya kulüp ara...',
            hintStyle: SwanType.bodySm(c.inkMuted),
            prefixIcon: Icon(Icons.search_rounded, size: 21, color: c.inkMuted),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon:
                        Icon(Icons.close_rounded, size: 16, color: c.inkMuted),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilters(SwanPalette c) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: SwanSpace.md),
      child: Row(
        children: _filters.asMap().entries.map((entry) {
          final idx = entry.key;
          final label = entry.value;
          final isSelected = _selectedFilter == idx;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _selectedFilter = idx),
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? c.accentFill : c.surfaceAlt,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: SwanType.caption(
                      isSelected ? c.onAccent : c.inkMuted,
                      w: isSelected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChatRoster(
      SwanPalette c, List<ConversationRow> dms, List<CommunityRow> groups) {
    final List<_ChatItemDisplay> items = [];

    if (ref.watch(featureEnabledProvider(FeatureFlags.swanAssistant))) {
      items.add(
        _ChatItemDisplay(
          id: 'swan-assistant',
          title: 'Swan Asistan',
          subtitle: 'Uygulama, etkinlik ve sporcu işlemlerinde yardım',
          time: '',
          kind: 'assistant',
          avatarWidget: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.accent.withValues(alpha: .12),
            ),
            child: Center(
              child: Icon(Icons.assistant_rounded, color: c.accent, size: 24),
            ),
          ),
          onTap: () => context.swanPush(AppRoutes.aiAssistant),
        ),
      );
    }

    // Real Supabase DMs
    for (final dm in dms) {
      items.add(_ChatItemDisplay(
        id: dm.otherId,
        title: dm.otherName,
        subtitle: dm.lastBody,
        time: _formatDate(dm.lastAt),
        unread: dm.unread,
        kind: 'coach',
        avatarUrl: dm.otherAvatarUrl,
        initials: dm.initials,
        onTap: () => context.swanPush(AppRoutes.directMessage, extra: {
          'id': dm.otherId,
          'name': dm.otherName,
        }),
      ));
    }

    // Real Joined Groups
    for (final g in groups.where((g) => g.joined)) {
      items.add(_ChatItemDisplay(
        id: g.id,
        title: g.name,
        subtitle: g.lastBody?.trim().isNotEmpty == true
            ? g.lastBody!
            : '${g.memberCount} üye',
        time: _formatDate(g.lastAt),
        kind: g.isFederation ? 'club' : 'group',
        initials: g.name.characters.take(2).toString(),
        avatarWidget: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: g.isFederation ? Colors.white : c.surfaceAlt,
            border:
                Border.all(color: c.accent.withValues(alpha: 0.3), width: 1),
          ),
          child: Center(
            child: Icon(
              g.isFederation ? Icons.shield_outlined : Icons.group_rounded,
              color: g.isFederation ? const Color(0xFF131D2E) : c.accent,
              size: 24,
            ),
          ),
        ),
        onTap: () => context.swanPush(
          g.isFederation ? AppRoutes.federation : AppRoutes.community,
          extra: {'id': g.id, 'name': g.name},
        ),
      ));
    }

    // Filter by category
    List<_ChatItemDisplay> filtered = items;
    if (_selectedFilter == 1) {
      filtered = filtered.where((i) => i.kind == 'group').toList();
    } else if (_selectedFilter == 2) {
      filtered = filtered.where((i) => i.kind == 'club').toList();
    } else if (_selectedFilter == 3) {
      filtered = filtered.where((i) => i.kind == 'coach').toList();
    }

    // Filter by query
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      filtered = filtered
          .where((i) =>
              i.title.toLowerCase().contains(q) ||
              i.subtitle.toLowerCase().contains(q))
          .toList();
    }

    if (filtered.isEmpty) {
      return Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: SwanSpace.md, vertical: 48),
        child: Center(
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.chat_bubble_outline_rounded,
                    size: 28, color: c.accent),
              ),
              const SizedBox(height: 14),
              Text(
                _query.isNotEmpty
                    ? 'Eşleşen sohbet bulunamadı'
                    : 'Henüz mesajınız yok',
                style: SwanType.h3(c.ink).copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                _query.isNotEmpty
                    ? 'Farklı bir arama yapabilir veya yeni bir sohbet başlatabilirsiniz.'
                    : 'Antrenörünüzle veya takım arkadaşlarınızla iletişime geçmek için yeni bir sohbet başlatın.',
                textAlign: TextAlign.center,
                style: SwanType.caption(c.inkMuted),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => context.swanPush(AppRoutes.search),
                icon: Icon(Icons.person_search_rounded,
                    size: 16, color: c.onAccent),
                label: const Text('Kullanıcı Ara & Sohbet Başlat'),
                style: FilledButton.styleFrom(
                  backgroundColor: c.accentFill,
                  foregroundColor: c.onAccent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SwanRadius.md)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final item in filtered) _buildConversationRow(c, item),
      ],
    );
  }

  Widget _buildAvatar(SwanPalette c, _ChatItemDisplay item) {
    if (item.avatarWidget != null) {
      return item.avatarWidget!;
    }
    if (item.avatarUrl != null && item.avatarUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          item.avatarUrl!,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => GradientAvatar(
            initials: item.initials.isNotEmpty
                ? item.initials
                : (item.title.isNotEmpty ? item.title[0].toUpperCase() : '?'),
            size: 52,
            radius: 26,
            gradientIndex: item.title.length % 4,
          ),
        ),
      );
    }
    return GradientAvatar(
      initials: item.initials.isNotEmpty
          ? item.initials
          : (item.title.isNotEmpty ? item.title[0].toUpperCase() : '?'),
      size: 52,
      radius: 26,
      gradientIndex: item.title.length % 4,
    );
  }

  Widget _buildConversationRow(SwanPalette c, _ChatItemDisplay item) {
    return InkWell(
      onTap: item.onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: SwanSpace.md, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: _buildAvatar(c, item),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    style: SwanType.body(c.ink, w: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.subtitle,
                    style: SwanType.caption(c.inkMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.time,
                      style: SwanType.caption(c.inkMuted, w: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (item.unread > 0)
                          Container(
                            constraints: const BoxConstraints(
                                minWidth: 20, minHeight: 20),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: c.accentFill,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${item.unread}',
                              style: SwanType.caption(c.onAccent,
                                      w: FontWeight.w800)
                                  .copyWith(
                                fontSize: 11,
                                height: 1.1,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: c.inkMuted.withValues(alpha: 0.35),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
  @override
  void initState() {
    super.initState();
    OpenChat.open(widget.otherId, widget.otherName);
    Future.microtask(() async {
      await ref
          .read(notificationServiceProvider)
          .markConversationRead(widget.otherId);
      if (mounted) ref.invalidate(conversationsProvider);
    });
  }

  @override
  void dispose() {
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
    if (!await requireSwanAction(context, ref, SwanAction.message) || !mounted)
      return;
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    await _deliver(text);
  }

  Future<void> _deliver(String text, {String? retryId}) async {
    if (!await requireSwanAction(context, ref, SwanAction.message) || !mounted)
      return;
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

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final async = ref.watch(chatProvider(widget.otherId));

    return SwanScaffold(
      backgroundColor: c.bg,
      header: _buildChatHeader(c),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: [
                Expanded(
                  child: async.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
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
                                  child: Icon(Icons.chat_bubble_outline_rounded,
                                      size: 28, color: c.accent),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Henüz Mesaj Yok',
                                  style: SwanType.h3(c.ink)
                                      .copyWith(fontWeight: FontWeight.w700),
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
                        itemBuilder: (_, i) =>
                            _bubble(c, all[all.length - 1 - i]),
                      );
                    },
                  ),
                ),

                // Interactive Quick Chips Row

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
      padding:
          const EdgeInsets.symmetric(horizontal: SwanSpace.sm, vertical: 8),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
              child: Row(
            children: [
              IconButton(
                onPressed: () => context.swanPop(),
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: c.ink),
                tooltip: 'Geri',
              ),
              CircleAvatar(
                radius: 20,
                backgroundColor: c.surface,
                child: Text(
                  widget.otherName.isNotEmpty
                      ? widget.otherName[0].toUpperCase()
                      : '?',
                  style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.otherName,
                      style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
                  Text('Birebir sohbet', style: SwanType.caption(c.inkMuted)),
                ],
              )),
            ],
          )),
          Row(
            children: [
              IconButton(
                onPressed: () => context.swanPush(AppRoutes.profile,
                    extra: widget.otherId),
                icon: Icon(Icons.info_outline_rounded, size: 20, color: c.ink),
                tooltip: 'Profil',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(SwanPalette c) => Padding(
      padding: const EdgeInsets.fromLTRB(SwanSpace.md, 6, SwanSpace.md, 12),
      child: Row(children: [
        Expanded(
            child: TextField(
                controller: _ctrl,
                minLines: 1,
                maxLines: 4,
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(hintText: 'Mesaj yaz…'))),
        IconButton(
            tooltip: 'Gönder',
            onPressed: _send,
            icon: Icon(Icons.send_rounded, color: c.accent)),
      ]));

  Widget _bubble(SwanPalette c, MessageRow m) {
    return Align(
      alignment: m.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: m.status == MessageStatus.failed
            ? () => _deliver(m.body, retryId: m.id)
            : null,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: m.isMine
                ? LinearGradient(colors: [c.accentFill, c.accentFill])
                : null,
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
              if (m.body.isNotEmpty) ...[
                Text(
                  m.body,
                  style:
                      SwanType.bodySm(m.isMine ? context.swan.onAccent : c.ink)
                          .copyWith(height: 1.35),
                ),
              ],
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                      child: Text(
                    m.status == MessageStatus.failed
                        ? 'Gönderilemedi · dokun, tekrar dene'
                        : shortAgo(m.createdAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SwanType.caption(
                        m.isMine ? context.swan.onAccent : c.inkMuted,
                        w: FontWeight.w600),
                  )),
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
        MessageStatus.sending => SizedBox(
            width: 11,
            height: 11,
            child: CircularProgressIndicator(
                strokeWidth: 1.4, color: context.swan.onAccent),
          ),
        MessageStatus.failed =>
          Icon(Icons.refresh_rounded, size: 13, color: context.swan.onAccent),
        MessageStatus.sent => Icon(
            m.isRead ? Icons.done_all_rounded : Icons.done_rounded,
            size: 13,
            color: m.isRead
                ? context.swan.onAccent
                : context.swan.onAccent.withValues(alpha: .6),
          ),
      };
}
