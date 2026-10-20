import 'package:flutter/material.dart';

/// Neutral quantity prompt shared by mobile and console. No data writes.
class SwanQuantityDialog extends StatefulWidget {
  const SwanQuantityDialog(
      {required this.maximum, required this.title, super.key});
  final int maximum;
  final String title;
  @override
  State<SwanQuantityDialog> createState() => _SwanQuantityDialogState();
}

class _SwanQuantityDialogState extends State<SwanQuantityDialog> {
  late final _quantity = TextEditingController(text: '${widget.maximum}');
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: Text(widget.title),
          content: Form(
              key: _form,
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Kalan ${widget.maximum} adetten işlem yapılacak miktarı seç. Kalanı zimmette kalır.'),
                    TextFormField(
                        controller: _quantity,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        decoration: const InputDecoration(labelText: 'Adet'),
                        validator: (s) {
                          final n = int.tryParse(s ?? '');
                          return n == null || n < 1 || n > widget.maximum
                              ? '1–${widget.maximum} arası tam sayı gir.'
                              : null;
                        })
                  ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Vazgeç')),
            FilledButton(
                onPressed: () {
                  if (_form.currentState!.validate())
                    Navigator.pop(context, int.parse(_quantity.text));
                },
                child: const Text('Kaydet'))
          ]);
}
