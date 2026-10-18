import 'package:swansport_app/app/widgets/swan_scaffold.dart';
import '../../../app/widgets/action_gate.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';
import '../../social/presentation/widgets/social_widgets.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/design/swan_palette.dart';
import '../../../app/widgets/chat_composer.dart';
import '../../../app/design/swan_shape.dart';

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
      if (!mounted) return;
      try {
        await ref.read(communityServiceProvider).markRead(widget.communityId);
        if (mounted) ref.invalidate(communityListProvider);
      } catch (_) {
        // Offline read receipts must not break the conversation.
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _sendDirect(String text) async {
    if (!await requireSwanAction(context, ref, SwanAction.message) || !mounted)
      return;
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(communityServiceProvider).send(widget.communityId, text);
      _scrollToEnd();
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

  Future<void> _showAttachmentSheet(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark ? SwanPalette.dark : SwanPalette.light;

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
                'Toplulukta Paylaş',
                style: SwanType.h3(c.ink),
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
                title: Text('Fotoğraf / Belge',
                    style: SwanType.body(c.ink, w: FontWeight.w600)),
                subtitle: Text('Görsel veya antrenman dokümanı seç',
                    style: SwanType.caption(c.inkMuted)),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final f = await FilePicker.pickFile(type: FileType.any);
                    if (f != null) {
                      await _sendDirect('📎 [Ek: ${f.name}]');
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
                  child: const Icon(Icons.fitness_center_rounded,
                      color: Color(0xFF6366F1)),
                ),
                title: Text('Grup Antrenman Duyurusu',
                    style: SwanType.body(c.ink, w: FontWeight.w600)),
                subtitle: Text('Bugünkü takım antrenman programını paylaş',
                    style: SwanType.caption(c.inkMuted)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _sendDirect(
                      '🏋️ Takım Antrenmanı: A Blok Kuvvet + B Blok Laktat Kapasitesi (18:30 Tesis)');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Yeni mesaj gelince en alta kaydır — grup sohbetinde akış hep aşağı doğru.
  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    if (!await requireSwanAction(context, ref, SwanAction.message) || !mounted)
      return;
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(communityServiceProvider).send(widget.communityId, text);
      if (!mounted) return;
      // Preserve anything typed while the request was in flight.
      if (_ctrl.text.trim() == text) _ctrl.clear();
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
        content:
            Text('${widget.title} grubundan çıkacaksın. İstediğin zaman tekrar '
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

    final async = ref.watch(communityMessagesProvider(widget.communityId));
    final members =
        ref.watch(communityMembersProvider(widget.communityId)).valueOrNull ??
            const <String, CommunityMember>{};

    return SwanScaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(SwanSpace.sm),
                  child: Row(children: [
                    IconButton(
                        tooltip: 'Geri dön',
                        onPressed: () => Navigator.maybePop(context),
                        icon:
                            Icon(Icons.arrow_back_ios_new_rounded, color: ink)),
                    CircleAvatar(
                        backgroundColor: context.swan.surfaceAlt,
                        child: Icon(Icons.forum_outlined, color: ink)),
                    const SizedBox(width: SwanSpace.md),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SwanType.h3(ink)),
                          Text(
                              members.isEmpty
                                  ? 'Topluluk sohbeti'
                                  : '${members.length} üye',
                              style: SwanType.caption(context.swan.inkMuted)),
                        ])),
                    IconButton(
                        tooltip: 'Topluluktan ayrıl',
                        onPressed: _leave,
                        icon: Icon(Icons.logout_rounded,
                            color: context.swan.inkMuted)),
                  ]),
                ),
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
                              style: SwanType.bodySm(SwanColors.textSecondary,
                                  w: FontWeight.w600)),
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
                // `viewInsets.bottom` EKLENMİYOR.
                //
                // Scaffold `resizeToAvoidBottomInset` ile gövdeyi klavye
                // kadar zaten küçültüyor. Üstüne bir de klavye yüksekliğini
                // dolgu olarak eklemek aynı boşluğu iki kez sayıyordu: yazı
                // alanı klavyenin bir boy yukarısına fırlıyor, arada kocaman
                // bir boşluk kalıyordu.
                Row(children: [
                  IconButton(
                      tooltip: 'Ek paylaş',
                      onPressed: () => _showAttachmentSheet(context),
                      icon: Icon(Icons.add_circle_outline_rounded, color: ink)),
                  Expanded(
                      child: SwanChatComposer(
                          controller: _ctrl, onSend: _send, sending: _sending)),
                ]),
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

    final bubble = Container(
      constraints:
          BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
      padding: const EdgeInsets.symmetric(
          horizontal: SwanSpace.lg, vertical: SwanSpace.md),
      decoration: BoxDecoration(
        color: m.isMine ? context.swan.accentFill : surf,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(SwanRadius.md),
          topRight: const Radius.circular(SwanRadius.md),
          bottomLeft: Radius.circular(m.isMine ? SwanRadius.md : SwanSpace.xs),
          bottomRight: Radius.circular(m.isMine ? SwanSpace.xs : SwanRadius.md),
        ),
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
              style: SwanType.caption(
                  m.isMine ? Colors.white70 : SwanColors.textSecondary,
                  w: FontWeight.w600)),
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
