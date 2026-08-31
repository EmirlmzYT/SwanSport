import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';
import '../../social/presentation/widgets/social_widgets.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/design/swan_palette.dart';

/// Topluluk sohbeti — birebir sohbetten farkı: gönderenin adı görünür ve
/// mesajlar anlık (realtime) düşer.
class CommunityChatScreen extends ConsumerStatefulWidget {
  const CommunityChatScreen({
    super.key,
    required this.communityId,
    required this.title,
  });

  final String communityId;
  final String title;

  @override
  ConsumerState<CommunityChatScreen> createState() =>
      _CommunityChatScreenState();
}

class _CommunityChatScreenState extends ConsumerState<CommunityChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  int _seen = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(communityServiceProvider).markRead(widget.communityId);
      if (mounted) ref.invalidate(communityListProvider);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Yeni mesaj gelince en alta kaydır — grup sohbetinde akış hep aşağı doğru.
  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(communityServiceProvider).send(widget.communityId, text);
      _ctrl.clear();
      // Mesaj akıştan kendiliğinden gelir; listeyi tazelemek yalnızca
      // "son mesaj" özetini güncellemek için.
      ref.invalidate(communityListProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Gönderilemedi: $e'),
            backgroundColor: SwanPalette.light.danger));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _leave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gruptan çık'),
        content: Text(
            '${widget.title} grubundan çıkacaksın. İstediğin zaman tekrar '
            'katılabilirsin.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Çık')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(communityServiceProvider).leave(widget.communityId);
      ref.invalidate(communityListProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Çıkılamadı: $e'),
            backgroundColor: SwanPalette.light.danger));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = (isDark ? SwanPalette.dark : SwanPalette.light).bg;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    final alt = (isDark ? SwanPalette.dark : SwanPalette.light).surfaceAlt;

    final async = ref.watch(communityMessagesProvider(widget.communityId));
    final members =
        ref.watch(communityMembersProvider(widget.communityId)).valueOrNull ??
            const <String, CommunityMember>{};

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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SwanType.h3(ink)),
                          if (members.isNotEmpty)
                            Text('${members.length} üye',
                                style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _leave,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                            color: surf,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: line)),
                        child: Icon(Icons.logout_rounded,
                            size: 16, color: SwanColors.textSecondary),
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
                      if (list.length != _seen) {
                        _seen = list.length;
                        _scrollToEnd();
                      }
                      if (list.isEmpty) {
                        return Center(
                          child: Text('İlk mesajı sen yaz',
                              style: SwanType.bodySm(SwanColors.textSecondary, w: FontWeight.w600)),
                        );
                      }
                      return ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final m = list[i];
                          // Aynı kişinin arka arkaya mesajlarında adı tekrarlama.
                          final showName = !m.isMine &&
                              (i == 0 || list[i - 1].senderId != m.senderId);
                          return _bubble(isDark, m, members[m.senderId],
                              showName: showName);
                        },
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

  Widget _bubble(bool isDark, CommunityMessageRow m, CommunityMember? sender,
      {required bool showName}) {
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final surf = isDark ? SwanPalette.dark.surfaceAlt : Colors.white;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;

    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient:
            m.isMine ? const LinearGradient(colors: [kTealBright, kTeal]) : null,
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
          if (showName)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(sender?.name ?? 'Üye',
                  style: SwanType.caption(kTeal, w: FontWeight.w800)),
            ),
          Text(m.body,
              style: SwanType.bodySm(m.isMine ? Colors.white : ink)
                  .copyWith(height: 1.35)),
          const SizedBox(height: 3),
          Text(shortAgo(m.createdAt),
              style: SwanType.caption(m.isMine ? Colors.white70 : SwanColors.textSecondary, w: FontWeight.w600)),
        ],
      ),
    );

    // Karşı taraf: baloncuğun yanında küçük avatar (kim yazdığı bir bakışta).
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            m.isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!m.isMine) ...[
            SizedBox(
              width: 28,
              child: showName
                  ? GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/profil',
                          arguments: m.senderId),
                      child: SocialAvatar(
                        initials: sender?.initials ?? '?',
                        size: 26,
                        gradientIndex: m.senderId.hashCode.abs() % 4,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 7),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}
