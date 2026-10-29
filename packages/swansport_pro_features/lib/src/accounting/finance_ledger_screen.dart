import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../host/pro_feature_host.dart';
import '../host/pro_feature_state.dart';
import 'accounting_operations_panel.dart';

final class SharedFinanceLedgerScreen extends ConsumerWidget {
  const SharedFinanceLedgerScreen({
    this.header,
    super.key,
  });

  final Widget? header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ProFeatureHostScope.of(context);
    return host.chrome.buildPage(
      context,
      title: 'Mali Defter',
      body: _FinanceLedgerScopeGate(header: header),
    );
  }
}

final class _FinanceLedgerScopeGate extends ConsumerWidget {
  const _FinanceLedgerScopeGate({this.header});

  final Widget? header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(swanAccessProvider);
    if (!access.isAccountant) {
      return const AccountingPanelMessage(
        icon: Icons.lock_person_outlined,
        title: 'Muhasebe çalışma alanı yetkisi gerekli',
        body:
            'Mali defter yalnız yetkili kulüp muhasebecisi hesapları tarafından görüntülenebilir.',
      );
    }

    final flagsAsync = ref.watch(featureFlagsProvider);
    final clubsAsync = ref.watch(myClubsProvider);
    if (flagsAsync.isLoading || clubsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (flagsAsync.hasError || clubsAsync.hasError) {
      final error = flagsAsync.error ?? clubsAsync.error!;
      return AccountingPanelMessage(
        icon: Icons.error_outline_rounded,
        title: classifyOperationError(error).userMessage,
        onRetry: () {
          ref
            ..invalidate(featureFlagsProvider)
            ..invalidate(myClubsProvider);
        },
      );
    }

    final flags = flagsAsync.valueOrNull ?? const FeatureFlags.none();
    if (!flags.has(FeatureFlags.financeOperationsCenter)) {
      return const AccountingPanelMessage(
        icon: Icons.lock_clock_outlined,
        title: 'Mali operasyonlar kademeli yayında',
        body: 'Muhasebe defteri hesabın için henüz açılmadı.',
      );
    }

    final accountantClubs = resolveEffectiveAccountantClubs(
      clubsAsync.valueOrNull ?? const <ClubRef>[],
      access,
    );
    if (accountantClubs.isEmpty) {
      return const AccountingPanelMessage(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Aktif muhasebe kulüp kapsamı bulunamadı',
        body:
            'Aktif bir muhasebe kulüp kapsamı olmadan hiçbir mali sorgu çalıştırılmaz.',
      );
    }

    final selectedId = ref.watch(selectedAccountantClubIdProvider);
    final selectedClub =
        accountantClubs.where((club) => club.id == selectedId).firstOrNull ??
            accountantClubs.first;

    if (selectedId != selectedClub.id ||
        ref.watch(selectedClubIdProvider) != selectedClub.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ref.read(selectedAccountantClubIdProvider.notifier).state =
              selectedClub.id;
          ref.read(selectedClubIdProvider.notifier).state = selectedClub.id;
        }
      });
    }

    return KeyedSubtree(
      key: ValueKey<String>('finance-ledger-club-${selectedClub.id}'),
      child: _ScopedFinanceLedgerContent(
        clubs: accountantClubs,
        selectedClub: selectedClub,
        header: header,
      ),
    );
  }
}

final class _ScopedFinanceLedgerContent extends ConsumerStatefulWidget {
  const _ScopedFinanceLedgerContent({
    required this.clubs,
    required this.selectedClub,
    this.header,
  });

  final List<ClubRef> clubs;
  final ClubRef selectedClub;
  final Widget? header;

  @override
  ConsumerState<_ScopedFinanceLedgerContent> createState() =>
      _ScopedFinanceLedgerContentState();
}

