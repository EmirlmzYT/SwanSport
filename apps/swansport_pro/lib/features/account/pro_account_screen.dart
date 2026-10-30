import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/pro_theme.dart';
import '../../app/push/pro_push_client.dart';
import '../../widgets/pro_ui_components.dart';
import '../../workspaces/pro_workspace_controller.dart';
import '../auth/pro_auth_controller.dart';

class ProAccountScreen extends ConsumerWidget {
  const ProAccountScreen({super.key});

  static final _swanSportWebUri = Uri.parse('https://swansport.pages.dev/');

  Future<void> _openSwanSport(BuildContext context) async {
    var opened = false;
    try {
      opened = await launchUrl(
        _swanSportWebUri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('SwanSport bağlantısı açılamadı. Lütfen tekrar deneyin.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider).valueOrNull;
    final email = session?.user.email ?? 'Giriş Yapıldı';
    final availableWorkspaces = ref.watch(availableProWorkspacesProvider);
    final selectedWorkspace = ref.watch(selectedProWorkspaceProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ProPageHeader(
                    title: 'Hesap & Yetkiler',
                    subtitle:
                        'Oturumunuzu, çalışma alanlarınızı ve bildirimlerinizi yönetin.',
                    leading: DecoratedBox(
                      decoration: BoxDecoration(
                        color: ProTheme.surfaceRaised,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(
                          Icons.manage_accounts_outlined,
                          color: ProTheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: ProTheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: ProTheme.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Giriş Yapılan Hesap',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: ProTheme.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: ProTheme.ink,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(color: ProTheme.line, height: 1),
                        const SizedBox(height: 12),
                        const Text(
                          'Yetkili Çalışma Alanları',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: ProTheme.muted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: availableWorkspaces.map((ws) {
                            final isSelected = ws == selectedWorkspace;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? ProTheme.primary.withValues(alpha: 0.14)
                                    : ProTheme.surfaceRaised,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? ProTheme.primary
                                      : ProTheme.line,
                                ),
                              ),
                              child: Text(
                                ws.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? ProTheme.primary
                                      : ProTheme.muted,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ProTheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: ProTheme.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.notifications_active_outlined,
                              size: 18,
                              color: ProTheme.primary,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Profesyonel Bildirim Tercihleri',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: ProTheme.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Saha ve operasyon bildirimlerinizi kategorilere göre yönetin.',
                          style: TextStyle(
                            fontSize: 12,
                            color: ProTheme.muted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(color: ProTheme.line, height: 1),
                        _buildPrefTile(
                          ref: ref,
                          category: 'kulup',
                          title: 'Kulüp & Yönetim',
                          subtitle:
                              'Görev delegasyonu, tesis ve yönetici bildirimleri',
                          prefsMap: {
                            for (final p in (ref
                                    .watch(notificationPrefsProvider)
                                    .valueOrNull ??
                                const <NotificationPref>[]))
                              p.category: p.enabled,
                          },
                        ),
                        _buildPrefTile(
                          ref: ref,
                          category: 'musabaka',
                          title: 'Müsabaka & Hakem',
                          subtitle:
                              'Hakem atamaları, esame listeleri ve maç sonuçları',
                          prefsMap: {
                            for (final p in (ref
                                    .watch(notificationPrefsProvider)
                                    .valueOrNull ??
                                const <NotificationPref>[]))
                              p.category: p.enabled,
                          },
                        ),
                        _buildPrefTile(
                          ref: ref,
                          category: 'aidat',
                          title: 'Finans & Muhasebe',
                          subtitle:
                              'Harcama onayları, mali taahhütler ve mutabakat',
                          prefsMap: {
                            for (final p in (ref
                                    .watch(notificationPrefsProvider)
                                    .valueOrNull ??
                                const <NotificationPref>[]))
                              p.category: p.enabled,
                          },
                        ),
                        _buildPrefTile(
                          ref: ref,
                          category: 'antrenman',
                          title: 'Antrenman & Yoklama',
                          subtitle:
                              'Antrenman oturumları ve canlı yoklama bildirimleri',
                          prefsMap: {
                            for (final p in (ref
                                    .watch(notificationPrefsProvider)
                                    .valueOrNull ??
                                const <NotificationPref>[]))
                              p.category: p.enabled,
                          },
                        ),
                        const SizedBox(height: 12),
                        const Divider(color: ProTheme.line, height: 1),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final status = const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cihaz Bildirim Durumu',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: ProTheme.ink,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Bu cihazda push bildirimleri aktiftir.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: ProTheme.muted,
                                  ),
                                ),
                              ],
                            );
                            final action = OutlinedButton(
                              onPressed: () async {
                                final client = ref.read(proPushClientProvider);
                                await client.requestPermission();
                                await client.registerWithServer();
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: ProTheme.primary,
                                side: const BorderSide(color: ProTheme.primary),
                                minimumSize: const Size(48, 48),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                              child: const Text(
                                'İzin Doğrula',
                                style: TextStyle(fontSize: 12),
                              ),
                            );
                            if (constraints.maxWidth < 480) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  status,
                                  const SizedBox(height: 12),
                                  action,
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: status),
                                const SizedBox(width: 12),
                                action,
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () => _openSwanSport(context),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text("SwanSport'u Aç"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ProTheme.primary,
                      side: const BorderSide(color: ProTheme.primary),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () {
                      ref.read(proAuthControllerProvider.notifier).signOut();
                    },
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Çıkış Yap'),
                    style: FilledButton.styleFrom(
                      backgroundColor: ProTheme.surfaceRaised,
                      foregroundColor: ProTheme.ink,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrefTile({
    required WidgetRef ref,
    required String category,
    required String title,
    required String subtitle,
    required Map<String, bool> prefsMap,
  }) {
    final enabled = prefsMap[category] ?? true;
    return Material(
      type: MaterialType.transparency,
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: ProTheme.ink,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11,
            color: ProTheme.muted,
          ),
        ),
        value: enabled,
        activeTrackColor: ProTheme.primary,
        onChanged: (bool value) async {
          if (ref.read(isSupabaseEnabledProvider)) {
            try {
              await ref
                  .read(notificationServiceProvider)
                  .setPref(category, value);
              ref.invalidate(notificationPrefsProvider);
            } catch (e) {
              debugPrint('Set pref failed: $e');
            }
          }
        },
      ),
    );
  }
}
