import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../design/swan_palette.dart';
import '../design/swan_shape.dart';
import '../design/swan_type.dart';

/// Sohbette paylaşılan içeriğin kartı.
///
/// **Kartın içeriği mesajda saklanmıyor.** Her çizimde `shared_content_card`
/// RPC'siyle kaynaktan tazeleniyor; kaynak silinmiş, moderasyona alınmış ya
/// da izleyen kişi engellenmişse kart eski veriyi göstermek yerine sabit bir
/// "artık kullanılamıyor" durumuna düşüyor.
///
/// Gömseydik: bir gönderi silindikten sonra bile içeriği, aylar önce
/// paylaşıldığı her sohbette okunmaya devam ederdi.
class SharedContentCard extends ConsumerWidget {
  const SharedContentCard({
    super.key,
    required this.kind,
    required this.id,
    this.onDark = false,
  });

  final String kind;
  final String id;

  /// Kendi mesaj balonumun içindeyse zemin koyu; metin rengi ona göre.
  final bool onDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.swan;
    final card = ref.watch(sharedCardProvider('$kind|$id'));

    final fg = onDark ? Colors.white : c.ink;
    final fgMuted = onDark ? Colors.white70 : c.inkMuted;
    final bg = onDark ? Colors.white.withValues(alpha: 0.14) : c.surfaceAlt;
    final border = onDark ? Colors.white24 : c.line;

    Widget shell(Widget child) => Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(SwanSpace.md),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(SwanRadius.sm),
            border: Border.all(color: border),
          ),
          child: child,
        );

    return card.when(
      // Yüklenirken içerik yokmuş gibi göstermiyoruz; boş bir iskelet.
      loading: () => shell(SizedBox(
        height: 34,
        child: Row(children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 1.6, color: fgMuted),
          ),
        ]),
      )),
      // Hata da "gösterme" demek: kısmi veri göstermektense boş bırakmak
      // doğru taraf.
      error: (_, __) => shell(_unavailable(fgMuted)),
      data: (x) {
        if (!x.available) return shell(_unavailable(fgMuted));

        return GestureDetector(
          onTap: x.route == null
              ? null
              : () => Navigator.pushNamed(context, x.route!),
          child: shell(Row(children: [
            Icon(_iconFor(kind), size: 18, color: fgMuted),
            const SizedBox(width: SwanSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(x.title ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SwanType.caption(fg, w: FontWeight.w700)),
                  if ((x.subtitle ?? '').isNotEmpty)
                    Text(x.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SwanType.caption(fgMuted)),
                ],
              ),
            ),
          ])),
        );
      },
    );
  }

  Widget _unavailable(Color muted) => Row(children: [
        Icon(Icons.block_rounded, size: 16, color: muted),
        const SizedBox(width: SwanSpace.sm),
        Expanded(
          // Sebep söylenmiyor: "silinmiş" ile "erişimin yok" arasındaki
          // fark, olmayan bir içeriğin varlığını doğrulardı.
          child: Text('Bu içerik artık kullanılamıyor',
              style: SwanType.caption(muted)),
        ),
      ]);

  IconData _iconFor(String kind) => switch (kind) {
        ShareKind.listing => Icons.sell_rounded,
        ShareKind.event => Icons.event_rounded,
        ShareKind.organization => Icons.emoji_events_rounded,
        _ => Icons.article_rounded,
      };
}

/// Paylaşım sayfası: son sohbetler ve üye olunan kanallar.
///
/// Çoklu seçim tek çağrıda gidiyor. Sekiz sohbete ayrı ayrı istek atmak,
/// yarısı gidip yarısı gitmeyen bir paylaşım bırakıyordu.
Future<void> showShareSheet(
  BuildContext context, {
  required String kind,
  required String id,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShareSheet(kind: kind, id: id),
    );

class _ShareSheet extends ConsumerStatefulWidget {
  const _ShareSheet({required this.kind, required this.id});

  final String kind;
  final String id;

  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<_ShareSheet> {
  final _selected = <String>{};
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send(List<ShareTarget> targets) async {
    if (_selected.isEmpty) return;
    setState(() => _busy = true);

    final chosen = targets.where((t) => _selected.contains(t.id));
    try {
      final n = await ref.read(socialShareServiceProvider).share(
            kind: widget.kind,
            id: widget.id,
            recipients:
                chosen.where((t) => !t.isCommunity).map((t) => t.id).toList(),
            communities:
                chosen.where((t) => t.isCommunity).map((t) => t.id).toList(),
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$n sohbete gönderildi')));
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final targets = ref.watch(shareTargetsProvider);

    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(SwanRadius.lg)),
      ),
      // Klavye açılınca gövde `viewInsets` kadar yukarı kayıyor. Scaffold
      // burada yok, bu yüzden çift sayım riski de yok.
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: SwanSpace.md),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: c.line, borderRadius: BorderRadius.circular(999)),
          ),
          const SizedBox(height: SwanSpace.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
            child: Row(children: [
              Text('Paylaş', style: SwanType.h3(c.ink)),
              const Spacer(),
              if (_selected.isNotEmpty)
                Text('${_selected.length} seçili',
                    style: SwanType.caption(c.inkMuted)),
            ]),
          ),
          const SizedBox(height: SwanSpace.sm),
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45),
            child: targets.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(SwanSpace.xl),
                child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(SwanSpace.lg),
                child: Text('Sohbetler alınamadı: $e',
                    style: SwanType.caption(c.inkMuted)),
              ),
              data: (list) => list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(SwanSpace.lg),
                      child: Text(
                        'Henüz paylaşabileceğin bir sohbet ya da kanal yok.',
                        style: SwanType.caption(c.inkMuted),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final t = list[i];
                        final on = _selected.contains(t.id);
                        return CheckboxListTile(
                          value: on,
                          dense: true,
                          onChanged: (v) => setState(() =>
                              v == true ? _selected.add(t.id)
                                        : _selected.remove(t.id)),
                          title: Text(t.name,
                              style: SwanType.bodySm(c.ink)),
                          subtitle: Text(
                              t.isCommunity ? 'Kanal' : 'Sohbet',
                              style: SwanType.caption(c.inkMuted)),
                          secondary: Icon(
                              t.isCommunity
                                  ? Icons.groups_rounded
                                  : Icons.person_rounded,
                              size: 20,
                              color: c.inkMuted),
                        );
                      },
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                SwanSpace.lg, SwanSpace.sm, SwanSpace.lg, SwanSpace.lg),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _note,
                  style: SwanType.bodySm(c.ink),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Mesaj ekle (isteğe bağlı)',
                    hintStyle: SwanType.bodySm(c.inkMuted),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(SwanRadius.sm),
                      borderSide: BorderSide(color: c.line),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: SwanSpace.sm),
              GestureDetector(
                onTap: _busy || _selected.isEmpty
                    ? null
                    : () => _send(targets.valueOrNull ?? const []),
                child: Container(
                  height: 44,
                  width: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _selected.isEmpty ? c.surfaceAlt : c.accentFill,
                    borderRadius: BorderRadius.circular(SwanRadius.sm),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Icon(Icons.send_rounded,
                          size: 18,
                          color: _selected.isEmpty ? c.inkMuted : Colors.white),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
