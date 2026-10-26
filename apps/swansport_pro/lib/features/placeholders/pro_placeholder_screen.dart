import 'package:flutter/material.dart';

class ProPlaceholderScreen extends StatelessWidget {
  const ProPlaceholderScreen({
    super.key,
    required this.title,
    this.description,
  });

  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final defaultDesc = switch (title) {
      'Görevler' =>
        'Onay, yoklama, lisans ve operasyonel görevler ortak paket Faz 2 kapsamında eklenecektir.',
      'Takvim' =>
        'Antrenman, resmi maç, tesis ve görev takvimi operasyonel planlama fazında eklenecektir.',
      'Gelen Kutusu' =>
        'Sosyal bildirimlerden izole edilmiş profesyonel operasyon bildirimleri Faz 5 kapsamında sunulacaktır.',
      _ => 'Bu modül Faz 2–5 planı uyarınca sonraki sürümlerde aktifleşecektir.',
    };

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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF38BDF8)),
                    ),
                    child: const Text(
                      'Yakında',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    description ?? defaultDesc,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF94A3B8),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
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
