import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/modules/console_module.dart';
import '../../app/shell/too_narrow_notice.dart';
import '../../app/theme/console_theme.dart';
import '../../app/media/image_picker.dart';
import 'diagnostics_screen.dart';

final missionLogoPickerProvider = Provider<Future<PickedImageFile?> Function()>((_) => pickImageFile);

class MissionControlScreen extends ConsumerStatefulWidget {
  const MissionControlScreen({super.key});
  @override
  ConsumerState<MissionControlScreen> createState() => _MissionControlScreenState();
}
class _MissionControlScreenState extends ConsumerState<MissionControlScreen> {
  PlatformConfig? _lastConfig;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < ConsoleDensity.minSupportedWidth) return const TooNarrowNotice();
    if (!ref.watch(consoleAccessProvider).isPlatformAdmin) {
      return const Center(child: Text('Bu alan yalnız platform yöneticilerine açıktır.'));
    }
    final config = ref.watch(platformConfigProvider);
    _lastConfig = config.valueOrNull ?? _lastConfig;
    final value = _lastConfig;
    if (value == null) return Center(child: config.hasError
      ? Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Platform ayarları alınamadı. 0109 kurulumu ve erişimi kontrol et.'),
          TextButton(onPressed: () => ref.invalidate(platformConfigProvider), child: const Text('Tekrar dene')),
        ]) : const CircularProgressIndicator());
    return DefaultTabController(length: 5, child: Column(children: [
      Padding(padding: const EdgeInsets.all(ConsoleDensity.xl), child: Row(children: [
        Icon(Icons.admin_panel_settings_rounded, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: ConsoleDensity.md),
        Expanded(child: Text('Platform Mission Control', style: Theme.of(context).textTheme.headlineSmall)),
        IconButton(tooltip: 'Platform verilerini yenile', onPressed: () {
          ref.invalidate(platformConfigProvider); ref.invalidate(platformPlansProvider);
          ref.invalidate(platformAuditLogsProvider); ref.invalidate(diagnosticOverviewProvider);
        }, icon: const Icon(Icons.refresh_rounded)),
      ])),
      if (config.hasError) const Text('Yenileme başarısız; önceki ayarlar ve taslaklar korunuyor.'),
      const TabBar(isScrollable: true, tabs: [
        Tab(text: 'Marka & Görünüm'), Tab(text: 'Finans & Komisyonlar'),
        Tab(text: 'Paketler & Fiyatlandırma'), Tab(text: 'Şalterler'), Tab(text: 'Denetim & Sistem'),
      ]),
      Expanded(child: TabBarView(children: [
        _Page(children: [
          const _Note('Marka ve duyuru ayarları herkese açıktır. Sır, erişim anahtarı veya özel belge eklemeyin. Her kart ayrı kaydedilir.'),
          _SettingForm(key: const ValueKey('branding'), section: 'branding', title: 'Marka & İletişim', value: value.branding,
            fields: const [
              _Field('app_name', 'Uygulama Adı', needed: true), _Field('logo_url', 'Logo URL', kind: 'url'),
              _Field('tagline', 'Slogan'), _Field('support_email', 'İletişim E-posta', kind: 'email'),
              _Field('support_phone', 'İletişim Telefonu'),
            ]),
          _SettingForm(key: const ValueKey('broadcast'), section: 'broadcast_alert', title: 'Canlı Acil Duyuru', value: value.broadcastAlert,
            switches: const {'enabled': 'Duyuru bandını göster'}, severity: true,
            fields: const [_Field('title', 'Başlık'), _Field('message', 'Mesaj', kind: 'message')]),
        ]),
        _Page(children: [
          const _Note('Komisyonlar yapılandırma değeridir; henüz tahsilat veya ödeme işlemlerinde uygulanmaz.'),
          _SettingForm(section: 'commissions', title: 'Komisyonları Güncelle', value: value.commissions,
            fields: const [
              _Field('marketplace_rate', 'Pazaryeri Satış Komisyonu (%)', kind: 'rate'),
              _Field('court_rate', 'Tesis/Kort Komisyonu (%)', kind: 'rate'),
              _Field('dues_fee_fixed', 'Aidat Sabit Ücreti (₺)', kind: 'money'),
              _Field('dues_fee_rate', 'Aidat İşlem Oranı (%)', kind: 'rate'),
            ]),
        ]),
        const _PlansPage(),
        _Page(children: [
          const _Note('Bakım görünümü yalnız mobil Ana Akışı kapatır. Kayıt/ödeme şalterleri henüz sunucu işlemlerini durdurmaz; güvenlik kapısı değildir.', alarm: true),
          _SettingForm(section: 'maintenance', title: 'Bakım Modu', value: value.maintenance,
            switches: const {'enabled': 'Mobil Ana Akışı bakım görünümüne al'},
            fields: const [_Field('message', 'Bakım Mesajı', kind: 'message', needed: true)]),
          _SettingForm(section: 'kill_switches', title: 'Şalter Yapılandırması', value: value.killSwitches,
            switches: const {'disable_signups': 'Yeni Kayıtları Dondur (yapılandırma)',
              'disable_payments': 'Ödemeleri Dondur (yapılandırma)',
              'disable_marketplace': 'Pazaryerini Dondur (yapılandırma)'}, fields: const []),
          OutlinedButton.icon(onPressed: () => context.go('/bayraklar'), icon: const Icon(Icons.flag_outlined), label: const Text('Özellik Bayraklarını Aç')),
        ]),
        const _AuditPage(),
      ])),
    ]));
  }
}

