import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tüm widget testlerinden önce bir Supabase istemcisi başlatır.
///
/// Testler fixture modunda kaldığı için bu adresle ağa istek yapılmaz. Ama bazı
/// mevcut ekranlar oturum bilgisini doğrudan `Supabase.instance` üzerinden
/// okuyor; istemci hiç başlatılmadığında test daha ekran çizilmeden düşüyordu.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://swansport-test.supabase.co',
      anonKey: 'test-anon-key',
    );
  });
  await testMain();
}
