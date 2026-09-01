import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';
import 'widgets/social_widgets.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/design/swan_palette.dart';

/// Arama — kulüpler, antrenörler ve sporcular.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;

  String _query = '';
  int _filter = 0; // 0 hepsi, 1 kulüp, 2 antrenör, 3 sporcu
  static const _filters = ['Hepsi', 'Kulüpler', 'Antrenörler', 'Sporcular'];

  List<SuggestionRow> _results = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(value));
  }

  Future<void> _run(String value) async {
    setState(() {
      _query = value;
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(socialServiceProvider).search(value);
      if (!mounted || _query != value) return;
      setState(() {
        _results = res;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  List<SuggestionRow> get _visible => switch (_filter) {
        1 => _results.where((r) => r.kind == 'club').toList(),
        2 => _results.where((r) => r.kind == 'coach').toList(),
        3 => _results.where((r) => r.kind == 'athlete').toList(),
        _ => _results,
      };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = (isDark ? SwanPalette.dark : SwanPalette.light).bg;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    final alt = (isDark ? SwanPalette.dark : SwanPalette.light).surfaceAlt;
    final list = _visible;

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
                // Başlık + arama alanı
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
                      child: TextField(
                        controller: _ctrl,
                        autofocus: true,
                        onChanged: _onChanged,
                        onSubmitted: _run,
                        textInputAction: TextInputAction.search,
                        style: SwanType.bodySm(ink, w: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: 'Kulüp, antrenör veya sporcu ara…',
                          hintStyle: SwanType.bodySm(SwanColors.textSecondary),
                          prefixIcon: Icon(Icons.search_rounded,
                              size: 20, color: SwanColors.textSecondary),
                          suffixIcon: _ctrl.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: Icon(Icons.close_rounded,
                                      size: 18,
                                      color: SwanColors.textSecondary),
                                  onPressed: () {
                                    _ctrl.clear();
                                    _run('');
                                  },
                                ),
                          filled: true,
                          fillColor: alt,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 13),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: line)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                                  const BorderSide(color: kTeal, width: 1.5)),
                        ),
                      ),
                    ),
                  ]),
                ),

                // Süzgeçler
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _filters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => _chip(isDark, _filters[i], i),
                  ),
                ),
                const SizedBox(height: 10),

                Expanded(
                  child: Builder(builder: (_) {
                    if (_loading) return premiumLoading();
                    if (_error != null) {
                      return premiumError(context, _error!);
                    }
                    if (list.isEmpty) {
                      return premiumEmpty(
                        context,
                        icon: Icons.search_off_rounded,
                        title: _query.trim().isEmpty
                            ? 'Aramaya başla'
                            : 'Sonuç bulunamadı',
                        subtitle: _query.trim().isEmpty
                            ? 'Kulüp, antrenör veya sporcu adı yaz.'
                            : '“${_query.trim()}” için eşleşme yok.',
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 132),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _tile(isDark, list[i]),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _chip(bool isDark, String label, int i) {
    final on = _filter == i;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    return GestureDetector(
      onTap: () => setState(() => _filter = i),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: on ? kTeal : surf,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? kTeal : line),
        ),
        child: Text(label,
            style: SwanType.caption(on ? Colors.white : SwanColors.textSecondary, w: FontWeight.w700)),
      ),
    );
  }

  Widget _tile(bool isDark, SuggestionRow r) {
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;

    final (badgeLabel, badgeColor) = switch (r.kind) {
      'club' => ('Kulüp', kTeal),
      'coach' => ('Antrenör', const Color(0xFF7C5CE6)),
      'athlete' => ('Sporcu', SwanPalette.light.success),
      _ => ('Üye', SwanColors.textSecondary),
    };

    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        r.isClub ? '/kulup-profil' : '/profil',
        arguments: r.id,
      ),
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
            initials: r.initials,
            imageUrl: r.avatarUrl,
            size: 44,
            gradientIndex: r.name.length % 4,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SwanType.bodySm(ink, w: FontWeight.w800)),
                if (r.subtitle != null)
                  Text(r.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SwanType.caption(SwanColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(badgeLabel,
                style: SwanType.caption(badgeColor, w: FontWeight.w800)),
          ),
        ]),
      ),
    );
  }
}
