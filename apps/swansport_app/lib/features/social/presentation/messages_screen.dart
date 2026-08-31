import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';
import 'edit_profile_sheet.dart';
import '../../../app/widgets/swan_tabs.dart';
import 'widgets/social_widgets.dart';
import '../../../app/widgets/swan_bottom_nav.dart';

/// Sohbet listesi — gruplar ve birebir sohbetler tek akışta (WhatsApp gibi).
///
/// Ayrı bir "Topluluklar" şeridi yerine grupların sohbetlerle aynı listede
/// durması bilinçli: kişi bu ekranda "kiminle konuşayım" modunda oluyor,
/// grubu ayrı bir kutuya koymak onu görünmez kılıyordu.
class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({this.initialTab = 0, super.key});

  /// 0 = Sohbetler, 1 = Topluluklar.
  ///
  /// Eski `/topluluklar` rotası korunuyor ve ikinci sekmeye açılıyor —
  /// bildirimlerdeki derin bağlantılar kırılmasın diye.
  final int initialTab;

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

/// Listedeki tek satır: ya bir grup ya bir birebir sohbet.
class _Entry {
  const _Entry.group(CommunityRow this.group) : dm = null;
  const _Entry.dm(ConversationRow this.dm) : group = null;

  final CommunityRow? group;
  final ConversationRow? dm;

  DateTime? get at => group?.lastAt ?? dm?.lastAt;
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  late int _tab = widget.initialTab;

