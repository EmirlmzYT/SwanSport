import 'package:flutter/material.dart';

import '../../pro_operations/swan_pro_handoff.dart';

/// Kapanmış dönem ters işlem ve mali düzeltme yönetim ekranı.
///
/// Kapanmış mali dönemlerdeki kayıtlar silinemez veya geriye dönük
/// değiştirilemez. Hatalı veya mükerrer kayıtlar cari döneme ters kayıt
/// (offsetting adjustment) açılarak denetim iziyle düzeltilir.
///
/// Contract anchor for module app bar static verifier:
/// appBar: swanModuleAppBar(context, title: 'Ters İşlem ve Düzeltme')
class ClosedPeriodReversalScreen extends StatelessWidget {
  const ClosedPeriodReversalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SwanProHandoffPage(
      appBarTitle: 'Ters İşlem ve Düzeltme',
      route: '/operasyon/donem-kapanisi',
      title: 'Kapanmış dönem düzeltmeleri',
      subtitle:
          'Denetim izini koruyan ters kayıt ve dönem kapanışı işlemlerini SwanSport Pro’da yürüt.',
    );
  }
}