class _Field {
  const _Field(this.key, this.label, {this.kind = 'text', this.needed = false});
  final String key, label, kind;
  final bool needed;
}
class _Page extends StatefulWidget {
  const _Page({required this.children});
  final List<Widget> children;
  @override
  State<_Page> createState() => _PageState();
}
class _PageState extends State<_Page> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(padding: const EdgeInsets.all(ConsoleDensity.xl),
      children: [for (final child in widget.children) Padding(padding: const EdgeInsets.only(bottom: ConsoleDensity.lg), child: child)]);
  }
}
class _Note extends StatelessWidget {
  const _Note(this.text, {this.alarm = false});
  final String text;
  final bool alarm;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(ConsoleDensity.lg),
    decoration: BoxDecoration(color: (alarm ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary).withValues(alpha: .1),
      borderRadius: BorderRadius.circular(ConsoleDensity.radius)),
    child: Text(text, style: Theme.of(context).textTheme.bodyMedium));
}

class _SettingForm extends ConsumerStatefulWidget {
  const _SettingForm({super.key, required this.section, required this.title,
    required this.value, required this.fields, this.switches = const {}, this.severity = false});
  final String section, title;
  final Map<String, dynamic> value;
  final List<_Field> fields;
  final Map<String, String> switches;
  final bool severity;
  @override
  ConsumerState<_SettingForm> createState() => _SettingFormState();
}
class _SettingFormState extends ConsumerState<_SettingForm> with AutomaticKeepAliveClientMixin {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers = {
    for (final field in widget.fields) field.key: TextEditingController(text: '${widget.value[field.key] ?? ''}'),
  };
  late final Map<String, bool> _switches = {for (final key in widget.switches.keys) key: widget.value[key] == true};
  late String _severity = ['info', 'warning', 'danger'].contains(widget.value['severity']) ? widget.value['severity'] as String : 'info';
  bool _busy = false;
  bool _logoBusy = false;
  String? _status;
  Future<void> _uploadLogo() async {
    if (_busy || _logoBusy || !ref.read(consoleAccessProvider).isPlatformAdmin) return;
    setState(() { _logoBusy = true; _status = null; });
    try {
      final file = await ref.read(missionLogoPickerProvider)();
      if (file == null || !mounted) return;
      if (!ref.read(consoleAccessProvider).isPlatformAdmin) return;
      final url = await ref.read(platformMissionControlServiceProvider)
        .uploadBrandLogo(bytes: file.bytes, name: file.name, mimeType: file.mimeType);
      if (!mounted) return;
      _controllers['logo_url']!.text = url;
      setState(() => _status = 'Logo yüklendi. Yayımlamak için Kaydet’e bas.');
    } catch (_) {
      if (mounted) setState(() => _status = 'Logo yüklenemedi. PNG/JPG/WebP/SVG ve en fazla 5 MB seçin; erişiminizi kontrol edin.');
    } finally { if (mounted) setState(() => _logoBusy = false); }
  }
  @override
  bool get wantKeepAlive => true;
  @override
  void dispose() { for (final controller in _controllers.values) { controller.dispose(); } super.dispose(); }
  String? _validate(_Field field, String? raw) {
    final value = (raw ?? '').trim();
    if (field.needed && value.isEmpty) return 'Bu alan gerekli';
    if (['rate', 'money'].contains(field.kind)) {
      final number = double.tryParse(value.replaceAll(',', '.'));
      if (number == null || !number.isFinite || number < 0 || (field.kind == 'rate' && number > 100)) return 'Geçerli ${field.kind == 'rate' ? '0–100 arası oran' : 'pozitif tutar'} gir';
    }
    if (field.kind == 'url' && value.isNotEmpty) {
      final uri = Uri.tryParse(value);
      if (uri == null || uri.scheme != 'https' || !uri.hasAuthority) return 'Geçerli HTTPS adresi gir';
    }
    if (field.kind == 'email' && value.isNotEmpty && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) return 'Geçerli e-posta gir';
    if (widget.section == 'broadcast_alert' && _switches['enabled'] == true && value.isEmpty) return 'Etkin duyuruda başlık ve mesaj gerekli';
    return null;
  }
  Future<void> _save() async {
    if (_busy || _logoBusy || !_form.currentState!.validate()) return;
    final logo = _controllers['logo_url'];
    if (logo != null && _validate(const _Field('logo_url', 'Logo URL', kind: 'url'), logo.text) != null) {
      setState(() => _status = 'Geçerli HTTPS logo adresi gir'); return;
    }
    if (!ref.read(consoleAccessProvider).isPlatformAdmin) return;
    final data = <String, dynamic>{...widget.value, ..._switches};
    for (final field in widget.fields) {
      final text = _controllers[field.key]!.text.trim();
      data[field.key] = ['rate', 'money'].contains(field.kind) ? double.parse(text.replaceAll(',', '.')) : field.kind == 'url' && text.isEmpty ? null : text;
    }
    if (widget.severity) data['severity'] = _severity;
    setState(() { _busy = true; _status = null; });
    try {
      await ref.read(platformMissionControlServiceProvider).updatePlatformSetting(widget.section, data);
      if (!mounted) return;
      ref.invalidate(platformConfigProvider); ref.invalidate(platformAuditLogsProvider);
      if (mounted) setState(() => _status = 'Kaydedildi');
    } catch (_) { if (mounted) setState(() => _status = 'Kaydedilemedi; taslak korundu. Tekrar deneyebilirsin.'); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Card(child: Padding(padding: const EdgeInsets.all(ConsoleDensity.xl), child: Form(key: _form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: ConsoleDensity.lg),
        for (final entry in widget.switches.entries) SwitchListTile(contentPadding: EdgeInsets.zero,
          title: Text(entry.value), value: _switches[entry.key]!, onChanged: _busy ? null : (v) => setState(() => _switches[entry.key] = v)),
        if (widget.severity) DropdownButtonFormField<String>(value: _severity,
          decoration: const InputDecoration(labelText: 'Uyarı Türü'),
          items: [for (final value in ['info', 'warning', 'danger']) DropdownMenuItem(value: value, child: Text(value))],
          onChanged: _busy ? null : (v) => setState(() => _severity = v!)),
        for (final field in widget.fields) Padding(padding: const EdgeInsets.only(top: ConsoleDensity.md),
          child: field.key == 'logo_url' ? _LogoField(controller: _controllers[field.key]!,
            enabled: !_busy && !_logoBusy, loading: _logoBusy, onUpload: _uploadLogo,
            validator: (value) => _validate(field, value)) : TextFormField(controller: _controllers[field.key], enabled: !_busy && !_logoBusy,
            minLines: field.kind == 'message' ? 2 : 1, maxLines: field.kind == 'message' ? 4 : 1,
            keyboardType: ['money', 'rate'].contains(field.kind) ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
            decoration: InputDecoration(labelText: field.label), validator: (value) => _validate(field, value))),
        const SizedBox(height: ConsoleDensity.lg),
        if (_status != null) Semantics(liveRegion: true, child: Text(_status!)),
        FilledButton.icon(onPressed: _busy || _logoBusy ? null : _save,
          icon: _busy ? const SizedBox(width: ConsoleDensity.lg, height: ConsoleDensity.lg, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
          label: Text(widget.section == 'commissions' ? 'Komisyonları Güncelle' : 'Kaydet')),
      ]))));
  }
}

