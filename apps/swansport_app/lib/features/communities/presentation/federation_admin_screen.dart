import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';
import '../../social/presentation/widgets/social_widgets.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/design/swan_palette.dart';

/// Federasyon yetkilisi atama — yalnızca platform yöneticisi.
///
/// Duyuru yazma yetkisi kendiliğinden verilemez: birinin "ben federasyonum"
/// deyip binlerce antrenöre duyuru geçmesini engelleyen tek şey bu ekran.
class FederationAdminScreen extends ConsumerStatefulWidget {
  const FederationAdminScreen({super.key});

  @override
  ConsumerState<FederationAdminScreen> createState() =>
      _FederationAdminScreenState();
}

class _FederationAdminScreenState
    extends ConsumerState<FederationAdminScreen> {
  final _search = TextEditingController();
  CommunityRow? _channel;
  List<SuggestionRow> _results = const [];
  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _find(String q) async {
    if (q.trim().length < 2) {
      setState(() => _results = const []);
      return;
    }
    try {
      final res = await ref.read(socialServiceProvider).search(q.trim());
      if (mounted) {
        setState(() =>
            _results = res.where((r) => r.kind != 'club').take(20).toList());
      }
    } catch (_) {
      if (mounted) setState(() => _results = const []);
    }
  }

  Future<void> _assign(SuggestionRow person) async {
    final channel = _channel;
    if (channel == null || _busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(communityServiceProvider)
          .setStaff(channel.id, person.id, true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${person.name} → ${channel.name} yetkilisi'),
            backgroundColor: kTeal));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Atanamadı: $e'),
            backgroundColor: SwanPalette.light.danger));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = (isDark ? SwanPalette.dark : SwanPalette.light).bg;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;

    final channels = ref.watch(federationChannelsProvider);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(children: [
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
                  Text('Federasyon Yetkilileri',
                      style: SwanType.h3(ink)),
                ]),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                  children: [
                    Text('1 · KANAL SEÇ',
                        style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w800)),
                    const SizedBox(height: 10),
                    channels.when(
                      loading: () => premiumLoading(),
                      error: (e, _) => premiumError(context, '$e'),
                      data: (list) => Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final c in list)
                            GestureDetector(
                              onTap: () => setState(() => _channel = c),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 13, vertical: 9),
                                decoration: BoxDecoration(
                                  color: _channel?.id == c.id
                                      ? kTeal
                                      : surf,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: _channel?.id == c.id
                                          ? kTeal
                                          : line),
                                ),
                                child: Text(c.name,
                                    style: SwanType.caption(_channel?.id == c.id
                                            ? Colors.white
                                            : ink, w: FontWeight.w700)),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('2 · KİŞİ ARA',
                        style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w800)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _search,
                      onChanged: _find,
                      style: SwanType.bodySm(ink),
                      decoration: InputDecoration(
                        hintText: 'Ad veya kullanıcı adı…',
                        hintStyle: SwanType.bodySm(SwanColors.textSecondary),
                        prefixIcon: const Icon(Icons.search_rounded, size: 19),
                        filled: true,
                        fillColor: surf,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: line)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_channel == null)
                      Text('Önce bir kanal seç.',
                          style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600))
                    else
                      for (final r in _results)
                        Container(
                          margin: const EdgeInsets.only(bottom: 9),
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: surf,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: line),
                          ),
                          child: Row(children: [
                            SocialAvatar(
                                initials:
                                    r.name.isEmpty ? '?' : r.name[0],
                                imageUrl: r.avatarUrl,
                                size: 38),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.name,
                                      style: SwanType.bodySm(ink, w: FontWeight.w700)),
                                  if (r.subtitle != null)
                                    Text(r.subtitle!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: SwanType.caption(SwanColors.textSecondary)),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _assign(r),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                      colors: [kTealBright, kTeal]),
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Text('Yetkili yap',
                                    style: SwanType.caption(Colors.white, w: FontWeight.w800)),
                              ),
                            ),
                          ]),
                        ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
