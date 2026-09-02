import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/shared_content_card.dart';
import '../../../app/push/push_service.dart';
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
    final bg = (isDark ? SwanPalette.dark : SwanPalette.light).bg;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;

    // Yeni bir DM geldiğinde listeyi tazele.
    //
    // `conversationsProvider` bir RPC ile hesaplanıyor (son mesaj, okunmamış
    // sayısı); gelen satırı istemcide listeye işlemek o mantığın ikinci bir
    // kopyası olurdu ve ikisi zamanla ayrışırdı. Sinyal gelince baştan
    // çekiyoruz — liste küçük, maliyeti önemsiz.
    ref.listen(dmChangesProvider, (_, next) {
      // Yalnızca gerçek bir olayda tazele. Akış kurulamazsa (tablo realtime
      // publication'ında değilse) hata durumu geliyor; onu tazeleme sebebi
      // saymak boşuna istek demek.
      if (next is AsyncData) ref.invalidate(conversationsProvider);
    });

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
                    Text('Mesajlar', style: SwanType.h2(ink)),
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
  // --------------------------------- döşeme --------------------------------
  //
  // Brief §8: *"Toplulukları da ayrı ağır kartlar olarak değil, normal sohbet
  // listesiyle aynı görsel dilde göster."* İki döşeme zaten yapı olarak
  // aynıydı (yalnızca baştaki widget farklıydı) ama ikisi de yüzey + kenarlık
  // + 16 radius'luk birer kartdı. Kabuk kalktı; WhatsApp/Instagram DM gibi
  // düz bir liste kaldı.

  Widget _groupTile(bool isDark, CommunityRow g) => _conversationTile(
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: context.swan.accentSoft,
            borderRadius: BorderRadius.circular(SwanRadius.md),
          ),
          child: Icon(
              g.isFederation ? Icons.campaign_rounded : Icons.forum_rounded,
              size: 22,
              color: context.swan.accent),
        ),
        title: g.name,
        // Henüz mesajı olmayan grupta üye sayısı bağlam veriyor.
        subtitle: g.lastBody?.trim().isNotEmpty == true
            ? g.lastBody!
            : '${g.memberCount} üye · henüz mesaj yok',
        at: g.lastAt,
        unread: g.unread,
        // Federasyon kanalı sohbet değil duyuru panosu — ayrı ekrana gider.
        onTap: () => Navigator.pushNamed(
            context, g.isFederation ? '/federasyon' : '/topluluk',
            arguments: {'id': g.id, 'name': g.name}),
      );

  Widget _tile(BuildContext context, bool isDark, ConversationRow c) =>
      _conversationTile(
        leading: SocialAvatar(
            initials: c.initials,
            imageUrl: c.otherAvatarUrl,
            size: 52,
            gradientIndex: c.otherName.length % 4),
        title: c.otherName,
        subtitle: c.lastBody,
        at: c.lastAt,
        unread: c.unread,
        onTap: () => Navigator.pushNamed(context, '/sohbet',
            arguments: {'id': c.otherId, 'name': c.otherName}),
      );

  Widget _conversationTile({
    required Widget leading,
    required String title,
    required String subtitle,
    required DateTime? at,
    required int unread,
    required VoidCallback onTap,
  }) {
    final c = context.swan;
    final unreadStyle = unread > 0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: SwanSpace.md),
        child: Row(children: [
          leading,
          const SizedBox(width: SwanSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SwanType.body(c.ink, w: FontWeight.w700)),
                  ),
                  if (at != null)
                    Text(shortAgo(at), style: SwanType.caption(c.inkMuted)),
                ]),
                const SizedBox(height: 2),
                Row(children: [
                  Expanded(
                    child: Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SwanType.bodySm(
                            unreadStyle ? c.ink : c.inkMuted,
                            w: unreadStyle ? FontWeight.w700 : FontWeight.w500)),
                  ),
                  if (unreadStyle) ...[
                    const SizedBox(width: SwanSpace.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: c.accent,
                          borderRadius: BorderRadius.circular(999)),
                      child: Text(unread > 99 ? '99+' : '$unread',
                          style: SwanType.caption(Colors.white,
                              w: FontWeight.w800)),
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
                  style: SwanType.bodySm(Colors.white, w: FontWeight.w800)),
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

  /// Topluluklar sekmesi döşemesi.
  ///
  /// Sohbet döşemesiyle aynı görsel dil; tek farkı katılmadığın gruplarda
  /// son mesaj yerine "Katıl" çağrısı olması.
  Widget _communityTile(bool isDark, CommunityRow g) {
    final c = context.swan;

    if (g.joined) {
      return _groupTile(isDark, g);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _join(g),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: SwanSpace.md),
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(SwanRadius.md),
            ),
            child: Icon(
                g.isFederation ? Icons.campaign_rounded : Icons.forum_rounded,
                size: 22,
                color: c.inkMuted),
          ),
          const SizedBox(width: SwanSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(g.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SwanType.body(c.ink, w: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('${g.memberCount} üye',
                    style: SwanType.bodySm(c.inkMuted)),
              ],
            ),
          ),
          const SizedBox(width: SwanSpace.sm),
          Text('Katıl', style: SwanType.bodySm(c.accent, w: FontWeight.w800)),
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
          backgroundColor: SwanPalette.light.danger));
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

  /// Sunucuya henüz ulaşmamış kendi mesajlarım.
  ///
  /// Eskiden mesaj gidip dönene kadar ekranda yoktu ve hata olursa yazdığın
  /// metin `SnackBar` ile birlikte kayboluyordu — uzun bir mesajı baştan
  /// yazmak gerekiyordu. Şimdi hemen görünüyor; başarısız olursa yerinde
  /// duruyor ve dokununca tekrar deneniyor.
  final List<MessageRow> _pending = [];

  /// Okundu işaretlenmek üzere gönderilenler — aynı mesaj için RPC'yi
  /// tekrar tekrar çağırmamak için.
  final Set<String> _marked = {};

  /// Mesaj bazlı işaretleme kullanılamıyor (0042 çalıştırılmamış olabilir);
  /// sohbet bazlı olana düşüldü.
  ///
  /// Bayrak olmadan her yeniden çizimde başarısız bir RPC tekrar
  /// deneniyordu — saniyede birkaç kez 404.
  bool _perMessageMarkUnavailable = false;

  @override
  void initState() {
    super.initState();
    // Push dinleyicisi bunu okuyup bu kişiden gelen ön plan uyarısını
    // bastırıyor — mesaj zaten sohbete canlı düşüyor.
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

  /// Sohbet ekrandayken gelen mesajları okundu işaretler.
  ///
  /// Eskiden yalnızca ekrana **girerken** işaretleniyordu: sen sohbetteyken
  /// gelen mesaj okunmamış kalıyor, karşı taraf çift tik görmüyor ve senin
  /// rozetin dolu duruyordu.
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
          // Yedek yol: bütün sohbeti işaretle. Daha kaba ama her zaman var.
          await svc.markConversationRead(widget.otherId);
        } else {
          await svc.markMessagesRead(ids);
        }
        if (mounted) ref.invalidate(conversationsProvider);
      } catch (_) {
        if (_perMessageMarkUnavailable) {
          // İkisi de olmadı: okundu işareti kritik değil, sessizce geç.
          // `_marked`'i geri almıyoruz — geri alsak her karede tekrar
          // denenirdi.
          return;
        }
        _perMessageMarkUnavailable = true;
        try {
          await svc.markConversationRead(widget.otherId);
          if (mounted) ref.invalidate(conversationsProvider);
        } catch (_) {
          // sessiz
        }
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    await _deliver(text);
  }

  /// Bir metni gönderir; ekranda önce "gönderiliyor" olarak görünür.
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
      // Gerçek mesaj akıştan gelecek; yereldeki kopyayı düşür.
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
    // Liste `reverse: true`: en yeni mesaj **sıfır** konumunda. Eskiden
    // `maxScrollExtent`'e gidiliyordu, ters listede orası en eski mesaj.
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = (isDark ? SwanPalette.dark : SwanPalette.light).bg;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    final alt = (isDark ? SwanPalette.dark : SwanPalette.light).surfaceAlt;
    final async = ref.watch(chatProvider(widget.otherId));

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
                            style: SwanType.h3(ink)),
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
                      _markVisible(list);
                      // Sunucudakiler + henüz gitmemiş kendi mesajlarım.
                      final all = [...list, ..._pending];
                      if (all.isEmpty) {
                        return Center(
                          child: Text('Sohbeti başlat',
                              style: SwanType.bodySm(SwanColors.textSecondary, w: FontWeight.w600)),
                        );
                      }
                      // `reverse: true` — WhatsApp/Telegram deseni.
                      //
                      // Liste alttan yukarı kuruluyor: en yeni mesaj sıfır
                      // konumunda duruyor. Kazancı, klavye açılıp gövde
                      // küçülünce listenin **kaydığı yerde kalmaması** —
                      // düz listede son mesaj klavyenin altında kalıyordu ve
                      // elle aşağı kaydırmak gerekiyordu.
                      //
                      // Bedeli, öğelere sondan erişmek; onu burada yapıyoruz.
                      return ListView.builder(
                        controller: _scroll,
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                        itemCount: all.length,
                        itemBuilder: (_, i) =>
                            _bubble(isDark, all[all.length - 1 - i]),
                      );
                    },
                  ),
                ),
                  // `viewInsets.bottom` EKLENMİYOR.
                  //
                  // Scaffold `resizeToAvoidBottomInset` ile gövdeyi klavye
                  // kadar zaten küçültüyor. Üstüne bir de klavye yüksekliğini
                  // dolgu olarak eklemek aynı boşluğu iki kez sayıyordu: yazı
                  // alanı klavyenin bir boy yukarısına fırlıyor, arada kocaman
                  // bir boşluk kalıyordu.
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        minLines: 1,
                        maxLines: 4,
                        style: SwanType.bodySm(ink),
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: 'Mesaj yaz…',
                          hintStyle: SwanType.bodySm(SwanColors.textSecondary),
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
                      // Artık kilitlenmiyor: mesaj hemen listeye düşüyor,
                      // gönderim arkada sürüyor. Arka arkaya iki mesaj
                      // yazabilmek için düğmenin beklemesi gerekmiyor.
                      onTap: _send,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [kTealBright, kTeal]),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(Icons.send_rounded,
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
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final surf = isDark ? SwanPalette.dark.surfaceAlt : Colors.white;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
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
            // Paylaşılan içerik kartı. İçeriği mesajda saklanmıyor; her
            // çizimde kaynaktan tazeleniyor ve kaynak kaldırılmışsa
            // "artık kullanılamıyor" durumuna düşüyor.
            if (m.isShare)
              SharedContentCard(
                  kind: m.sharedKind ?? m.contentType,
                  id: m.sharedId!,
                  onDark: m.isMine),
            if (m.body.isNotEmpty)
              Text(m.body,
                  style: SwanType.bodySm(m.isMine ? Colors.white : ink)
                      .copyWith(height: 1.35)),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    m.status == MessageStatus.failed
                        ? 'Gönderilemedi · dokun, tekrar dene'
                        : shortAgo(m.createdAt),
                    style: SwanType.caption(
                        m.isMine ? Colors.white70 : SwanColors.textSecondary,
                        w: FontWeight.w600)),
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

  /// Gönderim/okundu göstergesi — yalnızca kendi mesajlarımda.
  ///
  /// Renk tek başına anlam taşımıyor: saat/durum metni hemen yanında duruyor
  /// ve başarısız gönderimde metnin kendisi "Gönderilemedi" diyor. Tik
  /// görülemezse de bilgi kaybolmuyor.
  Widget _tick(MessageRow m) => switch (m.status) {
        MessageStatus.sending => const SizedBox(
            width: 11,
            height: 11,
            child: CircularProgressIndicator(
                strokeWidth: 1.4, color: Colors.white70),
          ),
        MessageStatus.failed => const Icon(Icons.refresh_rounded,
            size: 13, color: Colors.white),
        MessageStatus.sent => Icon(
            m.isRead ? Icons.done_all_rounded : Icons.done_rounded,
            size: 13,
            // Okundu tiki beyaz, okunmamış soluk — ikisi de teal balonun
            // üstünde. `accent` burada kullanılamaz: zemin zaten teal.
            color: m.isRead ? Colors.white : Colors.white60,
          ),
      };

}
