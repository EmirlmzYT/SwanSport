import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../club/club_operation_card.dart';
import '../host/pro_feature_host.dart';

final class SharedPlatformOperationsPanel extends ConsumerWidget {
  const SharedPlatformOperationsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ProFeatureHostScope.of(context);
    if (!ref.watch(swanAccessProvider).isPlatformAdmin) {
      return const _PlatformMessage(
        title: 'Platform yöneticisi yetkisi gerekli',
      );
    }
    final config = ref.watch(platformConfigProvider);
    final plans = ref.watch(platformPlansProvider);
    final audit = ref.watch(platformAuditLogsProvider);
    final waitlist = ref.watch(launchWaitlistSummaryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Platform Operasyonları',
          style: TextStyle(
            color: host.theme.ink,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Sırlar, API anahtarları ve Firebase yapılandırması bu çalışma alanında gösterilmez.',
          style: TextStyle(color: host.theme.inkMuted),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 720
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            final cards = [
              ClubOperationCard(
                icon: Icons.monitor_heart_outlined,
                title: 'Platform Durumu',
                detail: config.when(
                  loading: () => 'Yükleniyor…',
                  error: (error, _) =>
                      classifyOperationError(error).userMessage,
                  data: (value) => value.maintenanceEnabled
                      ? 'Bakım bildirimi açık'
                      : 'Bakım bildirimi kapalı',
                ),
                onTap: host.navigator.openPlatformStatus,
                theme: host.theme,
              ),
              ClubOperationCard(
                icon: Icons.history_outlined,
                title: 'Denetim Kayıtları',
                detail: _count(audit, 'kayıt'),
                onTap: host.navigator.openPlatformAudit,
                theme: host.theme,
              ),
              ClubOperationCard(
                icon: Icons.sell_outlined,
                title: 'Planlar',
                detail: _count(plans, 'plan'),
                onTap: host.navigator.openPlatformPlans,
                theme: host.theme,
              ),
              ClubOperationCard(
                icon: Icons.mark_email_read_outlined,
                title: 'Lansman Bekleme Listesi',
                detail: waitlist.when(
                  loading: () => 'Yükleniyor…',
                  error: (error, _) =>
                      classifyOperationError(error).userMessage,
                  data: (value) => '${value.totalCount} kayıt',
                ),
                onTap: host.navigator.openLaunchWaitlist,
                theme: host.theme,
              ),
            ];
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final card in cards) SizedBox(width: width, child: card),
              ],
            );
          },
        ),
      ],
    );
  }
}

final class SharedPlatformStatusScreen extends ConsumerWidget {
  const SharedPlatformStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ProFeatureHostScope.of(context);
    return host.chrome.buildPage(
      context,
      title: 'Platform Durumu',
      body: _adminBody(
        ref,
        ref.watch(platformConfigProvider).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _PlatformMessage(
                title: classifyOperationError(error).userMessage,
                onRetry: () => ref.invalidate(platformConfigProvider),
              ),
              data: (config) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _StatusTile(
                    title: 'Bakım bildirimi',
                    value: config.maintenanceEnabled ? 'Açık' : 'Kapalı',
                  ),
                  _StatusTile(
                    title: 'Yayın duyurusu',
                    value: config.broadcastEnabled ? 'Açık' : 'Kapalı',
                  ),
                  _StatusTile(title: 'Lansman', value: config.launchStatus),
                  _StatusTile(
                    title: 'Yeni kayıtlar',
                    value: config.disableSignups ? 'Kapalı' : 'Açık',
                  ),
                  _StatusTile(
                    title: 'Ödemeler',
                    value: config.disablePayments ? 'Kapalı' : 'Açık',
                  ),
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Bakım ve yayın ayarları istemci görünümüdür; sunucu tarafında uygulanmış küresel kill-switch kanıtı değildir.',
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => host.navigator.openPlatformWebConsole(
                      PlatformWebConsoleSection.missionControl,
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Masaüstü Mission Control'),
                  ),
                ],
              ),
            ),
      ),
    );
  }
}

