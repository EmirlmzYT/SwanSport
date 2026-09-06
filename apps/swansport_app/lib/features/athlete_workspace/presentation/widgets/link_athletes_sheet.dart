import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';

/// Hesaba bağlı olmayan kadro kayıtlarını eşleştirme.
///
/// **Kayıt silinip yeniden oluşturulmuyor.** Yoklama, aidat, performans
/// testi ve gelişim hedefleri `athlete_id`'ye bağlı; silip yeniden eklemek
/// o geçmişi kaybettirirdi. `link_athlete_to_member` (0076) yalnızca
/// `profile_id` alanını dolduruyor.
///
/// İki adım: önce hangi kayıt, sonra hangi hesap. Tek listede birleştirmek
/// (her kaydın yanında bir seçici) kalabalık kulüpte okunmaz olurdu.
Future<bool?> showLinkAthletesSheet(BuildContext context, String clubId) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LinkSheet(clubId: clubId),
    );

class _LinkSheet extends ConsumerStatefulWidget {
  const _LinkSheet({required this.clubId});

  final String clubId;

  @override
  ConsumerState<_LinkSheet> createState() => _LinkSheetState();
}

class _LinkSheetState extends ConsumerState<_LinkSheet> {
  UnlinkedAthlete? _picked;
  bool _busy = false;
  String? _error;
  bool _changed = false;

  Future<void> _link(ClubMemberCandidate m) async {
    final a = _picked;
    if (a == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(athleteServiceProvider)
          .linkAthleteToMember(a.athleteId, m.profileId);
      ref.invalidate(unlinkedAthletesProvider(widget.clubId));
      ref.invalidate(clubMemberCandidatesProvider(widget.clubId));
      ref.invalidate(clubAthletesProvider);
      if (mounted) {
        setState(() {
          _picked = null;
          _changed = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = _clean('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _clean(String raw) {
    final m = RegExp(r'message:\s*([^,)]+)').firstMatch(raw);
    return m?.group(1)?.trim() ?? raw;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;

    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(SwanRadius.lg)),
      ),
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: SwanSpace.md),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: c.line, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.all(SwanSpace.lg),
            child: Row(children: [
              if (_picked != null)
                GestureDetector(
                  onTap: () => setState(() => _picked = null),
                  child: Padding(
                    padding: const EdgeInsets.only(right: SwanSpace.sm),
                    child: Icon(Icons.arrow_back_rounded,
                        size: 18, color: c.ink),
                  ),
                ),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _picked == null
                            ? 'Hesaba bağlı olmayan sporcular'
                            : _picked!.fullName,
                        style: SwanType.h3(c.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _picked == null
                            ? 'Bu sporcular giriş yapamaz, kendi antrenmanlarını '
                                'göremez ve bildirim almaz.'
                            : 'Bu kaydı hangi hesaba bağlayacaksın? Geçmişi '
                                'olduğu gibi kalır.',
                        style: SwanType.caption(c.inkMuted),
                      ),
                    ]),
              ),
            ]),
          ),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  SwanSpace.lg, 0, SwanSpace.lg, SwanSpace.sm),
              child: Text(_error!, style: SwanType.bodySm(c.danger)),
            ),

          Flexible(
            child: _busy
                ? const Padding(
                    padding: EdgeInsets.all(SwanSpace.xl),
                    child: Center(child: CircularProgressIndicator()))
                : _picked == null
                    ? _athleteList(c)
                    : _memberList(c),
          ),
          const SizedBox(height: SwanSpace.lg),
        ]),
      ),
    );
  }

  Widget _athleteList(SwanPalette c) {
    final list = ref.watch(unlinkedAthletesProvider(widget.clubId));
    return list.when(
      loading: () => const Padding(
          padding: EdgeInsets.all(SwanSpace.xl),
          child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(SwanSpace.lg),
        child: Text('$e', style: SwanType.bodySm(c.danger)),
      ),
      data: (rows) => rows.isEmpty
          ? Padding(
              padding: const EdgeInsets.fromLTRB(
                  SwanSpace.lg, 0, SwanSpace.lg, SwanSpace.lg),
              child: Text(
                _changed
                    ? 'Hepsi bağlandı.'
                    : 'Bütün sporcular bir hesaba bağlı.',
                style: SwanType.bodySm(c.inkMuted),
              ),
            )
          : ListView.builder(
              shrinkWrap: true,
              itemCount: rows.length,
              itemBuilder: (_, i) => ListTile(
                leading: Icon(Icons.link_off_rounded, size: 20, color: c.warning),
                title: Text(rows[i].fullName, style: SwanType.body(c.ink)),
                trailing: Icon(Icons.chevron_right_rounded,
                    size: 18, color: c.inkMuted),
                onTap: () => setState(() => _picked = rows[i]),
              ),
            ),
    );
  }

  Widget _memberList(SwanPalette c) {
    final list = ref.watch(clubMemberCandidatesProvider(widget.clubId));
    return list.when(
      loading: () => const Padding(
          padding: EdgeInsets.all(SwanSpace.xl),
          child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(SwanSpace.lg),
        child: Text('$e', style: SwanType.bodySm(c.danger)),
      ),
      data: (rows) => rows.isEmpty
          ? Padding(
              padding: const EdgeInsets.fromLTRB(
                  SwanSpace.lg, 0, SwanSpace.lg, SwanSpace.lg),
              child: Text(
                'Bağlanabilecek üye yok. Kişi önce kulübüne katılmalı — '
                'başvurusunu onayladığında burada görünür.',
                style: SwanType.bodySm(c.inkMuted),
              ),
            )
          : ListView.builder(
              shrinkWrap: true,
              itemCount: rows.length,
              itemBuilder: (_, i) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: c.surfaceAlt,
                  backgroundImage: rows[i].avatarUrl == null
                      ? null
                      : NetworkImage(rows[i].avatarUrl!),
                  child: rows[i].avatarUrl != null
                      ? null
                      : Icon(Icons.person_rounded,
                          size: 18, color: c.inkMuted),
                ),
                title: Text(rows[i].displayName,
                    style: SwanType.body(
                        rows[i].hasName ? c.ink : c.inkMuted)),
                trailing: Text('Bağla', style: SwanType.bodySm(c.accent)),
                onTap: () => _link(rows[i]),
              ),
            ),
    );
  }
}
