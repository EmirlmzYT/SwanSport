import '../../../app/widgets/action_gate.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
  bool _isRecordingVoice = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  String? _playingVoiceId;
  int _playbackSeconds = 0;
  Timer? _playbackTimer;

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
    _recordTimer?.cancel();
    _playbackTimer?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
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
    await _sendDirect('🎙️ Sesli Mesaj ($minStr:$secStr)');
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

  Future<void> _sendDirect(String text) async {
    if (!await requireSwanAction(context, ref, SwanAction.message) || !mounted) return;
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
                  child: const Icon(Icons.fitness_center_rounded, color: Color(0xFF6366F1)),
                ),
                title: Text('Grup Antrenman Duyurusu', style: SwanType.body(c.ink, w: FontWeight.w600)),
                subtitle: Text('Bugünkü takım antrenman programını paylaş', style: SwanType.caption(c.inkMuted)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _sendDirect('🏋️ Takım Antrenmanı: A Blok Kuvvet + B Blok Laktat Kapasitesi (18:30 Tesis)');
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
    if (!await requireSwanAction(context, ref, SwanAction.message) || !mounted) return;
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
                  // `viewInsets.bottom` EKLENMİYOR.
                  //
                  // Scaffold `resizeToAvoidBottomInset` ile gövdeyi klavye
                  // kadar zaten küçültüyor. Üstüne bir de klavye yüksekliğini
                  // dolgu olarak eklemek aynı boşluğu iki kez sayıyordu: yazı
                  // alanı klavyenin bir boy yukarısına fırlıyor, arada kocaman
                  // bir boşluk kalıyordu.
                if (_isRecordingVoice)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: alt,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: line),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: _cancelVoiceRecording,
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                            tooltip: 'İptal Et',
                          ),
                          const SizedBox(width: 4),
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
                            '${_recordSeconds ~/ 60}:${(_recordSeconds % 60).toString().padLeft(2, '0')}',
                            style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: ink),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: SizedBox(
                              height: 24,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: List.generate(14, (i) {
                                  final h = 6.0 + ((i * 7 + _recordSeconds * 5) % 18);
                                  return Container(
                                    width: 3,
                                    height: h,
                                    decoration: BoxDecoration(
                                      color: kTeal.withValues(alpha: 0.8),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: _sendVoiceRecording,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [kTealBright, kTeal]),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                    child: Row(children: [
                      IconButton(
                        onPressed: () => _showAttachmentSheet(context),
                        icon: Icon(Icons.add_circle_outline_rounded, size: 22, color: ink.withValues(alpha: 0.6)),
                        tooltip: 'Ek paylaş',
                      ),
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
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: _startVoiceRecording,
                        icon: const Icon(Icons.mic_rounded, size: 22, color: kTeal),
                        tooltip: 'Sesli mesaj',
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: _sending ? null : _send,
                        child: Container(
                          width: 44,
                          height: 44,
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
          if (isVoice) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => _toggleVoicePlayback(m.id, durationSec),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: m.isMine ? Colors.white.withValues(alpha: 0.2) : kTeal.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: m.isMine ? Colors.white : kTeal,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 18,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(12, (idx) {
                          final active = isPlaying && ((idx / 12) <= (currentSec / durationSec));
                          final h = 4.0 + ((idx * 5 + 3) % 14);
                          return Container(
                            width: 3,
                            height: h,
                            decoration: BoxDecoration(
                              color: m.isMine
                                  ? (active ? Colors.white : Colors.white54)
                                  : (active ? kTeal : ink.withValues(alpha: 0.3)),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isPlaying ? '$curMinStr:$curSecStr / $totMinStr:$totSecStr' : '$totMinStr:$totSecStr • Sesli Mesaj',
                      style: SwanType.caption(m.isMine ? Colors.white70 : SwanColors.textSecondary, w: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ] else
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
