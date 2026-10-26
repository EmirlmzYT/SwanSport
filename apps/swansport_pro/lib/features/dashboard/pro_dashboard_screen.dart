import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../workspaces/pro_workspace.dart';
import '../../workspaces/pro_workspace_controller.dart';

class ProDashboardScreen extends ConsumerWidget {
  const ProDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedWorkspace = ref.watch(selectedProWorkspaceProvider);

    if (selectedWorkspace == null) {
      return const Scaffold(
        body: Center(
          child: Text('Çalışma alanı bulunamadı.'),
        ),
      );
    }

    final workspaceTitle = '${selectedWorkspace.label} Paneli';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                workspaceTitle,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Seçili çalışma alanı: ${selectedWorkspace.label}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF94A3B8),
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
                    Row(
                      children: [
                        const Icon(
                          Icons.verified_outlined,
                          size: 20,
                          color: Color(0xFF38BDF8),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Faz 1 Altyapısı Aktif',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${selectedWorkspace.label} için profesyonel kimlik doğrulandı ve yetkili oturum açıldı. '
                      'Operasyon modülleri (kadro, antrenman, atamalar, mali tablolar) '
                      'onaylı takvim uyarınca aşamalı olarak ortak paketten taşınacaktır.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFCBD5E1),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.security_outlined,
                          size: 20,
                          color: Color(0xFF10B981),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Doğrudan Veritabanı Yetkisi (RLS)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Text(
                      'SwanSport Pro arayüzü yalnızca SwanAccess yetki motorunun belirlediği '
                      'çalışma alanlarını gösterir. Tüm veri erişimleri ve işlemler doğrudan '
                      'sunucu taraflı RLS ve RPC kontrolleri ile korunur.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFFCBD5E1),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