final class _ScopedFinanceLedgerContentState
    extends ConsumerState<_ScopedFinanceLedgerContent> {
  static const int _pageSize = 50;
  int _offset = 0;
  String? _directionFilter;

  @override
  Widget build(BuildContext context) {
    final host = ProFeatureHostScope.of(context);
    final pageAsync = ref.watch(clubLedgerPageProvider(_offset));

    return pageAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => AccountingPanelMessage(
        icon: Icons.error_outline_rounded,
        title: classifyOperationError(error).userMessage,
        onRetry: () => ref.invalidate(clubLedgerPageProvider(_offset)),
      ),
      data: (page) {
        final visibleEntries = _directionFilter == null
            ? page.entries
            : page.entries
                .where((entry) => entry.direction == _directionFilter)
                .toList(growable: false);
        final hasPrev = _offset > 0;
        final hasNext = _offset + _pageSize < page.totalCount;

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(clubLedgerPageProvider(_offset));
            await ref.read(clubLedgerPageProvider(_offset).future);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AccountantClubSelector(
                clubs: widget.clubs,
                selectedClub: widget.selectedClub,
                theme: host.theme,
              ),
              if (widget.header != null) ...[
                const SizedBox(height: 12),
                widget.header!,
              ],
              const SizedBox(height: 8),
              Text(
                'Sunucu maskeli defter görünümü (acc_ledger): sporcu adı okunmaz, aidat karşı tarafı yalnız sabit referans koduyla (ör. maskeli hash) gösterilir.',
                style: TextStyle(color: host.theme.inkMuted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterChipButton(
                    label: 'Tümü',
                    selected: _directionFilter == null,
                    onTap: () => setState(() => _directionFilter = null),
                  ),
                  _FilterChipButton(
                    label: 'Gelir',
                    selected: _directionFilter == 'in',
                    onTap: () => setState(() => _directionFilter = 'in'),
                  ),
                  _FilterChipButton(
                    label: 'Gider',
                    selected: _directionFilter == 'out',
                    onTap: () => setState(() => _directionFilter = 'out'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (visibleEntries.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: host.theme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: host.theme.line),
                  ),
                  child: Text(
                    'Seçili kapsamda defter hareketi bulunamadı.',
                    style: TextStyle(color: host.theme.inkMuted),
                  ),
                )
              else
                for (final entry in visibleEntries) ...[
                  Container(
                    key: ValueKey<String>('ledger-entry-${entry.id}'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: host.theme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: host.theme.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          alignment: WrapAlignment.spaceBetween,
                          children: [
                            Text(
                              entry.label,
                              style: TextStyle(
                                color: host.theme.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${entry.isIncome ? '+' : '-'}${money(entry.amount)}',
                              style: TextStyle(
                                color: entry.isIncome
                                    ? host.theme.success
                                    : host.theme.danger,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Karşı Taraf / Referans: ${entry.counterpart} · Kategori: ${entry.category}',
                          style: TextStyle(
                            color: host.theme.inkMuted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Hesap: ${entry.account} · Tarih: ${accountingTurkeyDate(entry.movedOn)}',
                          style: TextStyle(
                            color: host.theme.inkMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${page.totalCount} kayıt',
                    style: TextStyle(color: host.theme.inkMuted, fontSize: 12),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (hasPrev)
                        SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            key: const Key('ledger-prev-page-button'),
                            onPressed: () => setState(
                              () => _offset = (_offset - _pageSize).clamp(
                                0,
                                page.totalCount,
                              ),
                            ),
                            icon: const Icon(Icons.chevron_left_rounded),
                            label: const Text('Önceki'),
                          ),
                        ),
                      if (hasNext)
                        SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            key: const Key('ledger-next-page-button'),
                            onPressed: () =>
                                setState(() => _offset += _pageSize),
                            icon: const Icon(Icons.chevron_right_rounded),
                            label: const Text('Sonraki'),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

final class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ProFeatureHostScope.of(context).theme;
    return SizedBox(
      height: 48,
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: theme.accent.withValues(alpha: 0.2),
        labelStyle: TextStyle(
          color: selected ? theme.accent : theme.ink,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}
