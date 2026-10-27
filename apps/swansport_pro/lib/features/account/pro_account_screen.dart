import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/push/pro_push_client.dart';
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
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hesap & Yetkiler',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Giriş Yapılan Hesap',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFF334155), height: 1),
                    const SizedBox(height: 12),
                    const Text(
                      'Yetkili Çalışma Alanları',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF94A3B8),
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
                                ? const Color(0xFF0284C7).withValues(alpha: 0.3)
                                : const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF38BDF8)
                                  : const Color(0xFF334155),
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
                                  ? const Color(0xFF38BDF8)
                                  : const Color(0xFF94A3B8),
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
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.notifications_active_outlined,
                          size: 18,
                          color: Color(0xFF38BDF8),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Profesyonel Bildirim Tercihleri',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Saha ve operasyon bildirimlerinizi kategorilere göre yönetin.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFF334155), height: 1),
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
                    const Divider(color: Color(0xFF334155), height: 1),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cihaz Bildirim Durumu',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Bu cihazda push bildirimleri aktiftir.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () async {
                            final client = ref.read(proPushClientProvider);
                            await client.requestPermission();
                            await client.registerWithServer();
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF38BDF8),
                            side: const BorderSide(color: Color(0xFF0284C7)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          child: const Text(
                            'İzin Doğrula',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
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
                  foregroundColor: const Color(0xFF38BDF8),
                  side: const BorderSide(color: Color(0xFF0284C7)),
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
                  backgroundColor: const Color(0xFF334155),
                  foregroundColor: Colors.white,
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
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF94A3B8),
          ),
        ),
        value: enabled,
        activeColor: const Color(0xFF38BDF8),
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