class _LogoField extends StatelessWidget {
  const _LogoField({required this.controller, required this.enabled,
    required this.loading, required this.onUpload, required this.validator});
  final TextEditingController controller;
  final bool enabled, loading;
  final VoidCallback onUpload;
  final String? Function(String?) validator;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<TextEditingValue>(
    valueListenable: controller, builder: (context, value, _) {
      final url = value.text.trim();
      final uri = Uri.tryParse(url);
      final valid = uri != null && uri.scheme == 'https' && uri.hasAuthority;
      Widget placeholder() => Icon(Icons.image_outlined, color: Theme.of(context).colorScheme.outline);
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Marka Logosu'),
        const SizedBox(height: ConsoleDensity.sm),
        Wrap(spacing: ConsoleDensity.lg, runSpacing: ConsoleDensity.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Container(key: const ValueKey('brand-logo-preview'),
            width: ConsoleDensity.logoPreviewSize, height: ConsoleDensity.logoPreviewSize,
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(ConsoleDensity.radius)),
            clipBehavior: Clip.antiAlias,
            child: !valid ? placeholder() : uri.path.toLowerCase().endsWith('.svg')
              ? SvgPicture.network(url, fit: BoxFit.contain, semanticsLabel: 'Marka logosu',
                  placeholderBuilder: (_) => placeholder())
              : Image.network(url, fit: BoxFit.contain, semanticLabel: 'Marka logosu',
                  errorBuilder: (_, __, ___) => placeholder())),
          FilledButton.tonalIcon(onPressed: enabled ? onUpload : null,
            icon: loading ? const SizedBox(width: ConsoleDensity.lg, height: ConsoleDensity.lg,
              child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.upload_rounded),
            label: Text(loading ? 'Logo yükleniyor…' : 'Logo Yükle')),
          if (url.isNotEmpty) TextButton.icon(onPressed: enabled ? controller.clear : null,
            icon: const Icon(Icons.delete_outline), label: const Text('Logoyu Kaldır')),
        ]),
        Text('PNG, JPG, WebP veya SVG · En fazla 5 MB · Kaldırma Kaydet ile uygulanır.', style: Theme.of(context).textTheme.bodySmall),
        ExpansionTile(tilePadding: EdgeInsets.zero, title: const Text('Manuel Logo URL (opsiyonel)'),
          children: [TextFormField(key: const ValueKey('brand-logo-url'), controller: controller,
            enabled: enabled, decoration: const InputDecoration(labelText: 'Logo URL'), validator: validator)]),
      ]);
    });
}

