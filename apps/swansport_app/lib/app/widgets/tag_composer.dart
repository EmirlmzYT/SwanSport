import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_data/swansport_data.dart';

import '../design/swan_palette.dart';
import '../design/swan_shape.dart';
import '../design/swan_type.dart';

/// Yazılan metinden `@kişi` ve `#etiket` çıkaran yardımcı.
///
/// **Metin ile kimlik ayrı tutuluyor.** Kullanıcı `@Emir Yılmaz` yazıyor ama
/// veritabanına o kişinin UUID'si gidiyor. Kullanıcı adını saklasaydık, kişi
/// adını değiştirdiğinde etiket koparadı (0062 kararı).
///
/// Seçilmiş bir kişinin adı metinden silinirse etiket de düşüyor: metinde
/// görünmeyen bir etiketi göndermek, kullanıcının görmediği bir bildirim
/// üretmek olurdu.
class TagState {
  TagState();

  /// Seçilen kişiler: görünen ad → profil kimliği.
  final Map<String, String> _picked = {};

  void pick(MentionCandidate c) => _picked[c.handle] = c.profileId;

  /// Metinde hâlâ geçen etiketlerin kimlikleri.
  List<String> mentionsIn(String text) {
    final out = <String>[];
    for (final e in _picked.entries) {
      if (text.contains('@${e.key}')) out.add(e.value);
    }
    return out.toSet().toList();
  }

  /// Kullanıcının seçtiği ama metinden sildiği kişi sayısı — uyarı için.
  int droppedIn(String text) =>
      _picked.keys.where((k) => !text.contains('@$k')).length;

  /// Metindeki hashtag'ler. `tr_fold` ile normalleştiriliyor; sunucu da
  /// aynısını yapıyor, ikisi ayrışırsa aynı etiket iki kayda bölünür.
  static List<String> hashtagsIn(String text) => _hashtagRe
      .allMatches(text)
      .map((m) => trFold(m.group(1)!))
      .where((t) => t.isNotEmpty)
      .toSet()
      .toList();

  /// İmlecin hemen solunda yarım kalmış bir `@` ya da `#` var mı.
  ///
  /// Boşluk gelince arama kapanıyor: `@Emir ` yazıp devam eden kişiye öneri
  /// göstermeye devam etmek, listeyi kapatmak için ayrı bir hareket
  /// gerektirirdi.
  static ({String sigil, String query, int start})? activeToken(
      String text, int cursor) {
    if (cursor <= 0 || cursor > text.length) return null;
    final head = text.substring(0, cursor);
    final at = head.lastIndexOf('@');
    final hash = head.lastIndexOf('#');
    final i = at > hash ? at : hash;
    if (i < 0) return null;

    // Kelime başında olmalı: "e-posta@adres" etiketleme değil.
    if (i > 0 && !_boundary.hasMatch(head[i - 1])) return null;

    final q = head.substring(i + 1);
    if (q.contains(RegExp(r'\s'))) return null;
    return (sigil: head[i], query: q, start: i);
  }

  /// `#` yalnızca **kelime başında** etiket sayılıyor.
  ///
  /// Sınır kontrolü olmadan `renk#123` içindeki `#123` de etiket oluyordu —
  /// `activeToken` bu kontrolü yapıyordu ama burada yoktu ve ikisi
  /// ayrışmıştı. Lookbehind yerine grup kullanılıyor: Safari'de lookbehind
  /// desteği geç geldi ve bu kod web'de de çalışıyor.
  ///
  /// `\w` Türkçe harfleri kapsamıyor (`[A-Za-z0-9_]`), o yüzden açıkça
  /// yazılıyor — yoksa "#Işıklar" etiketi "#I" diye kesilirdi.
  static final _hashtagRe =
      RegExp(r'(?:^|\s)#([\wçğıöşüÇĞİÖŞÜ]+)', unicode: true, multiLine: true);

  static final _boundary = RegExp(r'\s');
}

