import 'package:flutter/material.dart';
import '../../app/pro_environment.dart';

class ProStartupFailureScreen extends StatelessWidget {
  const ProStartupFailureScreen({
    super.key,
    required this.environment,
    required this.error,
    this.onRetry,
  });

  final ProEnvironment environment;
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 64,
                    color: Color(0xFFEF4444),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Bağlantı Kurulamadı',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    environment.isProduction
                        ? 'SwanSport Pro sunucusuna güvenli bağlantı kurulamadı. Lütfen internet bağlantınızı kontrol edip tekrar deneyin.'
                        : 'Geliştirme ortamında Supabase yapılandırması eksik veya başlatılamadı:\n$error',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF94A3B8),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  if (onRetry != null)
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Tekrar Dene'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0EA5E9),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
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
}
