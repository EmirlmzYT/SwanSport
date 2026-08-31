import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/design/swan_palette.dart';

/// Davet kodu girişi.
///
/// Tek ekran, üç amaç: veli çocuğuna bağlanıyor, muhasebeci kulübün
/// defterine, halı saha görevlisi sahasına. Kodun ne işe yaradığını sunucu
/// belirliyor (`invite_codes.purpose`), bu yüzden burada ayrı akış yok —
/// ikinci bir ekran yazmak aynı RPC'yi üç yerden çağırmak olurdu.
class GuardianLinkScreen extends ConsumerStatefulWidget {
  const GuardianLinkScreen({super.key});

  @override
  ConsumerState<GuardianLinkScreen> createState() => _GuardianLinkScreenState();
}

class _GuardianLinkScreenState extends ConsumerState<GuardianLinkScreen> {
  final _ctrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = (isDark ? SwanPalette.dark : SwanPalette.light).bg;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              children: [
                GestureDetector(
                  onTap: () => Navigator.maybePop(context),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                        color: surf,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: line),),
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 15, color: ink,),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF4FC3F7), Color(0xFF2563EB)],),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child:
                      Text('V', style: SwanType.h2(Colors.white)),
                ),
                const SizedBox(height: 20),
                Text('Davet kodu', style: SwanType.h1(ink)),
                const SizedBox(height: 8),
                Text(
                    'Sporcunun (veya kulübün) verdiği tek kullanımlık davet '
                    'kodunu gir.',
                    style: SwanType.bodySm(SwanColors.textSecondary),),
                const SizedBox(height: 22),
                TextField(
                  controller: _ctrl,
                  textCapitalization: TextCapitalization.characters,
                  textAlign: TextAlign.center,
                  style: SwanType.h2(ink),
                  decoration: InputDecoration(
                    hintText: 'K O D',
                    hintStyle: SwanType.h2(SwanColors.textSecondary),
                    filled: true,
                    fillColor: surf,
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: line),),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: const BorderSide(color: kTeal, width: 1.5),),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.schedule_rounded,
                        size: 14, color: SwanColors.textSecondary,),
                    const SizedBox(width: 6),
                    Text('Kod tek kullanımlık ve süreli — veren kişiden yeni kod iste',
                        style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600),),
                  ],
                ),
                const SizedBox(height: 22),
                GestureDetector(
                  onTap: _busy ? null : _redeem,
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient:
                          const LinearGradient(colors: [kTealBright, kTeal]),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                            color: kTeal.withValues(alpha: .34),
                            blurRadius: 18,
                            offset: const Offset(0, 8),),
                      ],
                    ),
                    child: Text(_busy ? 'Bağlanıyor…' : 'Sporcuya Bağlan',
                        style: SwanType.bodySm(Colors.white, w: FontWeight.w800),),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _redeem() async {
    final code = _ctrl.text.trim();
    if (code.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(verificationServiceProvider).redeemInvite(code);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Bağlandın.'),
            backgroundColor: kTeal,),);
        Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (_) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: SwanPalette.light.danger,),);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