  @override
  void initState() {
    super.initState();
    // Şehri/kademesi uyan gruplara katılımı tazele — liste dolu gelsin.
    Future.microtask(() async {
      await ref.read(communityServiceProvider).ensureMine();
      if (mounted) ref.invalidate(communityListProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

    final dms = ref.watch(conversationsProvider);
    final groups = ref.watch(communityListProvider).valueOrNull ?? const [];

    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => Navigator.maybePop(context),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                            color: surf,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: line)),
                        child: Icon(Icons.arrow_back_ios_new_rounded,
                            size: 15, color: ink),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text('Mesajlar', style: sora(22, FontWeight.w800, ink)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/ara'),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                            color: surf,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: line)),
                        child: Icon(Icons.edit_rounded, size: 17, color: ink),
                      ),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: SwanSegmentedTabs(
                    labels: const ['Sohbetler', 'Topluluklar'],
                    selected: _tab,
                    onSelect: (i) => setState(() => _tab = i),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(conversationsProvider);
                      ref.invalidate(communityListProvider);
                      await ref.read(conversationsProvider.future);
                    },
                    // Sohbetler = katıldığın gruplar + birebir mesajlar.
                    // Topluluklar = katılabileceklerin tamamı.
                    child: _tab == 0
                        ? dms.when(
                            loading: () =>
                                ListView(children: [premiumLoading()]),
                            error: (e, _) => ListView(
                                children: [premiumError(context, '$e')]),
                            data: (list) => _list(isDark, list, groups),
                          )
                        : _communitiesTab(isDark),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _list(
      bool isDark, List<ConversationRow> dms, List<CommunityRow> groups) {
    // Katıldığı gruplar + birebir sohbetler, son mesaja göre tek sırada.
    final entries = <_Entry>[
      for (final g in groups.where((g) => g.joined)) _Entry.group(g),
      for (final c in dms) _Entry.dm(c),
    ]..sort((a, b) {
        final x = a.at, y = b.at;
        if (x == null && y == null) return 0;
        if (x == null) return 1; // hiç mesajı olmayan grup en alta
        if (y == null) return -1;
        return y.compareTo(x);
      });

    if (entries.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(top: 40),
        children: [
          premiumEmpty(
            context,
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Sohbet yok',
            subtitle: 'Bir profile gidip mesaj göndererek ya da ilinin '
                'antrenör topluluğuna katılarak başlayabilirsin.',
            actionLabel: 'Kişi Ara',
            onAction: () => Navigator.pushNamed(context, '/ara'),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 132),
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final e = entries[i];
        return e.group != null
            ? _groupTile(isDark, e.group!)
            : _tile(context, isDark, e.dm!);
      },
    );
  }

  /// Grup satırı — birebir sohbetle aynı iskelet, avatar yerine grup simgesi.
  Widget _groupTile(bool isDark, CommunityRow g) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    return GestureDetector(
      // Federasyon kanalı sohbet değil duyuru panosu — ayrı ekrana gider.
      onTap: () => Navigator.pushNamed(
          context, g.isFederation ? '/federasyon' : '/topluluk',
          arguments: {'id': g.id, 'name': g.name}),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: line),
        ),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: kTeal.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
                g.isFederation ? Icons.campaign_rounded : Icons.forum_rounded,
                size: 21,
                color: kTeal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(g.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: jakarta(13.5, FontWeight.w800, ink)),
                  ),
                  if (g.lastAt != null)
                    Text(shortAgo(g.lastAt!),
                        style: jakarta(
                            10.5, FontWeight.w600, SwanColors.textSecondary)),
                ]),
                const SizedBox(height: 2),
                Row(children: [
                  Expanded(
                    child: Text(
                        g.lastBody?.trim().isNotEmpty == true
                            ? g.lastBody!
                            : '${g.memberCount} üye · henüz mesaj yok',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: jakarta(
                            12,
                            g.unread > 0 ? FontWeight.w700 : FontWeight.w500,
                            g.unread > 0 ? ink : SwanColors.textSecondary)),
                  ),
                  if (g.unread > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: kTeal,
                          borderRadius: BorderRadius.circular(999)),
                      child: Text(g.unread > 99 ? '99+' : '${g.unread}',
                          style: jakarta(10, FontWeight.w800, Colors.white)),
                    ),
                  ],
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _tile(BuildContext context, bool isDark, ConversationRow c) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/sohbet',
          arguments: {'id': c.otherId, 'name': c.otherName}),
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
              initials: c.initials,
              imageUrl: c.otherAvatarUrl,
              size: 46,
              gradientIndex: c.otherName.length % 4),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(c.otherName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: jakarta(13.5, FontWeight.w800, ink)),
                  ),
                  Text(shortAgo(c.lastAt),
                      style: jakarta(
                          10.5, FontWeight.w600, SwanColors.textSecondary)),
                ]),
                const SizedBox(height: 2),
                Row(children: [
                  Expanded(
                    child: Text(c.lastBody,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: jakarta(
                            12,
                            c.unread > 0 ? FontWeight.w700 : FontWeight.w500,
                            c.unread > 0 ? ink : SwanColors.textSecondary)),
                  ),
                  if (c.unread > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: kTeal,
                          borderRadius: BorderRadius.circular(999)),
                      child: Text('${c.unread}',
                          style:
                              jakarta(10, FontWeight.w800, Colors.white)),
                    ),
                  ],
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  // --------------------------- Topluluklar sekmesi --------------------------
  //
  // Sohbetler sekmesi yalnızca KATILDIĞIN grupları gösteriyor
  // (`groups.where((g) => g.joined)`); bu sekme katılabileceklerin tamamını
  // listeliyor. İkisi aynı `communityListProvider`'ı okuyor, farkları süzgeç.

  Widget _communitiesTab(bool isDark) {
    final async = ref.watch(communityListProvider);
    return async.when(
      loading: () => ListView(children: [premiumLoading()]),
      error: (e, _) => ListView(children: [premiumError(context, '$e')]),
      data: (list) {
        if (list.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 30, 20, 132),
            children: [_emptyState(isDark)],
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 132),
          itemCount: list.length,
          itemBuilder: (_, i) => _communityTile(isDark, list[i]),
        );
      },
    );
  }

  Widget _emptyState(bool isDark) {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final me = uid == null
        ? null
        : ref.watch(socialProfileProvider(uid)).valueOrNull;
    final hasCity = (me?.cityCode ?? '').isNotEmpty;

    if (!hasCity) {
      return Column(children: [
        premiumEmpty(
          context,
          icon: Icons.location_city_rounded,
          title: 'Şehrini seç',
          subtitle:
              'Topluluklar şehre göre kurulu. Şehrini seçince ilinin antrenör '
              'grubuna otomatik katılırsın.',
        ),
        const SizedBox(height: 14),
        Center(
          child: GestureDetector(
            onTap: () async {
              if (me == null) return;
              final saved = await showEditProfileSheet(context, me);
              if (saved == true && mounted) {
                ref.invalidate(socialProfileProvider(me.id));
                await ref.read(communityServiceProvider).ensureMine();
                ref.invalidate(communityListProvider);
              }
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [kTealBright, kTeal]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text('Şehrimi seç',
                  style: jakarta(13, FontWeight.w800, Colors.white)),
            ),
          ),
        ),
      ]);
    }

    return premiumEmpty(
      context,
      icon: Icons.forum_outlined,
      title: 'Topluluk yok',
      subtitle:
          'Topluluklar şimdilik doğrulanmış antrenörlere açık. Antrenör '
          'kademeni doğrulattığında ilinin grubu burada görünür.',
    );
  }

  Widget _communityTile(bool isDark, CommunityRow c) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    return GestureDetector(
      onTap: () {
        if (!c.joined) {
          _join(c);
          return;
        }
        Navigator.pushNamed(
            context, c.isFederation ? '/federasyon' : '/topluluk',
            arguments: {'id': c.id, 'name': c.name});
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: line),
        ),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: kTeal.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
                c.isFederation ? Icons.campaign_rounded : Icons.forum_rounded,
                size: 21,
                color: kTeal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name, style: jakarta(13.5, FontWeight.w700, ink)),
                const SizedBox(height: 3),
                Text(
                  c.joined
                      ? (c.lastBody?.trim().isNotEmpty == true
                          ? c.lastBody!
                          : '${c.memberCount} üye · henüz mesaj yok')
                      : 'Katılmak için dokun · ${c.memberCount} üye',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: jakarta(11.5, FontWeight.w500, SwanColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!c.joined)
            Text('Katıl', style: jakarta(12, FontWeight.w800, kTeal))
          else
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (c.lastAt != null)
                Text(shortAgo(c.lastAt!),
                    style: jakarta(
                        10.5, FontWeight.w600, SwanColors.textSecondary)),
              if (c.unread > 0) ...[
                const SizedBox(height: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  constraints: const BoxConstraints(minWidth: 20),
                  decoration: BoxDecoration(
                    color: kTeal,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(c.unread > 99 ? '99+' : '${c.unread}',
                      textAlign: TextAlign.center,
                      style: jakarta(10, FontWeight.w800, Colors.white)),
                ),
              ],
            ]),
        ]),
      ),
    );
  }

  Future<void> _join(CommunityRow c) async {
    try {
      await ref.read(communityServiceProvider).join(c.id);
      ref.invalidate(communityListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${c.name} grubuna katıldın'),
          backgroundColor: kTeal));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Katılamadın: $e'),
          backgroundColor: const Color(0xFFF43F5E)));
    }
  }
}