final class SharedPlatformAuditScreen extends ConsumerWidget {
  const SharedPlatformAuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ProFeatureHostScope.of(context);
    return host.chrome.buildPage(
      context,
      title: 'Platform Denetim Kayıtları',
      body: _adminBody(
        ref,
        ref.watch(platformAuditLogsProvider).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _PlatformMessage(
                title: classifyOperationError(error).userMessage,
                onRetry: () => ref.invalidate(platformAuditLogsProvider),
              ),
              data: (rows) => ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: rows.length + 1,
                itemBuilder: (context, index) {
                  if (index == rows.length) {
                    return OutlinedButton.icon(
                      onPressed: () => host.navigator.openPlatformWebConsole(
                        PlatformWebConsoleSection.audit,
                      ),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Tüm kayıtları masaüstünde aç'),
                    );
                  }
                  final row = rows[index];
                  return Card(
                    child: ListTile(
                      title: Text(row.action),
                      subtitle: Text(
                        '${row.entityType}${row.entityId == null ? '' : ' · ${row.entityId}'}\n${_dateTime(row.createdAt)}',
                      ),
                    ),
                  );
                },
              ),
            ),
      ),
    );
  }
}

final class SharedPlatformPlansScreen extends ConsumerStatefulWidget {
  const SharedPlatformPlansScreen({super.key});

  @override
  ConsumerState<SharedPlatformPlansScreen> createState() =>
      _SharedPlatformPlansScreenState();
}

