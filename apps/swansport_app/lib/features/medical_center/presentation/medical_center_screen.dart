import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/medical_controller.dart';
import '../domain/medical_center.dart';
import 'medical_route_args.dart';

class MedicalCenterScreen extends ConsumerWidget {
  const MedicalCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(medicalControllerProvider);
    final c = ref.read(medicalControllerProvider.notifier);
    final metrics = state.metrics;

    if (state.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sağlık Merkezi & Sporcu Sağlığı'),
        actions: [
          DropdownButton<MedicalRole>(
            key: const Key('medical-role-switcher'),
            value: state.currentRole,
            onChanged: (role) {
              if (role != null) c.changeRole(role);
            },
            items: MedicalRole.values
                .map(
                  (r) => DropdownMenuItem(
                    value: r,
                    child: Text(r.name),
                  ),
                )
                .toList(),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, box) {
          final overview = Column(
            children: [
              Container(
                key: const Key('medical-command-center'),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MEDICAL COMMAND CENTER',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${metrics.totalAthletes} Sporcu • Uyum Skoru: %${metrics.complianceScore}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${metrics.healthyAthletes} Sağlıklı • ${metrics.injuredAthletes} Sakat • ${metrics.rehabCases} Rehabilitasyon • ${metrics.expiringCertificates} Süresi Dolan Rapor',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ExpansionTile(
                  key: const Key('medical-alerts-tile'),
                  title: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tıbbi Uyarı Merkezi (${state.alerts.length})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  children: [
                    if (state.alerts.isEmpty)
                      const ListTile(title: Text('Aktif tıbbi uyarı yok.'))
                    else
                      for (final a in state.alerts)
                        ListTile(
                          key: Key('alert-${a.id.value}'),
                          leading: Icon(
                            a.severity == AlertSeverity.critical
                                ? Icons.gpp_maybe
                                : Icons.info,
                            color: a.severity == AlertSeverity.critical
                                ? Colors.red
                                : Colors.amber,
                          ),
                          title: Text(a.title),
                          subtitle: Text('${a.athleteName} • ${a.message}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.check),
                            onPressed: () => c.dismissAlert(a.id),
                          ),
                        ),
                  ],
                ),
              ),
              Card(
                child: ExpansionTile(
                  key: const Key('medical-appointments'),
                  title: Text(
                    'Tıbbi Randevular (${state.appointments.length})',
                  ),
                  children: state.appointments
                      .map(
                        (appointment) => ListTile(
                          leading: const Icon(Icons.event_available),
                          title: Text(appointment.type),
                          subtitle: Text(
                            '${appointment.professional} • ${appointment.location}\n'
                            '${appointment.start} • ${appointment.status.name}',
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              Card(
                child: ExpansionTile(
                  key: const Key('medical-clearances'),
                  title: Text(
                    'Tıbbi Onaylar (${state.clearances.length})',
                  ),
                  children: state.clearances
                      .map(
                        (clearance) => ListTile(
                          leading: const Icon(Icons.verified_user),
                          title: Text(clearance.type),
                          subtitle: Text(
                            '${clearance.issuer} • ${clearance.status.name}\n'
                            'Geçerlilik: ${clearance.expiresAt}',
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              if (state.permissions.canViewDoctorNotes)
                Card(
                  child: ExpansionTile(
                    key: const Key('medical-audit'),
                    title: Text('Tıbbi Denetim Kaydı (${state.audit.length})'),
                    children: state.audit.isEmpty
                        ? const [
                            ListTile(title: Text('Henüz denetim kaydı yok.')),
                          ]
                        : state.audit
                            .map(
                              (entry) => ListTile(
                                leading: const Icon(Icons.history),
                                title: Text(entry.action),
                                subtitle: Text(
                                  '${entry.actor} (${entry.role}) • '
                                  '${entry.previousValue} → ${entry.newValue}\n'
                                  '${entry.timestamp} • ${entry.confidentiality}',
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ),
            ],
          );

          final directory = Column(
            children: [
              TextField(
                key: const Key('medical-search'),
                onChanged: c.search,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Sporcu, branş, takım veya sakatlık türü ara...',
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Tümü'),
                      selected: state.filter.eligibility == null,
                      onSelected: (_) => c.filterEligibility(null),
                    ),
                    ...MedicalEligibilityStatus.values.map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: ChoiceChip(
                          label: Text(_statusLabel(s)),
                          selected: state.filter.eligibility == s,
                          onSelected: (_) => c.filterEligibility(s),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (state.filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Eşleşen tıbbi profil bulunamadı.',
                    key: Key('medical-empty'),
                  ),
                ),
              for (final p in state.filtered)
                Card(
                  child: ListTile(
                    key: Key('medical-${p.id.value}'),
                    leading: _statusIcon(p.eligibility),
                    title: Text(p.athleteName),
                    subtitle: Text(
                      '${p.branch} • ${p.team}\nKan: ${p.bloodType} • Uygunluk: ${_statusLabel(p.eligibility)}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/medical-detail',
                      arguments: MedicalDetailArgs(p.id),
                    ),
                  ),
                ),
            ],
          );

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'SAĞLIK YÖNETİM MERKEZİ',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                ),
              ),
              const Text(
                'Sporcu Sağlığı & Tıbbi Uygunluk',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              if (box.maxWidth >= 840)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: overview),
                    const SizedBox(width: 24),
                    Expanded(flex: 7, child: directory),
                  ],
                )
              else ...[
                overview,
                const SizedBox(height: 16),
                directory,
              ],
            ],
          );
        },
      ),
    );
  }

  String _statusLabel(MedicalEligibilityStatus s) {
    switch (s) {
      case MedicalEligibilityStatus.eligible:
        return 'Uygun';
      case MedicalEligibilityStatus.temporarilyRestricted:
        return 'Geçici Kısıtlı';
      case MedicalEligibilityStatus.rehabilitation:
        return 'Rehabilitasyon';
      case MedicalEligibilityStatus.suspended:
        return 'Tıbbi Askı';
      case MedicalEligibilityStatus.clearanceRequired:
        return 'Onay Gerekli';
    }
  }

  Widget _statusIcon(MedicalEligibilityStatus s) {
    switch (s) {
      case MedicalEligibilityStatus.eligible:
        return const Icon(Icons.check_circle, color: Colors.green);
      case MedicalEligibilityStatus.temporarilyRestricted:
        return const Icon(Icons.warning, color: Colors.orange);
      case MedicalEligibilityStatus.rehabilitation:
        return const Icon(Icons.healing, color: Colors.blue);
      case MedicalEligibilityStatus.suspended:
        return const Icon(Icons.cancel, color: Colors.red);
      case MedicalEligibilityStatus.clearanceRequired:
        return const Icon(Icons.help, color: Colors.purple);
    }
  }
}

class MedicalDetailScreen extends ConsumerWidget {
  final MedicalDetailArgs? args;

  const MedicalDetailScreen({required this.args, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(medicalControllerProvider);
    final c = ref.read(medicalControllerProvider.notifier);

    if (args == null) {
      return const Scaffold(
        body: Center(child: Text('Geçersiz tıbbi profil bağlantısı.')),
      );
    }

    final found = state.profiles.where((p) => p.id == args!.athleteId);
    if (state.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (found.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Sağlık profili bulunamadı.')),
      );
    }

    final p = found.single;
    final perms = state.permissions;

    return Scaffold(
      appBar: AppBar(title: Text('${p.athleteName} - Sağlık Profili')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            p.athleteName,
            key: const Key('medical-detail-name'),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          Text('${p.branch} • ${p.team} • Kan Grubu: ${p.bloodType}'),
          Text(
            'Boy: ${p.heightCm} cm • Kilo: ${p.weightKg} kg • Baskın Taraf: ${p.dominantHand} el / ${p.dominantFoot} ayak',
          ),
          const SizedBox(height: 12),
          if (perms.canClearEligibility)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tıbbi Uygunluk Güncelleme (Doktor Yetkisi)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: MedicalEligibilityStatus.values
                          .map(
                            (status) => OutlinedButton(
                              onPressed: () =>
                                  c.updateEligibility(p.id, status),
                              child: Text(status.name),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          _section(
            'Acil Durum İletişim',
            p.emergencyContacts.map(
              (e) => ListTile(
                leading: const Icon(Icons.phone),
                title: Text('${e.name} (${e.relation})'),
                subtitle: Text(e.phone),
              ),
            ),
          ),
          _section(
            'Alerjiler & Kronik Durumlar',
            p.allergies.map(
              (a) => ListTile(
                leading: Icon(
                  Icons.warning,
                  color: a.isCritical ? Colors.red : Colors.amber,
                ),
                title: Text(a.title),
                subtitle: Text('${a.category} • Critical: ${a.isCritical}'),
              ),
            ),
          ),
          _section(
            'Aktif İlaçlar & Doping Kontrolü',
            p.medications.map(
              (m) => ListTile(
                leading: const Icon(Icons.medication),
                title: Text(m.name),
                subtitle: Text(
                  '${m.dosage} • ${m.duration}\nReçete Eden: ${m.physician} • Doping Uyumlu: ${m.isAntiDopingCompliant}',
                ),
              ),
            ),
          ),
          _section(
            'Sağlık Belgeleri & Raporlar',
            p.certificates.map(
              (cert) => ListTile(
                leading: const Icon(Icons.description),
                title: Text(cert.title),
                subtitle: Text(
                  '${cert.type} • Durum: ${cert.state.name}\nGeçerlilik: ${cert.expirationDate.toString().split(' ')[0]}',
                ),
              ),
            ),
          ),
          _section(
            'Sakatlık Geçmişi & Rehabilitasyon',
            p.injuries.map(
              (inj) => ListTile(
                leading: const Icon(Icons.local_hospital, color: Colors.red),
                title: Text('${inj.type} (${inj.bodyRegion})'),
                subtitle: Text(
                  'Şiddet: ${inj.severity.name} • Dr. ${inj.physician}\nTahmini İyileşme: ${inj.estimatedRecovery}',
                ),
              ),
            ),
          ),
          _section(
            'Randevular',
            state.appointments
                .where((appointment) => appointment.athleteId == p.id)
                .map(
                  (appointment) => ListTile(
                    title: Text(appointment.type),
                    subtitle: Text(
                      '${appointment.professional} • ${appointment.location}\n'
                      '${appointment.start} • ${appointment.status.name}',
                    ),
                  ),
                ),
          ),
          _section(
            'Tıbbi Onay & Return-to-Play',
            state.clearances
                .where((clearance) => clearance.athleteId == p.id)
                .map(
                  (clearance) => ListTile(
                    title: Text(clearance.type),
                    subtitle: Text(
                      '${clearance.status.name} • ${clearance.issuer}\n'
                      'Son geçerlilik: ${clearance.expiresAt}',
                    ),
                  ),
                ),
          ),
          if (perms.canViewDoctorNotes && p.confidentialDoctorNotes != null)
            Card(
              color: Colors.blue.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lock, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Gizli Klinik Doktor Notları',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      p.confidentialDoctorNotes!,
                      key: const Key('confidential-doctor-notes'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _section(String title, Iterable<Widget> children) {
    return Card(
      child: ExpansionTile(
        title: Text(title),
        children: children.isEmpty
            ? const [ListTile(title: Text('Kayıt bulunmuyor.'))]
            : children.toList(),
      ),
    );
  }
}