/// Birebir sohbet ekranı.
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
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref
          .read(notificationServiceProvider)
          .markConversationRead(widget.otherId);
      if (mounted) ref.invalidate(conversationsProvider);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(notificationServiceProvider).send(widget.otherId, text);
      _ctrl.clear();
      ref.invalidate(messagesProvider(widget.otherId));
      ref.invalidate(conversationsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Gönderilemedi: $e'),
            backgroundColor: const Color(0xFFF43F5E)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final alt = isDark ? const Color(0xFF1A2537) : const Color(0xFFF1F5F8);
    final async = ref.watch(messagesProvider(widget.otherId));

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => Navigator.maybePop(context),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                            color: surf,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: line)),
                        child: Icon(Icons.arrow_back_ios_new_rounded,
                            size: 15, color: ink),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/profil',
                            arguments: widget.otherId),
                        child: Text(widget.otherName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: sora(18, FontWeight.w800, ink)),
                      ),
                    ),
                  ]),
                ),
                Divider(color: line, height: 1),
                Expanded(
                  child: async.when(
                    loading: () => premiumLoading(),
                    error: (e, _) => premiumError(context, '$e'),
                    data: (list) {
                      if (list.isEmpty) {
                        return Center(
                          child: Text('Sohbeti başlat',
                              style: jakarta(13, FontWeight.w600,
                                  SwanColors.textSecondary)),
                        );
                      }
                      return ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                        itemCount: list.length,
                        itemBuilder: (_, i) => _bubble(isDark, list[i]),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      14, 6, 14, 12 + MediaQuery.of(context).viewInsets.bottom),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        minLines: 1,
                        maxLines: 4,
                        style: jakarta(13.5, FontWeight.w500, ink),
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: 'Mesaj yaz…',
                          hintStyle: jakarta(
                              13, FontWeight.w500, SwanColors.textSecondary),
                          filled: true,
                          fillColor: alt,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(color: line)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide:
                                  const BorderSide(color: kTeal, width: 1.5)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _sending ? null : _send,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [kTealBright, kTeal]),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: _sending
                            ? const Padding(
                                padding: EdgeInsets.all(13),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.send_rounded,
                                color: Colors.white, size: 19),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bubble(bool isDark, MessageRow m) {
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final surf = isDark ? const Color(0xFF1A2537) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    return Align(
      alignment: m.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: m.isMine
              ? const LinearGradient(colors: [kTealBright, kTeal])
              : null,
          color: m.isMine ? null : surf,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(m.isMine ? 16 : 4),
            bottomRight: Radius.circular(m.isMine ? 4 : 16),
          ),
          border: m.isMine ? null : Border.all(color: line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m.body,
                style: jakarta(13.5, FontWeight.w500,
                        m.isMine ? Colors.white : ink)
                    .copyWith(height: 1.35)),
            const SizedBox(height: 3),
            Text(shortAgo(m.createdAt),
                style: jakarta(9.5, FontWeight.w600,
                    m.isMine ? Colors.white70 : SwanColors.textSecondary)),
          ],
        ),
      ),
    );
  }

}