final class _SharedPlatformPlansScreenState
    extends ConsumerState<SharedPlatformPlansScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final host = ProFeatureHostScope.of(context);
    return host.chrome.buildPage(
      context,
      title: 'Platform Planları',
      actions: [
        IconButton(
          key: const Key('platform-plan-add'),
          onPressed: _busy || !ref.watch(swanAccessProvider).isPlatformAdmin
              ? null
              : () => _editPlan(),
          icon: const Icon(Icons.add),
          tooltip: 'Plan ekle',
        ),
      ],
      body: _adminBody(
        ref,
        ref.watch(platformPlansProvider).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _PlatformMessage(
                title: classifyOperationError(error).userMessage,
                onRetry: () => ref.invalidate(platformPlansProvider),
              ),
              data: (plans) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final plan in plans)
                    Card(
                      child: ListTile(
                        title: Text(plan.name),
                        subtitle: Text(
                          '${plan.target} · ${plan.code}\nAylık ${plan.priceMonthly.toStringAsFixed(2)} ₺ · Yıllık ${plan.priceYearly.toStringAsFixed(2)} ₺',
                        ),
                        trailing: IconButton(
                          onPressed: _busy ? null : () => _editPlan(plan),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => host.navigator.openPlatformWebConsole(
                      PlatformWebConsoleSection.plans,
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Yoğun plan yönetimini masaüstünde aç'),
                  ),
                ],
              ),
            ),
      ),
    );
  }

  Future<void> _editPlan([PlatformPlan? current]) async {
    final result = await showDialog<PlatformPlan>(
      context: context,
      builder: (_) => _PlanDialog(current: current),
    );
    if (result == null || !mounted) return;
    final actor = ref.read(authSessionProvider).valueOrNull?.user.id;
    if (actor == null || !ref.read(swanAccessProvider).isPlatformAdmin) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(platformMissionControlServiceProvider)
          .upsertPlatformPlan(result);
      if (!mounted ||
          ref.read(authSessionProvider).valueOrNull?.user.id != actor) {
        return;
      }
      ref.invalidate(platformPlansProvider);
      ProFeatureHostScope.of(context).chrome.showMessage(
            context,
            'Plan kaydedildi.',
            tone: ProFeatureMessageTone.success,
          );
    } catch (error) {
      if (mounted) {
        ProFeatureHostScope.of(context).chrome.showMessage(
              context,
              classifyOperationError(error).userMessage,
              tone: ProFeatureMessageTone.danger,
            );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

final class SharedLaunchWaitlistScreen extends ConsumerStatefulWidget {
  const SharedLaunchWaitlistScreen({super.key});

  @override
  ConsumerState<SharedLaunchWaitlistScreen> createState() =>
      _SharedLaunchWaitlistScreenState();
}

final class _SharedLaunchWaitlistScreenState
    extends ConsumerState<SharedLaunchWaitlistScreen> {
  final Set<String> _selected = {};
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final host = ProFeatureHostScope.of(context);
    final entries = ref.watch(launchWaitlistEntriesProvider);
    final summary = ref.watch(launchWaitlistSummaryProvider);
    return host.chrome.buildPage(
      context,
      title: 'Lansman Bekleme Listesi',
      actions: [
        IconButton(
          onPressed: () => host.navigator.openPlatformWebConsole(
            PlatformWebConsoleSection.waitlist,
          ),
          icon: const Icon(Icons.open_in_new),
          tooltip: 'Masaüstünde aç',
        ),
      ],
      bottomBar: _selected.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  key: const Key('waitlist-mark-notified'),
                  onPressed: _busy ? null : _markNotified,
                  icon: const Icon(Icons.mark_email_read_outlined),
                  label: Text('${_selected.length} kaydı bildirildi işaretle'),
                ),
              ),
            ),
      body: _adminBody(
        ref,
        entries.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _PlatformMessage(
            title: classifyOperationError(error).userMessage,
            onRetry: () => ref.invalidate(launchWaitlistEntriesProvider),
          ),
          data: (rows) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              summary.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
                data: (value) => Card(
                  child: ListTile(
                    title: Text('${value.totalCount} toplam kayıt'),
                    subtitle: Text(
                      'Sporcu ${value.athleteCount} · Antrenör ${value.coachCount} · Kulüp ${value.clubCount}',
                    ),
                  ),
                ),
              ),
              for (final row in rows)
                CheckboxListTile(
                  value: _selected.contains(row.email),
                  onChanged: row.isNotified || _busy
                      ? null
                      : (value) => setState(() {
                            value == true
                                ? _selected.add(row.email)
                                : _selected.remove(row.email);
                          }),
                  title: Text(row.email),
                  subtitle: Text(
                    '${row.role}${row.sportCode == null ? '' : ' · ${row.sportCode}'}${row.isNotified ? ' · Bildirildi' : ''}',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _markNotified() async {
    final actor = ref.read(authSessionProvider).valueOrNull?.user.id;
    if (actor == null || !ref.read(swanAccessProvider).isPlatformAdmin) return;
    final host = ProFeatureHostScope.of(context);
    final confirmed = await host.chrome.confirm(
      context,
      title: 'Bildirim durumunu güncelle',
      message:
          '${_selected.length} kayıt bildirildi olarak işaretlenecek. Bu işlem e-posta göndermez.',
      confirmLabel: 'İşaretle',
    );
    if (!confirmed || !mounted) return;
    final emails = _selected.toList(growable: false);
    setState(() => _busy = true);
    try {
      final count = await ref
          .read(platformMissionControlServiceProvider)
          .markWaitlistNotified(emails: emails);
      if (!mounted ||
          ref.read(authSessionProvider).valueOrNull?.user.id != actor ||
          !ref.read(swanAccessProvider).isPlatformAdmin) {
        return;
      }
      setState(_selected.clear);
      ref
        ..invalidate(launchWaitlistEntriesProvider)
        ..invalidate(launchWaitlistSummaryProvider)
        ..invalidate(platformAuditLogsProvider);
      host.chrome.showMessage(
        context,
        '$count kayıt güncellendi.',
        tone: ProFeatureMessageTone.success,
      );
    } catch (error) {
      if (mounted) {
        host.chrome.showMessage(
          context,
          classifyOperationError(error).userMessage,
          tone: ProFeatureMessageTone.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

final class _PlanDialog extends StatefulWidget {
  const _PlanDialog({this.current});

  final PlatformPlan? current;

  @override
  State<_PlanDialog> createState() => _PlanDialogState();
}

final class _PlanDialogState extends State<_PlanDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _monthly;
  late final TextEditingController _yearly;
  late String _target;

  @override
  void initState() {
    super.initState();
    final plan = widget.current;
    _code = TextEditingController(text: plan?.code ?? '');
    _name = TextEditingController(text: plan?.name ?? '');
    _monthly =
        TextEditingController(text: plan?.priceMonthly.toString() ?? '0');
    _yearly = TextEditingController(text: plan?.priceYearly.toString() ?? '0');
    _target = plan?.target ?? 'club';
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _monthly.dispose();
    _yearly.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.current == null ? 'Plan Ekle' : 'Planı Düzenle'),
        content: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _target,
                  items: const [
                    DropdownMenuItem(value: 'club', child: Text('Kulüp')),
                    DropdownMenuItem(value: 'athlete', child: Text('Sporcu')),
                  ],
                  onChanged: (value) => _target = value ?? _target,
                ),
                TextFormField(
                  controller: _code,
                  decoration: const InputDecoration(labelText: 'Kod'),
                  validator: _required,
                ),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Ad'),
                  validator: _required,
                ),
                TextFormField(
                  controller: _monthly,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Aylık fiyat'),
                  validator: _money,
                ),
                TextFormField(
                  controller: _yearly,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Yıllık fiyat'),
                  validator: _money,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () {
              if (!_form.currentState!.validate()) return;
              Navigator.pop(
                context,
                PlatformPlan(
                  id: widget.current?.id,
                  target: _target,
                  code: _code.text.trim(),
                  name: _name.text.trim(),
                  badge: widget.current?.badge,
                  priceMonthly: double.parse(_monthly.text),
                  priceYearly: double.parse(_yearly.text),
                  maxAthletes: widget.current?.maxAthletes,
                  features: widget.current?.features ?? const [],
                  isActive: widget.current?.isActive ?? true,
                  sortOrder: widget.current?.sortOrder ?? 0,
                ),
              );
            },
            child: const Text('Kaydet'),
          ),
        ],
      );

  String? _required(String? value) =>
      value?.trim().isNotEmpty == true ? null : 'Bu alan zorunlu';

  String? _money(String? value) {
    final amount = double.tryParse(value ?? '');
    return amount == null || !amount.isFinite || amount < 0
        ? 'Geçerli, negatif olmayan tutar girin'
        : null;
  }
}

Widget _adminBody(WidgetRef ref, Widget child) =>
    ref.watch(swanAccessProvider).isPlatformAdmin
        ? child
        : const _PlatformMessage(title: 'Platform yöneticisi yetkisi gerekli');

String _count<T>(AsyncValue<List<T>> value, String label) => value.when(
      loading: () => 'Yükleniyor…',
      error: (error, _) => classifyOperationError(error).userMessage,
      data: (rows) => '${rows.length} $label',
    );

String _dateTime(DateTime? date) {
  if (date == null) return '—';
  final local = date.toUtc().add(const Duration(hours: 3));
  return '${local.day.toString().padLeft(2, '0')}.'
      '${local.month.toString().padLeft(2, '0')}.${local.year} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

final class _StatusTile extends StatelessWidget {
  const _StatusTile({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(title: Text(title), trailing: Text(value)),
      );
}

final class _PlatformMessage extends StatelessWidget {
  const _PlatformMessage({required this.title, this.onRetry});

  final String title;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.admin_panel_settings_outlined, size: 40),
              const SizedBox(height: 8),
              Text(title, textAlign: TextAlign.center),
              if (onRetry != null)
                TextButton(
                  onPressed: onRetry,
                  child: const Text('Tekrar dene'),
                ),
            ],
          ),
        ),
      );
}