class _PlansPage extends ConsumerStatefulWidget {
  const _PlansPage();
  @override
  ConsumerState<_PlansPage> createState() => _PlansPageState();
}
class _PlansPageState extends ConsumerState<_PlansPage> {
  final _busy = <String>{};
  Future<void> _toggle(PlatformPlan plan, bool enabled) async {
    if (_busy.contains(plan.code) || !ref.read(consoleAccessProvider).isPlatformAdmin) return;
    setState(() => _busy.add(plan.code));
    try {
      await ref.read(platformMissionControlServiceProvider).upsertPlatformPlan(PlatformPlan(
        id: plan.id, target: plan.target, code: plan.code, name: plan.name, badge: plan.badge,
        priceMonthly: plan.priceMonthly, priceYearly: plan.priceYearly, maxAthletes: plan.maxAthletes,
        features: plan.features, isActive: enabled, sortOrder: plan.sortOrder));
      if (!mounted) return;
      ref.invalidate(platformPlansProvider); ref.invalidate(platformAuditLogsProvider);
    } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paket durumu kaydedilemedi.'))); }
    finally { if (mounted) setState(() => _busy.remove(plan.code)); }
  }
  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(platformPlansProvider);
    return _Page(children: [
      const _Note('Aktif/pasif paket görünürlüğünü değiştirir; mevcut abonelik veya ödeme işlemini iptal etmez. Yıllık 0 fiyat henüz tanımlanmamış olabilir.'),
      Align(alignment: Alignment.centerLeft, child: FilledButton.icon(
        onPressed: () => showDialog<void>(context: context, builder: (_) => const _PlanDialog()),
        icon: const Icon(Icons.add), label: const Text('Yeni Paket Ekle'))),
      plans.when(loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => TextButton(onPressed: () => ref.invalidate(platformPlansProvider), child: const Text('Paketler alınamadı · Tekrar dene')),
        data: (rows) => rows.isEmpty ? const Text('Henüz paket yok.') : Wrap(spacing: ConsoleDensity.lg, runSpacing: ConsoleDensity.lg, children: [
          for (final plan in rows) SizedBox(width: ConsoleDensity.dashboardActionMinWidth, child: Card(child: Padding(
            padding: const EdgeInsets.all(ConsoleDensity.lg), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(plan.target == 'club' ? 'KULÜP' : 'SPORCU', style: Theme.of(context).textTheme.labelSmall),
              Text(plan.name, style: Theme.of(context).textTheme.titleMedium),
              Text('${fmtMoney(plan.priceMonthly)} / ay'), Text('${fmtMoney(plan.priceYearly)} / yıl'),
              Text('Sporcu limiti: ${plan.maxAthletes ?? 'Sınırsız'}'),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Aktif'), value: plan.isActive,
                onChanged: _busy.contains(plan.code) ? null : (v) => _toggle(plan, v)),
              OutlinedButton(onPressed: _busy.contains(plan.code) ? null : () => showDialog<void>(context: context, builder: (_) => _PlanDialog(plan: plan)), child: const Text('Fiyat & Limit Düzenle')),
            ]))))
        ])),
    ]);
  }
}

