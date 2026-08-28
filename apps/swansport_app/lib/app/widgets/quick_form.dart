import 'package:flutter/material.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import 'premium.dart';

/// Basit bir form alanı tanımı.
class FormField_ {
  FormField_(this.label, {this.hint, this.keyboard, this.required = true})
      : controller = TextEditingController();

  final String label;
  final String? hint;
  final TextInputType? keyboard;
  final bool required;
  final TextEditingController controller;

  String get value => controller.text.trim();
}

/// Alttan açılan hızlı kayıt formu.
///
/// Kulüp modüllerinde (tesis, sakatlık, aidat, takım, belge) yeni kayıt
/// oluşturmak için ortak kullanılır. Kaydedilirse true döner.
Future<bool?> showQuickForm(
  BuildContext context, {
  required String title,
  required List<FormField_> fields,
  required Future<void> Function() onSubmit,
  String action = 'Kaydet',
  String? note,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _QuickForm(
      title: title,
      fields: fields,
      onSubmit: onSubmit,
      action: action,
      note: note,
    ),
  );
}

class _QuickForm extends StatefulWidget {
  const _QuickForm({
    required this.title,
    required this.fields,
    required this.onSubmit,
    required this.action,
    this.note,
  });

  final String title;
  final List<FormField_> fields;
  final Future<void> Function() onSubmit;
  final String action;
  final String? note;

  @override
  State<_QuickForm> createState() => _QuickFormState();
}

class _QuickFormState extends State<_QuickForm> {
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    for (final f in widget.fields) {
      if (f.required && f.value.isEmpty) {
        setState(() => _error = '${f.label} boş bırakılamaz');
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Kaydedilemedi: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final alt = isDark ? const Color(0xFF1A2537) : const Color(0xFFF1F5F8);
    final grip = isDark ? const Color(0xFF2E3B4E) : const Color(0xFFE4E9F0);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: surf,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: grip, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 16),
            Text(widget.title, style: sora(20, FontWeight.w800, ink)),
            if (widget.note != null) ...[
              const SizedBox(height: 6),
              Text(widget.note!,
                  style: jakarta(
                      12, FontWeight.w500, SwanColors.textSecondary)),
            ],
            const SizedBox(height: 18),

            for (final f in widget.fields) ...[
              Text(f.label.toUpperCase(),
                  style: jakarta(
                      10.5, FontWeight.w800, SwanColors.textSecondary,
                      ls: 1.1)),
              const SizedBox(height: 7),
              TextField(
                controller: f.controller,
                keyboardType: f.keyboard,
                style: jakarta(13.5, FontWeight.w600, ink),
                decoration: InputDecoration(
                  hintText: f.hint,
                  hintStyle:
                      jakarta(13, FontWeight.w500, SwanColors.textSecondary),
                  filled: true,
                  fillColor: alt,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 15, vertical: 13),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: line)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: kTeal, width: 1.5)),
                ),
              ),
              const SizedBox(height: 14),
            ],

            if (_error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF43F5E).withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFF43F5E).withValues(alpha: .35)),
                ),
                child: Text(_error!,
                    style: jakarta(
                        12, FontWeight.w600, const Color(0xFFF43F5E))),
              ),
              const SizedBox(height: 14),
            ],

            GestureDetector(
              onTap: _busy ? null : _submit,
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [kTealBright, kTeal]),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: kTeal.withValues(alpha: .32),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: Text(_busy ? 'Kaydediliyor…' : widget.action,
                    style: jakarta(14.5, FontWeight.w800, Colors.white)),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Vazgeç',
                    style: jakarta(
                        13, FontWeight.w700, SwanColors.textSecondary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ekran başlıklarında kullanılan yuvarlak "+" düğmesi.
class AddButton extends StatelessWidget {
  const AddButton({super.key, required this.onTap, this.tooltip});
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [kTealBright, kTeal]),
          borderRadius: BorderRadius.circular(13),
          boxShadow: [
            BoxShadow(
              color: kTeal.withValues(alpha: .3),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}
