import 'package:swansport_app/app/widgets/swan_scaffold.dart';
import '../../../app/widgets/action_gate.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_core/swansport_core.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/push/push_service.dart';
import '../../../app/widgets/premium.dart';
import 'widgets/social_widgets.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../../app/widgets/swan_floating_header.dart';
import '../../../app/widgets/chat_composer.dart';
import '../../../app/widgets/swan_tabs.dart';
import 'widgets/chat_presentation.dart';
import 'widgets/chat_timeline.dart';

/// Gruplar ve birebir sohbetler; katılım ve mesajlar gerçek kayıtlardan okunur.
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
  int _selectedFilter = 0; // 0 = Tüm Mesajlar, 1 = Birebir, 2 = Topluluklar

  final List<String> _filters = const ['Tümü', 'Birebir', 'Topluluklar'];

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
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(0, 0, 0, SwanSpace.xl * 5),
                children: [
                  const SwanHeaderSpacer(),
                  const SizedBox(height: SwanSpace.sm),

                  _buildSearchField(c),
                  const SizedBox(height: SwanSpace.md),

                  _buildCategoryFilters(c),
                  const SizedBox(height: SwanSpace.sm),

                  // Real conversations only; no suggested/mock chat roster.
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

  Widget _buildHeader(SwanPalette c) => SwanFloatingHeader(
        leading: Navigator.canPop(context)
            ? SwanHeaderIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                tooltip: 'Geri dön',
                onPressed: () => Navigator.maybePop(context))
            : null,
        title: Text('Mesajlar',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SwanType.h2(c.ink)),
        actions: [
          SwanHeaderIconButton(
              icon: Icons.edit_square,
              tooltip: 'Yeni Sohbet',
              onPressed: () => Navigator.pushNamed(context, '/ara'))
        ],
      );

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
            hintText: 'Sohbetlerde ara…',
            hintStyle: SwanType.bodySm(c.inkMuted),
            prefixIcon: Icon(Icons.search_rounded, size: 20, color: c.inkMuted),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: Icon(Icons.close_rounded, size: 16),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: SwanSpace.md, vertical: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilters(SwanPalette c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SwanSpace.md),
      child: SwanPillTabs(
          labels: _filters,
          selected: _selectedFilter,
          onSelect: (index) => setState(() => _selectedFilter = index)),
    );
  }

  Widget _buildChatRoster(
      SwanPalette c, List<ConversationRow> dms, List<CommunityRow> groups) {
    final filteredGroups = groups.where((g) => g.joined).toList();
    final entries = <_Entry>[
      for (final g in filteredGroups) _Entry.group(g),
      for (final dm in dms) _Entry.dm(dm),
    ];
    entries.removeWhere((e) =>
        (_selectedFilter == 1 && e.dm == null) ||
        (_selectedFilter == 2 && e.group == null) ||
        !trContains(e.group?.name ?? e.dm!.otherName, _query));
    entries.sort(
        (a, b) => (b.at ?? DateTime(1970)).compareTo(a.at ?? DateTime(1970)));

    if (entries.isEmpty) {
      return Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: SwanSpace.md, vertical: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(SwanRadius.lg),
            border: Border.all(color: c.line),
          ),
          child: Column(
            children: [
              Icon(Icons.chat_bubble_outline_rounded,
                  size: 48, color: c.accent),
              const SizedBox(height: 12),
              Text(
                _query.isNotEmpty ? 'Sohbet bulunamadı' : 'Henüz mesajınız yok',
                style: SwanType.h3(c.ink).copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Antrenörünüzle veya takım arkadaşlarınızla iletişime geçmek için yeni bir sohbet başlatın.',
                textAlign: TextAlign.center,
                style: SwanType.caption(c.inkMuted),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/ara'),
                icon: Icon(Icons.search_rounded, size: 16, color: c.onAccent),
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SwanSpace.md),
      child: Column(
        children: [
          for (final e in entries)
            if (e.group != null &&
                (_selectedFilter == 0 || _selectedFilter == 2))
              _buildRealGroupTile(c, e.group!)
            else if (e.dm != null &&
                (_selectedFilter == 0 || _selectedFilter == 1))
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
        borderRadius: BorderRadius.circular(SwanRadius.md),
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
                      Expanded(
                          child: Text(g.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SwanType.body(c.ink, w: FontWeight.w700))),
                      if (g.lastAt != null)
                        Text(shortAgo(g.lastAt!),
                            style: SwanType.caption(c.inkMuted)),
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
        borderRadius: BorderRadius.circular(SwanRadius.md),
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
                      Expanded(
                          child: Text(dm.otherName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SwanType.body(c.ink, w: FontWeight.w700))),
                      Flexible(
                          child: Text(shortAgo(dm.lastAt),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SwanType.caption(c.inkMuted))),
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
                decoration: BoxDecoration(
                    color: c.accentFill,
                    borderRadius: BorderRadius.circular(999)),
                child: Text('${dm.unread}',
                    style: SwanType.caption(c.onAccent, w: FontWeight.w700)),
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
  final _search = TextEditingController();
  final List<MessageRow> _pending = [];
  final Set<String> _marked = {};
  final Set<String> _marking = {};
  final Set<String> _retrying = {};
  bool _searching = false;
  bool _gating = false;

  @override
  void initState() {
    super.initState();
    OpenChat.open(widget.otherId, widget.otherName);
  }

  @override
  void dispose() {
    OpenChat.close(widget.otherId);
    _ctrl.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _markVisible(List<ChatItem> visible) async {
    final ids = visible
        .where((item) =>
            !item.message.isMine &&
            !item.message.isRead &&
            !_marked.contains(item.message.id) &&
            !_marking.contains(item.message.id))
        .map((item) => item.message.id)
        .toList();
    if (ids.isEmpty || !mounted) return;
    _marking.addAll(ids);
    try {
      await ref.read(notificationServiceProvider).markMessagesRead(ids);
      if (!mounted) return;
      _marked.addAll(ids);
      ref.invalidate(conversationsProvider);
    } catch (_) {
      // Never fall back to marking the entire unseen conversation.
      // Retry on the next visibility/scroll update, not an unbounded timer.
    } finally {
      _marking.removeAll(ids);
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _gating) return;
    _gating = true;
    var allowed = false;
    try {
      allowed = await requireSwanAction(context, ref, SwanAction.message);
    } finally {
      _gating = false;
    }
    if (!allowed || !mounted) return;
    if (_ctrl.text.trim() == text) _ctrl.clear();
    await _deliver(text);
  }

  Future<void> _retry(String id) async {
    if (_retrying.contains(id)) return;
    final found =
        _pending.where((m) => m.id == id && m.status == MessageStatus.failed);
    if (found.isEmpty) return;
    final message = found.first;
    _retrying.add(id);
    try {
      if (!await requireSwanAction(context, ref, SwanAction.message) ||
          !mounted) return;
      await _deliver(message.body, retryId: id);
    } finally {
      _retrying.remove(id);
    }
  }

  Future<void> _deliver(String text, {String? retryId}) async {
    if (!mounted) return;
    final id = retryId ?? 'local-${DateTime.now().microsecondsSinceEpoch}';
    final existing = _pending.where((m) => m.id == id).firstOrNull;
    setState(() {
      _pending.removeWhere((m) => m.id == id);
      _pending.add(MessageRow(
          id: id,
          body: text,
          createdAt: existing?.createdAt ?? DateTime.now(),
          isMine: true,
          status: MessageStatus.sending));
    });
    try {
      await ref.read(notificationServiceProvider).send(widget.otherId, text);
      if (!mounted) return;
      setState(() => _pending.removeWhere((m) => m.id == id));
      ref.invalidate(conversationsProvider);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final index = _pending.indexWhere((m) => m.id == id);
        if (index >= 0)
          _pending[index] =
              _pending[index].copyWith(status: MessageStatus.failed);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final async = ref.watch(chatProvider(widget.otherId));
    final people = ref.watch(conversationsProvider).valueOrNull ??
        const <ConversationRow>[];
    final person = people.where((p) => p.otherId == widget.otherId).firstOrNull;
    final avatar = person?.otherAvatarUrl;
    void profile() =>
        Navigator.pushNamed(context, '/profil', arguments: widget.otherId);
    final identity = Row(children: [
      SocialAvatar(
          initials: person?.initials ??
              (widget.otherName.isEmpty
                  ? '?'
                  : widget.otherName.characters.first),
          imageUrl: avatar,
          size: SwanSpace.xl * 2,
          gradientIndex: widget.otherName.length % 4),
      const SizedBox(width: SwanSpace.md),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.otherName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SwanType.h3(c.ink)),
        Text('Birebir sohbet', style: SwanType.caption(c.inkMuted)),
      ])),
    ]);
    return SwanScaffold(
        backgroundColor: c.bg,
        header: Padding(
            padding: const EdgeInsets.all(SwanSpace.sm),
            child: Row(children: [
              IconButton(
                  tooltip: 'Geri dön',
                  onPressed: () => Navigator.maybePop(context),
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: c.ink)),
              Expanded(
                  child: InkWell(
                      onTap: profile,
                      borderRadius: BorderRadius.circular(SwanRadius.md),
                      child: Semantics(
                          button: true, label: 'Profili aç', child: identity))),
              IconButton(
                  tooltip: 'Sohbette ara',
                  onPressed: () => setState(() => _searching = !_searching),
                  icon: Icon(Icons.search_rounded, color: c.ink)),
            ])),
        body: SafeArea(
            top: false,
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(children: [
                      if (_searching)
                        Padding(
                            padding: const EdgeInsets.all(SwanSpace.md),
                            child: TextField(
                                controller: _search,
                                autofocus: true,
                                style: SwanType.body(c.ink),
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                    hintText: 'Yüklenen mesajlarda ara',
                                    prefixIcon:
                                        const Icon(Icons.search_rounded),
                                    suffixIcon: IconButton(
                                        tooltip: 'Aramayı kapat',
                                        onPressed: () {
                                          _search.clear();
                                          FocusScope.of(context).unfocus();
                                          setState(() => _searching = false);
                                        },
                                        icon:
                                            const Icon(Icons.close_rounded))))),
                      Expanded(
                          child: async.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => premiumError(context, '$e'),
                        data: (list) => ChatTimeline(
                            key: ValueKey(widget.otherId),
                            items: orderedChatItems([
                              ...list,
                              ..._pending
                            ].map((m) => ChatItem(
                                message: m,
                                senderId: m.isMine ? 'self' : widget.otherId))),
                            query: _searching ? _search.text : '',
                            searching: _searching,
                            onVisible: _markVisible,
                            onRetry: _retry,
                            empty: Padding(
                                padding: const EdgeInsets.all(SwanSpace.xl),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SocialAvatar(
                                          initials: person?.initials ??
                                              (widget.otherName.isEmpty
                                                  ? '?'
                                                  : widget.otherName.characters
                                                      .first),
                                          imageUrl: avatar,
                                          size: SwanSpace.xl * 3,
                                          gradientIndex:
                                              widget.otherName.length % 4),
                                      const SizedBox(height: SwanSpace.lg),
                                      Text(widget.otherName,
                                          textAlign: TextAlign.center,
                                          style: SwanType.h2(c.ink)),
                                      const SizedBox(height: SwanSpace.sm),
                                      Text('İlk mesajı gönder',
                                          style: SwanType.body(c.inkMuted)),
                                      const SizedBox(height: SwanSpace.xl),
                                      OutlinedButton(
                                          onPressed: profile,
                                          child:
                                              const Text('Profili görüntüle')),
                                    ]))),
                      )),
                      SwanChatComposer(controller: _ctrl, onSend: _send),
                    ])))));
  }
}
