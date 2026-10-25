import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../app/modules/console_module.dart';
import '../../app/shell/too_narrow_notice.dart';
import '../../app/theme/console_theme.dart';
import '../../app/widgets/status_pill.dart';
import '../federation/referee_assignments_screen.dart' show federationDate;

String _dutyLabel(MatchOfficialDuty d) => switch (d) {
  MatchOfficialDuty.headReferee => 'Başhakem',
  MatchOfficialDuty.assistantReferee1 => '1. Yardımcı Hakem',
  MatchOfficialDuty.assistantReferee2 => '2. Yardımcı Hakem',
  MatchOfficialDuty.fourthReferee => '4. Hakem',
  MatchOfficialDuty.tableOfficial => 'Masa Hakemi',
  MatchOfficialDuty.observer => 'Gözlemci',
};

String _tierLabel(RefereeBadgeTier tier) => switch (tier) {
  RefereeBadgeTier.candidate => 'Aday Hakem',
  RefereeBadgeTier.provincial => 'İl Hakemi',
  RefereeBadgeTier.national => 'Ulusal Hakem',
  RefereeBadgeTier.international => 'Uluslararası / FİBA / FIFA',
};

class RefereeCockpitScreen extends ConsumerStatefulWidget {
  const RefereeCockpitScreen({super.key});

  @override
  ConsumerState<RefereeCockpitScreen> createState() => _RefereeCockpitScreenState();
}

class _RefereeCockpitScreenState extends ConsumerState<RefereeCockpitScreen> {
  int _tab = 0;
  final Set<String> _busy = {};
  String? _error;