/// Metin alanının altında açılan öneri şeridi.
///
/// Yalnızca aktif bir `@`/`#` varken çiziliyor. Sürekli açık durmak, küçük
/// ekranda yazı alanının yarısını yiyordu.
class TagSuggestions extends ConsumerWidget {
  const TagSuggestions({
    super.key,
    required this.controller,
    required this.tags,
    required this.onChanged,
  });

  final TextEditingController controller;
  final TagState tags;

  /// Metin değiştiğinde üst sayfanın yeniden çizilmesi için.
  final VoidCallback onChanged;

  void _insert(String replacement, int start) {
    final sel = controller.selection.baseOffset;
    final text = controller.text;
    final before = text.substring(0, start);
    final after = sel >= 0 && sel <= text.length ? text.substring(sel) : '';
    final next = '$before$replacement $after';
    controller.value = TextEditingValue(
      text: next,
      selection:
          TextSelection.collapsed(offset: (before + replacement).length + 1),
    );
    onChanged();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.swan;
    final sel = controller.selection.baseOffset;
    final token = TagState.activeToken(controller.text, sel);
    if (token == null) return const SizedBox.shrink();

    // Tek harf bile aranıyor; boşken de öneri geliyor (takip ettiklerin).
    final isMention = token.sigil == '@';
    final async = isMention
        ? ref.watch(mentionSearchProvider(token.query))
        : ref.watch(hashtagSearchProvider(token.query));

    return async.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: SwanSpace.sm),
            child: Text(
              isMention
                  ? 'Eşleşen kişi yok'
                  : 'Yeni etiket: #${trFold(token.query)}',
              style: SwanType.caption(c.inkMuted),
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.only(top: SwanSpace.sm),
          constraints: const BoxConstraints(maxHeight: 172),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(SwanRadius.sm),
            border: Border.all(color: c.line),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: list.length,
            itemBuilder: (_, i) {
              if (isMention) {
                final m = (list as List<MentionCandidate>)[i];
                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: CircleAvatar(
                    radius: 15,
                    backgroundColor: c.surfaceAlt,
                    child: Text(m.initials,
                        style: SwanType.caption(c.ink, w: FontWeight.w700)),
                  ),
                  title: Text(m.fullName, style: SwanType.bodySm(c.ink)),
                  subtitle: m.username == null
                      ? null
                      : Text('@${m.username}',
                          style: SwanType.caption(c.inkMuted)),
                  onTap: () {
                    tags.pick(m);
                    _insert('@${m.handle}', token.start);
                  },
                );
              }

              final h = (list as List<HashtagSuggestion>)[i];
              return ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: Icon(Icons.tag_rounded, size: 18, color: c.inkMuted),
                title: Text('#${h.tag}', style: SwanType.bodySm(c.ink)),
                trailing: Text('${h.postCount}',
                    style: SwanType.caption(c.inkMuted)),
                onTap: () => _insert('#${h.tag}', token.start),
              );
            },
          ),
        );
      },
    );
  }
}

/// Metinde geçen etiketleri özetleyen küçük şerit.
class TagSummary extends StatelessWidget {
  const TagSummary({super.key, required this.text, required this.tags});

  final String text;
  final TagState tags;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final mentions = tags.mentionsIn(text).length;
    final hashtags = TagState.hashtagsIn(text);
    final dropped = tags.droppedIn(text);

    if (mentions == 0 && hashtags.isEmpty && dropped == 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: SwanSpace.sm),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (mentions > 0)
            _chip(c, Icons.alternate_email_rounded, '$mentions kişi'),
          for (final h in hashtags.take(6)) _chip(c, Icons.tag_rounded, h),
          if (hashtags.length > 6)
            Text('+${hashtags.length - 6}',
                style: SwanType.caption(c.inkMuted)),
          // Metinden silinen etiket sessizce düşüyor; kullanıcı bunu
          // bilmeli, yoksa "ben onu etiketlemiştim" der.
          if (dropped > 0)
            Text('$dropped etiket metinden silindi',
                style: SwanType.caption(c.warning)),
        ],
      ),
    );
  }

  Widget _chip(SwanPalette c, IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.line),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: c.inkMuted),
          const SizedBox(width: 4),
          Text(label, style: SwanType.caption(c.inkMuted)),
        ]),
      );
}
