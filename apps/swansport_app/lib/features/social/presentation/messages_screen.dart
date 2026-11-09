import 'package:swansport_app/app/widgets/swan_scaffold.dart';
import '../../../app/widgets/action_gate.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/navigation/swan_back_navigation.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/shared_content_card.dart';
import '../../../app/push/push_service.dart';
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
    required this.kindLabel,
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
  final String kindLabel;
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
    'Kişiler',
    'Topluluklar',
  ];

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialTab == 1 ? 2 : 0;
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
                    error: (_, __) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(SwanSpace.lg),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Mesajlar yüklenemedi.',
                              style: SwanType.body(c.ink, w: FontWeight.w700),
                            ),
                            const SizedBox(height: SwanSpace.sm),
                            TextButton.icon(
                              onPressed: () {
                                ref.invalidate(conversationsProvider);
                                ref.invalidate(communityListProvider);
                              },
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Tekrar dene'),
                            ),
                          ],
                        ),
                      ),
                    ),
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
        leading: SwanBackNavigation.shouldShow(context)
            ? SwanHeaderIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                tooltip: 'Geri dön',
                onPressed: () => SwanBackNavigation.back(context),
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
              icon: Icon(Icons.edit_square, size: 19, color: c.accent),
              tooltip: 'Yeni Sohbet',
              onPressed: () => Navigator.pushNamed(context, '/ara'),
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

    // Real Supabase DMs
    for (final dm in dms) {
      items.add(_ChatItemDisplay(
        id: dm.otherId,
        title: dm.otherName,
        subtitle: dm.lastBody,
        time: _formatDate(dm.lastAt),
        unread: dm.unread,
        kind: 'coach',
        kindLabel: 'Birebir',
        avatarUrl: dm.otherAvatarUrl,
        initials: dm.initials,
        onTap: () => Navigator.pushNamed(context, '/sohbet', arguments: {
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
        kindLabel: g.isFederation ? 'Federasyon' : 'Topluluk',
        unread: g.unread,
        initials: g.name.characters.take(2).toString(),
        avatarWidget: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: g.isFederation ? c.surface : c.surfaceAlt,
            border:
                Border.all(color: c.accent.withValues(alpha: 0.3), width: 1),
          ),
          child: Center(
            child: Icon(
              g.isFederation ? Icons.shield_outlined : Icons.group_rounded,
              color: g.isFederation ? c.ink : c.accent,
              size: 24,
            ),
          ),
        ),
        onTap: () => Navigator.pushNamed(
          context,
          g.isFederation ? '/federasyon' : '/topluluk',
          arguments: {'id': g.id, 'name': g.name},
        ),
      ));
    }

    // Filter by category
    List<_ChatItemDisplay> filtered = items;
    if (_selectedFilter == 1) {
      filtered = filtered.where((i) => i.kind == 'coach').toList();
    } else if (_selectedFilter == 2) {
      filtered = filtered.where((i) => i.kind != 'coach').toList();
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
                    : _selectedFilter == 0
                        ? 'Henüz mesajınız yok'
                        : 'Bu bölümde sohbet yok',
                style: SwanType.h3(c.ink).copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                _query.isNotEmpty
                    ? 'Farklı bir arama yapabilir veya yeni bir sohbet başlatabilirsiniz.'
                    : _selectedFilter == 0
                        ? 'Takım arkadaşlarınızla veya antrenörünüzle iletişime geçmek için yeni bir sohbet başlatın.'
                        : 'Diğer konuşmalarınızı görmek için Tümü bölümüne dönebilirsiniz.',
                textAlign: TextAlign.center,
                style: SwanType.caption(c.inkMuted),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/ara'),
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
    return Semantics(
      button: true,
      label: '${item.kindLabel} sohbeti, ${item.title}',
      value: item.unread > 0 ? '${item.unread} okunmamış mesaj' : null,
      child: InkWell(
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: SwanSpace.md, vertical: 10),
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
                      style: SwanType.body(
                        c.ink,
                        w: item.unread > 0 ? FontWeight.w800 : FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: '${item.kindLabel} · ',
                          style: SwanType.caption(
                            item.unread > 0 ? c.accent : c.inkMuted,
                            w: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: item.subtitle,
                          style: SwanType.caption(
                            item.unread > 0 ? c.ink : c.inkMuted,
                            w: item.unread > 0
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ]),
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
                                style: SwanType.caption(
                                  c.onAccent,
                                  w: FontWeight.w800,
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
  bool _checkingSend = false;
  Future<void> _sendQueue = Future<void>.value();
  @override
  void initState() {
    super.initState();
    _openConversation(widget.otherId, widget.otherName);
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.otherId == widget.otherId) return;
    OpenChat.close(oldWidget.otherId);
    _ctrl.clear();
    _pending.clear();
    _marked.clear();
    _perMessageMarkUnavailable = false;
    _checkingSend = false;
    _sendQueue = Future<void>.value();
    _openConversation(widget.otherId, widget.otherName);
  }

  void _openConversation(String otherId, String otherName) {
    OpenChat.open(otherId, otherName);
    Future.microtask(() async {
      await ref.read(notificationServiceProvider).markConversationRead(otherId);
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
    final draft = _ctrl.text;
    final text = draft.trim();
    if (_checkingSend || text.isEmpty) return;
    setState(() => _checkingSend = true);
    try {
      if (!await requireSwanAction(context, ref, SwanAction.message) ||
          !mounted) {
        return;
      }
      if (_ctrl.text == draft) _ctrl.clear();
      _deliver(text);
    } finally {
      if (mounted) setState(() => _checkingSend = false);
    }
  }

  void _deliver(String text, {String? retryId}) {
    final recipientId = widget.otherId;
    final id = retryId ?? NotificationService.newMessageId();
    setState(() {
      final existing = _pending.indexWhere((m) => m.id == id);
      final message = MessageRow(
        id: id,
        body: text,
        createdAt: DateTime.now(),
        isMine: true,
        status: MessageStatus.sending,
      );
      if (existing < 0) {
        _pending.add(message);
      } else {
        _pending[existing] = message;
      }
    });
    _scrollToEnd();
    final service = ref.read(notificationServiceProvider);
    _sendQueue = _sendQueue.then((_) async {
      try {
        final sent = await service.send(
          recipientId,
          text,
          messageId: id,
        );
        if (!mounted || widget.otherId != recipientId) return;
        setState(() {
          final index = _pending.indexWhere((m) => m.id == id);
          if (index >= 0) _pending[index] = sent;
        });
        ref.invalidate(conversationsProvider);
      } catch (_) {
        if (!mounted || widget.otherId != recipientId) return;
        setState(() {
          final index = _pending.indexWhere((m) => m.id == id);
          if (index >= 0) {
            _pending[index] =
                _pending[index].copyWith(status: MessageStatus.failed);
          }
        });
      }
    });
  }

  List<MessageRow> _visibleMessages(List<MessageRow> serverMessages) {
    final byId = {for (final message in serverMessages) message.id: message};
    for (final pending in _pending) {
      final serverHasMessage = byId.containsKey(pending.id);
      if (!serverHasMessage || pending.status != MessageStatus.sent) {
        byId[pending.id] = pending;
      }
    }
    return byId.values.toList()
      ..sort((a, b) {
        final byTime = a.createdAt.compareTo(b.createdAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
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
                    error: (_, __) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(SwanSpace.lg),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Mesajlar yüklenemedi.',
                              style: SwanType.body(c.ink, w: FontWeight.w700),
                            ),
                            const SizedBox(height: SwanSpace.sm),
                            TextButton.icon(
                              onPressed: () => ref.invalidate(
                                chatProvider(widget.otherId),
                              ),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Tekrar dene'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    data: (list) {
                      _markVisible(list);
                      final all = _visibleMessages(list);

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
                onPressed: () => Navigator.maybePop(context),
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
                  Text(
                    widget.otherName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                  ),
                  Text('Birebir sohbet', style: SwanType.caption(c.inkMuted)),
                ],
              )),
            ],
          )),
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pushNamed(context, '/profil',
                    arguments: widget.otherId),
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
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            minLines: 1,
            maxLines: 5,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Mesaj yaz…'),
          ),
        ),
        const SizedBox(width: 6),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _ctrl,
          builder: (context, value, _) => IconButton.filled(
            tooltip: _checkingSend ? 'Gönderim hazırlanıyor' : 'Gönder',
            onPressed:
                _checkingSend || value.text.trim().isEmpty ? null : _send,
            icon: _checkingSend
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
            style: IconButton.styleFrom(
              backgroundColor: c.accentFill,
              foregroundColor: c.onAccent,
              disabledBackgroundColor: c.surfaceAlt,
              disabledForegroundColor: c.inkMuted,
            ),
          ),
        ),
      ]));

  Widget _bubble(SwanPalette c, MessageRow m) {
    final direction = m.isMine ? 'Gönderilen' : 'Gelen';
    return Semantics(
      label: '$direction mesaj, ${m.body}',
      button: m.status == MessageStatus.failed,
      hint: m.status == MessageStatus.failed
          ? 'Tekrar göndermek için dokun'
          : null,
      child: Align(
        alignment: m.isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: LayoutBuilder(
          builder: (context, constraints) => GestureDetector(
            onTap: m.status == MessageStatus.failed
                ? () => _deliver(m.body, retryId: m.id)
                : null,
            child: Container(
              constraints: BoxConstraints(
                maxWidth:
                    (constraints.maxWidth * .78).clamp(220, 420).toDouble(),
              ),
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
                      style: SwanType.bodySm(
                              m.isMine ? context.swan.onAccent : c.ink)
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