  Future<void> _respond(RefereeMatchSummary match, bool accept) async {
    if (_busy.contains(match.officialId)) return;
    String? reason;
    if (!accept) {
      final controller = TextEditingController();
      try {
        reason = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Görev Mazereti Bildir'),
            content: TextField(
              controller: controller,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Mazeret gerekçeniz',
                hintText: 'Örn. Sağlık mazereti veya il dışı seyahat',
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
              FilledButton(
                onPressed: () {
                  if (controller.text.trim().isNotEmpty) {
                    Navigator.pop(ctx, controller.text.trim());
                  }
                },
                child: const Text('Mazeret Gönder'),
              ),
            ],
          ),
        );
      } finally {
        controller.dispose();
      }
      if (reason == null || !mounted) return;
    }

    setState(() {
      _busy.add(match.officialId);
      _error = null;
    });

    try {
      final service = ref.read(sportsRolesServiceProvider);
      if (service == null) throw StateError('Çevrimiçi servis bağlantısı kurulamadı.');
      await service.respondMatchAssignment(match.officialId, accept, reason: reason);
      ref.invalidate(myRefereeMatchesProvider);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy.remove(match.officialId));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < ConsoleDensity.minSupportedWidth) {
      return const TooNarrowNotice();
    }
    final access = ref.watch(consoleAccessProvider);
    if (!access.isReferee && !access.isPlatformAdmin) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(ConsoleDensity.xl),
          child: Text('Bu modülü görüntülemek için onaylanmış bir hakem lisansı veya platform yönetici yetkisi gereklidir.'),
        ),
      );
    }

    final matchesAsync = ref.watch(refereeDutyMatchesProvider);
    final profileAsync = ref.watch(myRefereeProfileProvider);
    final t = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(ConsoleDensity.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: t.colorScheme.primary.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(ConsoleDensity.radius),
                  border: Border.all(color: t.colorScheme.primary.withValues(alpha: .32)),
                ),
                child: Icon(Icons.sports_score_rounded, color: t.colorScheme.primary, size: 24),
              ),
              const SizedBox(width: ConsoleDensity.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hakem Kokpiti & Müsabaka Yönetimi', style: t.textTheme.headlineSmall),
                    const SizedBox(height: 2),
                    Text(
                      'Resmi görevlendirmeler, esame listesi kontrolleri, canlı müsabaka kontrolü ve maç raporu',
                      style: t.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Yenile',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () {
                  ref.invalidate(refereeDutyMatchesProvider);
                  ref.invalidate(myRefereeProfileProvider);
                },
              ),
            ],
          ),
          const SizedBox(height: ConsoleDensity.lg),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Yaklaşan & Bugünkü Görevler'), icon: Icon(Icons.event_available_rounded)),
              ButtonSegment(value: 1, label: Text('Tamamlanan Görevler'), icon: Icon(Icons.history_rounded)),
              ButtonSegment(value: 2, label: Text('Hakem Lisans Kartı'), icon: Icon(Icons.badge_rounded)),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
          if (_error != null) ...[
            const SizedBox(height: ConsoleDensity.md),
            Container(
              padding: const EdgeInsets.all(ConsoleDensity.md),
              decoration: BoxDecoration(
                color: SwanColors.error.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(ConsoleDensity.radius),
                border: Border.all(color: SwanColors.error.withValues(alpha: .3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: SwanColors.error),
                  const SizedBox(width: ConsoleDensity.md),
                  Expanded(child: Text(_error!, style: TextStyle(color: SwanColors.error))),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    onPressed: () => setState(() => _error = null),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: ConsoleDensity.lg),
          Expanded(
            child: _tab == 2
                ? _RefereeProfileView(profile: profileAsync)
                : matchesAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Görev listesi alınamadı: $e'),
                          const SizedBox(height: ConsoleDensity.md),
                          FilledButton.icon(
                            onPressed: () => ref.invalidate(refereeDutyMatchesProvider),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Tekrar Dene'),
                          ),
                        ],
                      ),
                    ),
                    data: (matches) {
                      final active = matches.where((m) {
                        final isScheduled = m.matchStatus == 'scheduled' || m.matchStatus == 'in_progress';
                        final assigned = m.status == MatchOfficialStatus.assigned || m.status == MatchOfficialStatus.accepted;
                        return _tab == 0 ? (isScheduled && assigned) : (!isScheduled || m.status == MatchOfficialStatus.declined);
                      }).toList();

                      if (active.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.sports_rounded, size: 48, color: t.colorScheme.outline),
                              const SizedBox(height: ConsoleDensity.md),
                              Text(
                                _tab == 0 ? 'Şu anda bekleyen veya yaklaşan bir müsabaka göreviniz yok.' : 'Kayıtlı geçmiş görev bulunamadı.',
                                style: t.textTheme.titleMedium,
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: active.length,
                        separatorBuilder: (_, __) => const SizedBox(height: ConsoleDensity.md),
                        itemBuilder: (ctx, i) {
                          final m = active[i];
                          final isBusy = _busy.contains(m.officialId);

                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(ConsoleDensity.radius),
                              side: BorderSide(color: t.colorScheme.outline),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(ConsoleDensity.lg),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: t.colorScheme.primary.withValues(alpha: .12),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          m.sportCode.toUpperCase(),
                                          style: t.textTheme.labelSmall?.copyWith(
                                            color: t.colorScheme.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: ConsoleDensity.sm),
                                      Expanded(
                                        child: Text(
                                          '${m.homeClubName ?? 'Ev Sahibi'} vs ${m.awayClubName ?? 'Deplasman'}',
                                          style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      StatusPill(
                                        label: _dutyLabel(m.duty),
                                        tone: PillTone.info,
                                      ),
                                      const SizedBox(width: ConsoleDensity.xs),
                                      StatusPill(
                                        label: switch (m.status) {
                                          MatchOfficialStatus.assigned => 'Görev Atandı (Yanıt Bekliyor)',
                                          MatchOfficialStatus.accepted => 'Kabul Edildi',
                                          MatchOfficialStatus.declined => 'Mazeret Bildirildi',
                                          MatchOfficialStatus.replaced => 'Değiştirildi',
                                        },
                                        tone: switch (m.status) {
                                          MatchOfficialStatus.accepted => PillTone.good,
                                          MatchOfficialStatus.assigned => PillTone.warning,
                                          _ => PillTone.bad,
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: ConsoleDensity.sm),
                                  Wrap(
                                    spacing: ConsoleDensity.lg,
                                    runSpacing: ConsoleDensity.xs,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.schedule_rounded, size: 16),
                                          const SizedBox(width: ConsoleDensity.xs),
                                          Text(federationDate(m.startsAt)),
                                        ],
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.stadium_rounded, size: 16),
                                          const SizedBox(width: ConsoleDensity.xs),
                                          Text(m.location ?? 'Saha belirtilmedi'),
                                        ],
                                      ),
                                      if (m.cityCode != null)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.location_city_rounded, size: 16),
                                            const SizedBox(width: ConsoleDensity.xs),
                                            Text('İl: ${m.cityCode}'),
                                          ],
                                        ),
                                    ],
                                  ),
                                  if (m.declineReason != null) ...[
                                    const SizedBox(height: ConsoleDensity.sm),
                                    Text('Mazeret Notu: ${m.declineReason}', style: t.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                                  ],
                                  const SizedBox(height: ConsoleDensity.md),
                                  Divider(height: 1, color: t.colorScheme.outlineVariant),
                                  const SizedBox(height: ConsoleDensity.md),
                                  if (isBusy)
                                    const Center(child: CircularProgressIndicator())
                                  else
                                    Wrap(
                                      spacing: ConsoleDensity.md,
                                      runSpacing: ConsoleDensity.sm,
                                      children: [
                                        if (m.status == MatchOfficialStatus.assigned && m.matchStatus == 'scheduled') ...[
                                          FilledButton.icon(
                                            onPressed: () => _respond(m, true),
                                            icon: const Icon(Icons.check_rounded, size: 18),
                                            label: const Text('Görevi Kabul Et'),
                                          ),
                                          OutlinedButton.icon(
                                            onPressed: () => _respond(m, false),
                                            icon: const Icon(Icons.close_rounded, size: 18),
                                            label: const Text('Mazeret Bildir'),
                                          ),
                                        ],
                                        if (m.canControl && m.matchStatus == 'scheduled')
                                          OutlinedButton.icon(
                                            onPressed: () => showDialog<void>(
                                              context: context,
                                              builder: (_) => _RefereeLineupDialog(match: m),
                                            ),
                                            icon: const Icon(Icons.fact_check_rounded, size: 18),
                                            label: const Text('Esame Kontrolü & Kilitle'),
                                          ),
                                        if (m.canControl && (m.matchStatus == 'scheduled' || m.matchStatus == 'in_progress'))
                                          FilledButton.tonalIcon(
                                            onPressed: () => showDialog<void>(
                                              context: context,
                                              builder: (_) => _RefereeLiveCockpitDialog(match: m),
                                            ),
                                            icon: const Icon(Icons.sports_rounded, size: 18),
                                            label: const Text('Canlı Maç Yönetimi'),
                                          ),
                                        OutlinedButton.icon(
                                          onPressed: () => showDialog<void>(
                                            context: context,
                                            builder: (_) => _RefereeMatchReportDialog(match: m),
                                          ),
                                          icon: const Icon(Icons.assignment_turned_in_rounded, size: 18),
                                          label: const Text('Hakem Raporu'),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RefereeProfileView extends StatelessWidget {
  const _RefereeProfileView({required this.profile});

  final AsyncValue<RefereeProfile?> profile;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return profile.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hakem profili alınamadı: $e')),
      data: (p) {
        if (p == null) {
          return const Center(child: Text('Onaylanmış aktif hakem profiliniz bulunmuyor.'));
        }
        return Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ConsoleDensity.radius),
                side: BorderSide(color: t.colorScheme.outline),
              ),
              child: Padding(
                padding: const EdgeInsets.all(ConsoleDensity.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: t.colorScheme.primary.withValues(alpha: .15),
                          child: Icon(Icons.badge_rounded, color: t.colorScheme.primary, size: 28),
                        ),
                        const SizedBox(width: ConsoleDensity.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Hakem Lisans Kartı', style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                              Text(_tierLabel(p.badgeTier), style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.primary)),
                            ],
                          ),
                        ),
                        StatusPill(
                          label: p.isActive ? 'Aktif Lisans' : 'Pasif',
                          tone: p.isActive ? PillTone.good : PillTone.bad,
                        ),
                      ],
                    ),
                    const SizedBox(height: ConsoleDensity.xl),
                    const Divider(),
                    const SizedBox(height: ConsoleDensity.md),
                    _ProfileRow(label: 'Lisans Numarası', value: p.licenseNumber),
                    _ProfileRow(label: 'Kayıtlı Branş', value: p.sportCode.toUpperCase()),
                    _ProfileRow(label: 'Yetkili Bölge / İl', value: 'İl Kodu ${p.cityCode}'),
                    _ProfileRow(label: 'Kademe Seviyesi', value: _tierLabel(p.badgeTier)),
                    _ProfileRow(label: 'Durum', value: p.isActive ? 'Müsabaka görevlendirmelerine açık' : 'Görevlendirmeye kapalı'),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ConsoleDensity.xs + 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          Text(value, style: t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _RefereeLineupDialog extends ConsumerStatefulWidget {
  const _RefereeLineupDialog({required this.match});
  final RefereeMatchSummary match;

  @override
  ConsumerState<_RefereeLineupDialog> createState() => _RefereeLineupDialogState();
}

class _RefereeLineupDialogState extends ConsumerState<_RefereeLineupDialog> {
  int _sideTab = 0;
  bool _busy = false;
  String? _error;
  final Map<String, String> _selections = {};

  Future<void> _lock(List<RefereeLineupCandidate> rows) async {
    if (_busy) return;
    final homeStarters = rows.where((r) => r.side == 'home' && (_selections[r.athleteId] ?? r.selection) == 'starter').map((r) => r.athleteId).toList();
    final awayStarters = rows.where((r) => r.side == 'away' && (_selections[r.athleteId] ?? r.selection) == 'starter').map((r) => r.athleteId).toList();
    final homeSubs = rows.where((r) => r.side == 'home' && (_selections[r.athleteId] ?? r.selection) == 'substitute').map((r) => r.athleteId).toList();
    final awaySubs = rows.where((r) => r.side == 'away' && (_selections[r.athleteId] ?? r.selection) == 'substitute').map((r) => r.athleteId).toList();

    if (homeStarters.isEmpty || awayStarters.isEmpty) {
      setState(() => _error = 'Her iki takım için en az bir ilk 11/sahaya çıkan sporcu seçilmelidir.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final service = ref.read(sportsRolesServiceProvider);
      if (service == null) throw StateError('Bağlantı kurulamadı.');
      await service.verifyMatchLineup(
        widget.match.matchId,
        homeStarters,
        awayStarters,
        homeSubs: homeSubs,
        awaySubs: awaySubs,
      );
      ref.invalidate(matchLineupApprovalsProvider(widget.match.matchId));
      ref.invalidate(refereeLineupCandidatesProvider(widget.match.matchId));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final candidatesAsync = ref.watch(refereeLineupCandidatesProvider(widget.match.matchId));
    final approvalsAsync = ref.watch(matchLineupApprovalsProvider(widget.match.matchId));
    final isLocked = (approvalsAsync.asData?.value ?? []).isNotEmpty;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(ConsoleDensity.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.fact_check_rounded, color: t.colorScheme.primary),
                  const SizedBox(width: ConsoleDensity.sm),
                  Expanded(
                    child: Text('Dijital Esame Listesi Kontrolü', style: t.textTheme.titleLarge),
                  ),
                  if (isLocked)
                    const StatusPill(label: 'Esame Kilitlendi', tone: PillTone.good),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              Text(
                '${widget.match.homeClubName ?? 'Ev Sahibi'} — ${widget.match.awayClubName ?? 'Deplasman'}',
                style: t.textTheme.bodySmall,
              ),
              const SizedBox(height: ConsoleDensity.md),
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(value: 0, label: Text(widget.match.homeClubName ?? 'Ev Sahibi Takım')),
                  ButtonSegment(value: 1, label: Text(widget.match.awayClubName ?? 'Deplasman Takımı')),
                ],
                selected: {_sideTab},
                onSelectionChanged: (s) => setState(() => _sideTab = s.first),
              ),
              if (_error != null) ...[
                const SizedBox(height: ConsoleDensity.sm),
                Text(_error!, style: TextStyle(color: SwanColors.error)),
              ],
              const SizedBox(height: ConsoleDensity.md),
              Expanded(
                child: candidatesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Kadro listesi alınamadı: $e')),
                  data: (candidates) {
                    final side = _sideTab == 0 ? 'home' : 'away';
                    final sideCandidates = candidates.where((c) => c.side == side).toList();

                    if (sideCandidates.isEmpty) {
                       return const Center(child: Text('Bu takım için bildirilmiş sporcu esamesi yok.'));
                    }

                    return ListView.separated(
                      itemCount: sideCandidates.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final c = sideCandidates[i];
                        final selection = isLocked ? c.selection : (_selections[c.athleteId] ?? c.selection);

                        return ListTile(
                          leading: CircleAvatar(
                            radius: 18,
                            child: Text(c.jerseyNumber == null ? '—' : '${c.jerseyNumber}', style: const TextStyle(fontSize: 12)),
                          ),
                          title: Text(c.name ?? c.maskedRef),
                          subtitle: Text('Lisans: ${c.licenseNumber ?? 'Belirtilmedi'} · Durum: ${switch (c.eligibilityStatus) {
                            'medical' => 'Tıbbi Engel',
                            'suspended' => 'Cezalı',
                            'rested' => 'Dinlendiriliyor',
                            _ => c.eligible ? 'Uygun' : 'Uygun Değil'
                          }}'),
                          trailing: SizedBox(
                            width: 170,
                            child: DropdownButtonFormField<String>(
                              value: selection,
                              items: const [
                                DropdownMenuItem(value: 'unselected', child: Text('Kadro Dışı')),
                                DropdownMenuItem(value: 'starter', child: Text('İlk Kadro')),
                                DropdownMenuItem(value: 'substitute', child: Text('Yedek')),
                              ],
                              onChanged: isLocked || _busy || !c.eligible
                                  ? null
                                  : (v) => setState(() => _selections[c.athleteId] = v!),
                              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: ConsoleDensity.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
                  const SizedBox(width: ConsoleDensity.md),
                  if (!isLocked)
                    candidatesAsync.maybeWhen(
                      data: (rows) => FilledButton.icon(
                        onPressed: _busy ? null : () => _lock(rows),
                        icon: const Icon(Icons.lock_rounded, size: 18),
                        label: Text(_busy ? 'Onaylanıyor…' : 'Esameyi Onayla ve Kilitle'),
                      ),
                      orElse: () => const SizedBox.shrink(),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RefereeLiveCockpitDialog extends ConsumerStatefulWidget {
  const _RefereeLiveCockpitDialog({required this.match});
  final RefereeMatchSummary match;

  @override
  ConsumerState<_RefereeLiveCockpitDialog> createState() => _RefereeLiveCockpitDialogState();
}

class _RefereeLiveCockpitDialogState extends ConsumerState<_RefereeLiveCockpitDialog> {
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final stateAsync = ref.watch(refereeMatchStateProvider(widget.match.matchId));
    final mutation = ref.watch(refereeMutationProvider(widget.match.matchId));
    final controller = ref.read(refereeMutationProvider(widget.match.matchId).notifier);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(ConsoleDensity.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.sports_rounded, color: t.colorScheme.primary),
                  const SizedBox(width: ConsoleDensity.sm),
                  Expanded(
                    child: Text('Canlı Müsabaka Yönetim Kokpiti', style: t.textTheme.titleLarge),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              Text(
                '${widget.match.sportCode.toUpperCase()} · ${widget.match.homeClubName ?? 'Ev Sahibi'} vs ${widget.match.awayClubName ?? 'Deplasman'}',
                style: t.textTheme.bodySmall,
              ),
              const SizedBox(height: ConsoleDensity.lg),
              stateAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Canlı durum alınamadı: $e')),
                data: (st) {
                  if (st == null) return const Center(child: Text('Canlı maç kaydı henüz başlatılmamış.'));
                  return Expanded(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(ConsoleDensity.lg),
                          decoration: BoxDecoration(
                            color: t.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(ConsoleDensity.radius),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  Text(widget.match.homeClubName ?? 'Ev Sahibi', style: t.textTheme.titleMedium),
                                  const SizedBox(height: ConsoleDensity.xs),
                                  Text('${st.homeScore}', style: t.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w800)),
                                  Wrap(
                                    spacing: 4,
                                    children: [
                                      IconButton.filledTonal(
                                        onPressed: mutation.busy
                                            ? null
                                            : () => controller.submit(
                                                  'referee_append_match_event',
                                                  {
                                                    'p_match_id': widget.match.matchId,
                                                    'p_operation_id': refereeOperationId(),
                                                    'p_expected_version': st.version,
                                                    'p_kind': 'score',
                                                    'p_side': 'home',
                                                  },
                                                ),
                                        icon: const Text('+1'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  Text('Periyot / Durum', style: t.textTheme.labelSmall),
                                  const SizedBox(height: 4),
                                  StatusPill(label: 'Periyot / Devre ${st.period}', tone: PillTone.info),
                                  const SizedBox(height: 8),
                                  Text('Olay Sayısı: ${st.events.length}'),
                                ],
                              ),
                              Column(
                                children: [
                                  Text(widget.match.awayClubName ?? 'Deplasman', style: t.textTheme.titleMedium),
                                  const SizedBox(height: ConsoleDensity.xs),
                                  Text('${st.awayScore}', style: t.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w800)),
                                  Wrap(
                                    spacing: 4,
                                    children: [
                                      IconButton.filledTonal(
                                        onPressed: mutation.busy
                                            ? null
                                            : () => controller.submit(
                                                  'referee_append_match_event',
                                                  {
                                                    'p_match_id': widget.match.matchId,
                                                    'p_operation_id': refereeOperationId(),
                                                    'p_expected_version': st.version,
                                                    'p_kind': 'score',
                                                    'p_side': 'away',
                                                  },
                                                ),
                                        icon: const Text('+1'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: ConsoleDensity.md),
                        Row(
                          children: [
                            Text('Canlı Olay Günlüğü', style: t.textTheme.titleSmall),
                            const Spacer(),
                            FilledButton.icon(
                              onPressed: mutation.busy
                                  ? null
                                  : () => controller.submit(
                                        'referee_append_match_event',
                                        {
                                          'p_match_id': widget.match.matchId,
                                          'p_operation_id': refereeOperationId(),
                                          'p_expected_version': st.version,
                                          'p_kind': 'period_end',
                                        },
                                      ),
                              icon: const Icon(Icons.timer_outlined, size: 16),
                              label: const Text('Periyot Tamamla'),
                            ),
                          ],
                        ),
                        const SizedBox(height: ConsoleDensity.sm),
                        Expanded(
                          child: st.events.isEmpty
                              ? const Center(child: Text('Henüz kaydedilmiş canlı müsabaka olayı yok.'))
                              : ListView.separated(
                                  itemCount: st.events.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (ctx, idx) {
                                    final ev = st.events[idx];
                                    return ListTile(
                                      leading: const Icon(Icons.bolt_rounded, size: 20),
                                      title: Text('${ev.elapsedSeconds ~/ 60}′ · ${ev.kind}'),
                                      subtitle: Text(ev.card != null
                                          ? 'Kart: ${ev.card}'
                                          : (ev.side == 'home' ? 'Ev Sahibi' : ev.side == 'away' ? 'Deplasman' : 'Genel')),
                                      trailing: Text(ev.undone ? 'İptal edildi' : 'Geçerli'),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RefereeMatchReportDialog extends ConsumerStatefulWidget {
  const _RefereeMatchReportDialog({required this.match});
  final RefereeMatchSummary match;

  @override
  ConsumerState<_RefereeMatchReportDialog> createState() => _RefereeMatchReportDialogState();
}

class _RefereeMatchReportDialogState extends ConsumerState<_RefereeMatchReportDialog> {
  final _notes = TextEditingController();
  final _redCardCount = TextEditingController(text: '0');
  final _yellowCardCount = TextEditingController(text: '0');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _notes.dispose();
    _redCardCount.dispose();
    _yellowCardCount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final ok = await ref.read(refereeMutationProvider(widget.match.matchId).notifier).submit(
        'referee_submit_match_report',
        {
          'p_match_id': widget.match.matchId,
          'p_operation_id': refereeOperationId(),
          'p_expected_version': 0,
          'p_notes': _notes.text.trim(),
        },
      );
      if (ok && mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(ConsoleDensity.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.assignment_turned_in_rounded, color: t.colorScheme.primary),
                  const SizedBox(width: ConsoleDensity.sm),
                  Expanded(
                    child: Text('Resmi Hakem Müsabaka Raporu', style: t.textTheme.titleLarge),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: ConsoleDensity.md),
              TextField(
                controller: _notes,
                maxLength: 1000,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Müsabaka Hakem Raporu & Disiplin Notları',
                  hintText: 'Saha güvenliği, ihraçlar, teknik notlar veya olaylar...',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: ConsoleDensity.sm),
                Text(_error!, style: TextStyle(color: SwanColors.error)),
              ],
              const SizedBox(height: ConsoleDensity.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
                  const SizedBox(width: ConsoleDensity.md),
                  FilledButton.icon(
                    onPressed: _busy ? null : _submit,
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: Text(_busy ? 'İmzalanıyor…' : 'Raporu İmzala ve Gönder'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
