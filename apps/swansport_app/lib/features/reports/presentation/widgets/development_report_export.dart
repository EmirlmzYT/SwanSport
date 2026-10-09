import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_type.dart';

/// Explicit, private text export. No public URL or report snapshot is created.
class DevelopmentReportExport extends ConsumerStatefulWidget {
  const DevelopmentReportExport({
    super.key,
    required this.request,
    required this.report,
  });
  final DevelopmentReportRequest request;
  final DevelopmentReport report;
  @override
  ConsumerState<DevelopmentReportExport> createState() =>
      _DevelopmentReportExportState();
}

class _DevelopmentReportExportState
    extends ConsumerState<DevelopmentReportExport> {
  late DevelopmentReport _report;
  bool _identity = false, _busy = false;
  bool _sessionChanged = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _report = widget.report;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    ref.listen(authSessionProvider, (previous, next) {
      if (previous?.hasValue == true &&
          next.hasValue &&
          previous!.valueOrNull?.user.id != next.valueOrNull?.user.id) {
        _sessionChanged = true;
        unawaited(Navigator.maybePop(context));
      }
    });
    return AlertDialog(
      backgroundColor: c.surface,
      title: Text('Rapor metni', style: SwanType.h3(c.ink)),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                value: _identity,
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _identity = v ?? false),
                title: Text(
                  'Adı ve kulübü metne dahil et',
                  style: SwanType.bodySm(c.ink),
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              Text(
                _report.text(includeIdentity: _identity),
                style: SwanType.bodySm(c.ink),
              ),
              if (_error != null)
                Text(_error!, style: SwanType.bodySm(c.danger)),
              if (_busy) const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Kapat'),
        ),
        TextButton(
          onPressed: _busy ? null : _copy,
          child: const Text('Metni kopyala'),
        ),
      ],
    );
  }

  Future<void> _copy() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Always reauthorize on the server; an old preview cannot bypass unlinking.
      final current =
          await ref.read(developmentReportServiceProvider).load(widget.request);
      if (!mounted || _sessionChanged) return;
      if (current.fingerprint != _report.fingerprint) {
        setState(() {
          _report = current;
          _error = 'Veri değişti. Güncel metni inceleyip tekrar kopyala.';
        });
        return;
      }
      await Clipboard.setData(
        ClipboardData(text: current.text(includeIdentity: _identity)),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rapor metni kopyalandı.')),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Metin kopyalanamadı. Bağlantını ve rapora erişimini kontrol et.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
