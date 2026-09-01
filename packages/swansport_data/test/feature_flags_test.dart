import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';

/// Özellik bayrakları.
///
/// Buradaki en önemli iddia **varsayılanın kapalı olması.** Sunucuya
/// ulaşılamadığında açık varsaymak, bir ağ hatasının denenmemiş bir özelliği
/// herkese açması demek — tam olarak bayrakların engellemek için var olduğu
/// şey.
void main() {
  group('varsayılan davranış', () {
    test('bayrak yoksa özellik KAPALI', () {
      const flags = FeatureFlags.none();
      expect(flags.has(FeatureFlags.marketplace), isFalse);
      expect(flags.has(FeatureFlags.courts), isFalse);
    });

    test('bilinmeyen anahtar kapalı sayılır', () {
      // Yazım hatası sessizce "açık" dönmemeli.
      const flags = FeatureFlags({'marketplace'});
      expect(flags.has('marketpalce'), isFalse);
      expect(flags.has(''), isFalse);
    });
  });

  group('açık bayraklar', () {
    test('listede olan açık, olmayan kapalı', () {
      const flags = FeatureFlags({'marketplace', 'courts'});
      expect(flags.has(FeatureFlags.marketplace), isTrue);
      expect(flags.has(FeatureFlags.courts), isTrue);
      expect(flags.has(FeatureFlags.partnerSearch), isFalse);
    });
  });

  group('anahtar sabitleri şemayla eşleşmeli', () {
    test('0053''teki anahtarlarla birebir', () {
      // Ayrışırsa bayrak hiç açılmaz ve sebebi görünmez: sunucu
      // 'partner_search' derken istemci 'partnerSearch' arar.
      expect(FeatureFlags.marketplace, 'marketplace');
      expect(FeatureFlags.courts, 'courts');
      expect(FeatureFlags.partnerSearch, 'partner_search');
      expect(FeatureFlags.turfFields, 'turf_fields');
      expect(FeatureFlags.teamHub, 'team_hub');
    });
  });
}
