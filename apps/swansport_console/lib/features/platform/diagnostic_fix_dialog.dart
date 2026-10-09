import 'package:flutter/material.dart';
import 'package:swansport_data/swansport_data.dart';

class DiagnosticFixDialog extends StatefulWidget {
  const DiagnosticFixDialog({super.key});
  @override
  State<DiagnosticFixDialog> createState() => _DiagnosticFixDialogState();
}

class _DiagnosticFixDialogState extends State<DiagnosticFixDialog> {
  final _release = TextEditingController();
  final _form = GlobalKey<FormState>();
  String? _platform;
  @override
  void dispose() {
    _release.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Düzeltmenin yayın kapsamı'),
        content: SingleChildScrollView(
            child: Form(
                key: _form,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                      controller: _release,
                      decoration: const InputDecoration(
                          labelText: 'Düzeltme sürümü', hintText: '0.5.2+17'),
                      validator: (value) => diagnosticReleaseAtLeast(
                              value?.trim() ?? '', value?.trim() ?? '')
                          ? null
                          : 'Geçerli sürüm/build gir'),
                  DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                          labelText: 'Düzeltme platformu'),
                      items: [
                        for (final p in [
                          'android',
                          'web',
                          'ios',
                          'windows',
                          'macos',
                          'linux'
                        ])
                          DropdownMenuItem(value: p, child: Text(p))
                      ],
                      onChanged: (value) => setState(() => _platform = value),
                      validator: (value) =>
                          value == null ? 'Platform seç' : null),
                  const Text(
                      'Yayınlanan düzeltmeyi bildirir. Kullanıcı teyidi ve sonraki teknik hatalar ayrıca izlenir.'),
                ]))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () {
                if (_form.currentState!.validate()) {
                  Navigator.pop(context, (_release.text.trim(), _platform!));
                }
              },
              child: const Text('Düzeltmeyi bildir'))
        ],
      );
}