class _PlanDialog extends ConsumerStatefulWidget {
  const _PlanDialog({this.plan});
  final PlatformPlan? plan;
  @override
  ConsumerState<_PlanDialog> createState() => _PlanDialogState();
}
class _PlanDialogState extends ConsumerState<_PlanDialog> {
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.plan?.code);
  late final _name = TextEditingController(text: widget.plan?.name);
  late final _monthly = TextEditingController(text: '${widget.plan?.priceMonthly ?? 0}');
  late final _yearly = TextEditingController(text: '${widget.plan?.priceYearly ?? 0}');
  late final _cap = TextEditingController(text: '${widget.plan?.maxAthletes ?? ''}');
  late String _target = widget.plan?.target ?? 'club';
  bool _busy = false;
  String? _error;
  @override
  void dispose() { for (final c in [_code, _name, _monthly, _yearly, _cap]) { c.dispose(); } super.dispose(); }
  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate() || !ref.read(consoleAccessProvider).isPlatformAdmin) return;
    setState(() { _busy = true; _error = null; });
    try {
      final old = widget.plan;
      await ref.read(platformMissionControlServiceProvider).upsertPlatformPlan(PlatformPlan(
        id: old?.id, target: _target, code: _code.text.trim(), name: _name.text.trim(), badge: old?.badge,
        priceMonthly: double.parse(_monthly.text.replaceAll(',', '.')), priceYearly: double.parse(_yearly.text.replaceAll(',', '.')),
        maxAthletes: _cap.text.trim().isEmpty ? null : int.parse(_cap.text.trim()),
        features: old?.features ?? const [], isActive: old?.isActive ?? true, sortOrder: old?.sortOrder ?? 0));
      if (!mounted) return;
      ref.invalidate(platformPlansProvider); ref.invalidate(platformAuditLogsProvider);
      setState(() => _busy = false);
      Navigator.pop(context);
    } catch (_) { if (mounted) setState(() => _error = 'Paket kaydedilemedi; taslak korundu.'); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) => PopScope(canPop: !_busy, child: AlertDialog(
    title: Text(widget.plan == null ? 'Yeni Paket Ekle' : 'Paket Düzenle'),
    content: SizedBox(width: ConsoleDensity.loginCardWidth, child: SingleChildScrollView(child: Form(key: _form,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: _target, decoration: const InputDecoration(labelText: 'Hedef'),
          items: const [DropdownMenuItem(value: 'club', child: Text('Kulüp')), DropdownMenuItem(value: 'athlete', child: Text('Sporcu'))],
          onChanged: _busy || widget.plan != null ? null : (v) => setState(() => _target = v!)),
        for (final field in [(_code, 'Paket Kodu'), (_name, 'Paket Adı'), (_monthly, 'Aylık Fiyat (₺)'), (_yearly, 'Yıllık Fiyat (₺)'), (_cap, 'Sporcu Limiti (boş = sınırsız)')])
          Padding(padding: const EdgeInsets.only(top: ConsoleDensity.md), child: TextFormField(controller: field.$1,
            enabled: !_busy && !(field.$1 == _code && widget.plan != null), decoration: InputDecoration(labelText: field.$2),
            validator: (v) {
              final text = (v ?? '').trim();
              if (field.$1 == _cap) return text.isEmpty || (int.tryParse(text) != null && int.parse(text) >= 0) ? null : 'Pozitif tam sayı gir';
              if (field.$1 == _monthly || field.$1 == _yearly) {
                final n = double.tryParse(text.replaceAll(',', '.'));
                return n != null && n.isFinite && n >= 0 ? null : 'Geçerli tutar gir';
              }
              return text.isEmpty ? 'Bu alan gerekli' : null;
            })),
        if (_error != null) Text(_error!),
      ])))),
    actions: [TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Vazgeç')),
      FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Kaydediliyor…' : 'Kaydet'))],
  ));
}

