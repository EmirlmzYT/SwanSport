import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../host/pro_feature_host.dart';

enum InboxFilter { all, unread }

/// Profesyonel gelen kutusu ekranı.
///
/// Sunucunun Pro'ya özel RPC'sinden yalnız kulüp, hakem, tesis, antrenman ve
/// operasyon bildirimlerini listeler.
final class SharedProInboxScreen extends ConsumerStatefulWidget {
  const SharedProInboxScreen({
    this.onNotificationTap,
    this.onMarkRead,
    super.key,
  });

  final void Function(NotificationRow notification)? onNotificationTap;
  final Future<void> Function(String? notificationId)? onMarkRead;

  @override
  ConsumerState<SharedProInboxScreen> createState() =>
      _SharedProInboxScreenState();
}

final class _SharedProInboxScreenState
    extends ConsumerState<SharedProInboxScreen> {
  InboxFilter _filter = InboxFilter.all;

  IconData _iconForKind(String kind) {
    return switch (kind.trim().toLowerCase()) {
      'referee_assignment' => Icons.sports,
      'expense_approval' ||
      'expense_rejected' ||
      'commitment_due' ||
      'account_negative' ||
      'bank_unmatched' ||
      'period_closed' ||
      'period_blocked' ||
      'fee' ||
      'fee_reminder' ||
      'payment' ||
      'donation' =>
        Icons.account_balance_wallet_outlined,
      'turf_slot_request' ||
      'turf_field' ||
      'turf_manager' ||
      'court_waitlist' ||
      'turf_delegation' =>
        Icons.stadium_outlined,
      'match_live' || 'match_result' => Icons.sports_soccer,
      'attendance' || 'attendance_reminder' => Icons.fact_check_outlined,
      'training_session' || 'training_result' => Icons.fitness_center_outlined,
      _ => Icons.notifications_outlined,
    };
  }

  String _formatTime(DateTime date) {
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _markAllRead() async {
    if (!ref.read(isSupabaseEnabledProvider)) return;
    try {
      await (widget.onMarkRead?.call(null) ??
          ref.read(notificationServiceProvider).markProRead());
      ref.invalidate(proNotificationsProvider);
    } catch (e) {
      debugPrint('Mark all read failed: $e');
    }
  }

  Future<void> _handleItemTap(NotificationRow item) async {
    if (item.isUnread && ref.read(isSupabaseEnabledProvider)) {
      try {
        await (widget.onMarkRead?.call(item.id) ??
            ref
                .read(notificationServiceProvider)
                .markProRead(notificationId: item.id));
        ref.invalidate(proNotificationsProvider);
      } catch (e) {
        debugPrint('Mark read failed: $e');
      }
    }
    widget.onNotificationTap?.call(item);
  }

  Widget _buildContent(List<NotificationRow> items) {
    final filtered = _filter == InboxFilter.unread
        ? items.where((n) => n.isUnread).toList()
        : items;

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              ChoiceChip(
                label: Text('Tümü (${items.length})'),
                selected: _filter == InboxFilter.all,
                onSelected: (_) => setState(() => _filter = InboxFilter.all),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(
                  'Okunmamış (${items.where((n) => n.isUnread).length})',
                ),
                selected: _filter == InboxFilter.unread,
                onSelected: (_) => setState(() => _filter = InboxFilter.unread),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.inbox_outlined,
                          size: 48,
                          color: Colors.white38,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _filter == InboxFilter.unread
                              ? 'Okunmamış bildiriminiz bulunmuyor.'
                              : 'Gelen kutunuzda bildirim bulunmuyor.',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Profesyonel görev, nöbet ve operasyon bildirimleriniz burada listelenir.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white38,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(proNotificationsProvider);
                    await ref.read(proNotificationsProvider.future);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return Card(
                        color: item.isUnread
                            ? const Color(0xFF1E293B)
                            : const Color(0xFF151E2E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: item.isUnread
                                ? const Color(0xFF0EA5E9).withValues(alpha: 0.4)
                                : const Color(0xFF334155),
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _handleItemTap(item),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: const Color(0xFF0F172A),
                                  child: Icon(
                                    _iconForKind(item.kind),
                                    size: 18,
                                    color: item.isUnread
                                        ? const Color(0xFF38BDF8)
                                        : Colors.white54,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.title,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: item.isUnread
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            _formatTime(item.createdAt),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.white38,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (item.body != null &&
                                          item.body!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          item.body!,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (item.isUnread) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF38BDF8),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final proAsync = ref.watch(proNotificationsProvider);
    final host = ProFeatureHostScope.maybeOf(context);

    final actions = [
      IconButton(
        icon: const Icon(Icons.done_all, size: 20),
        tooltip: 'Tümünü Okundu İşaretle',
        onPressed: _markAllRead,
      ),
    ];

    final body = proAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 40,
                color: Color(0xFFEF4444),
              ),
              const SizedBox(height: 12),
              const Text(
                'Bildirimler yüklenirken bir sorun oluştu.',
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.refresh(notificationsProvider),
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      ),
      data: _buildContent,
    );

    if (host != null) {
      return host.chrome.buildPage(
        context,
        title: 'Gelen Kutusu',
        actions: actions,
        body: body,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      appBar: AppBar(
        title: const Text('Gelen Kutusu'),
        backgroundColor: const Color(0xFF1C2541),
        foregroundColor: Colors.white,
        actions: actions,
      ),
      body: body,
    );
  }
}
