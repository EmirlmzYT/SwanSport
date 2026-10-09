import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

/// Uses the existing finance service and database policy; waits for confirmation.
class FeePlanStatusSwitch extends ConsumerStatefulWidget {
  const FeePlanStatusSwitch({required this.plan, super.key});
  final FeePlan plan;
  @override
  ConsumerState<FeePlanStatusSwitch> createState() =>
      _FeePlanStatusSwitchState();
}

class _FeePlanStatusSwitchState extends ConsumerState<FeePlanStatusSwitch> {
  bool _busy = false;
  Future<void> _change(bool active) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(financeServiceProvider)
          .setPlanActive(widget.plan.id, active);
      if (mounted) ref.invalidate(feePlansProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Plan durumu kaydedilemedi. Yeniden dene.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(swanAccessProvider);
    return Semantics(
      label:
          '${widget.plan.name}: ${widget.plan.active ? 'aktif' : 'pasif taslak'}',
      child: Switch(
        value: widget.plan.active,
        onChanged: _busy || !(access.isClubStaff || access.isAccountant)
            ? null
            : _change,
      ),
    );
  }
}