class _AuditPage extends ConsumerWidget {
  const _AuditPage();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audit = ref.watch(platformAuditLogsProvider);
    final overview = ref.watch(diagnosticOverviewProvider);
    return _Page(children: [
      OutlinedButton.icon(onPressed: () => context.go('/hata-merkezi'), icon: const Icon(Icons.bug_report_outlined),
        label: Text(overview.isLoading ? 'Hata Teşhis Merkezi · Yükleniyor…' : overview.hasError ? 'Hata Teşhis Merkezi · Özet alınamadı' : 'Hata Teşhis Merkezi · ${overview.valueOrNull?['open_issues'] ?? '—'} açık hata')),
      Text('Son 50 Yönetici Eylemi', style: Theme.of(context).textTheme.titleLarge),
      audit.when(loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => TextButton(onPressed: () => ref.invalidate(platformAuditLogsProvider), child: const Text('Denetim izi alınamadı · Tekrar dene')),
        data: (rows) => rows.isEmpty ? const Text('Henüz yönetici eylemi kaydedilmedi.') : SingleChildScrollView(scrollDirection: Axis.horizontal,
          child: DataTable(columns: const [DataColumn(label: Text('Zaman')), DataColumn(label: Text('Yönetici ID')),
            DataColumn(label: Text('İşlem')), DataColumn(label: Text('Değişen Veri'))], rows: [
            for (final row in rows.take(50)) DataRow(cells: [
              DataCell(Text(row.createdAt?.toLocal().toIso8601String() ?? '—')),
              DataCell(SelectableText(row.actorId ?? 'Silinmiş hesap')),
              DataCell(Text('${row.action} · ${row.entityType}')),
              DataCell(SizedBox(width: ConsoleDensity.loginCardWidth, child: TextButton(
                onPressed: () => showDialog<void>(context: context, builder: (_) => AlertDialog(title: Text(row.entityId ?? 'Değişiklik'),
                  content: SingleChildScrollView(child: SelectableText('${const JsonEncoder.withIndent('  ').convert(row.oldState)}\n➔\n${const JsonEncoder.withIndent('  ').convert(row.newState)}')))),
                child: Text('${jsonEncode(row.oldState)} ➔ ${jsonEncode(row.newState)}', maxLines: 2, overflow: TextOverflow.ellipsis)))),
            ]),
          ])),
      ),
    ]);
  }
}
