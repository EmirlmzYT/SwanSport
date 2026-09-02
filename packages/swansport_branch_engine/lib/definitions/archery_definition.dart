import 'branch_definition_contract.dart';
import '../schemas/branch_field_schema.dart';

/// Okçuluk — motorun ilk çalışan branşı.
///
/// Bu sınıfın tek işi, branşa özgü **kelimeleri** tek yerde tutmak: motorun
/// geri kalanı "unit" diyor, sporcu "ok" görüyor. Yüzme eklendiğinde aynı
/// yerde "kulvar", atletizmde "deneme" olacak — tablo ve RPC değişmeyecek.
class ArcheryDefinition implements BranchDefinitionContract {
  const ArcheryDefinition();

  @override
  String get code => 'okculuk';

  @override
  String get displayName => 'Okçuluk';

  /// Set içindeki tek denemenin adı: "3 **ok**".
  String get unitLabel => 'ok';

  /// Çoğul biçim. Türkçede sayıdan sonra çoğul eki gelmiyor ("3 ok"), o
  /// yüzden ikisi de aynı; başka branşta ayrışabilir.
  String get unitLabelPlural => 'ok';

  /// Aşamanın branştaki karşılığı — motorun `collect` aşaması okçulukta
  /// "ok toplama".
  String get collectLabel => 'Ok toplama';

  /// Sonuç ekranında puan dağılımının başlığı.
  String get distributionLabel => 'Puan dağılımı';

  /// Antrenörün şablon yazarken göreceği alanlar.
  List<BranchFieldSchema> get fields => const [
        BranchFieldSchema(key: 'set_count', label: 'Set sayısı'),
        BranchFieldSchema(key: 'units_per_set', label: 'Set başına ok'),
        BranchFieldSchema(key: 'prep_seconds', label: 'Hazırlık süresi (sn)'),
        BranchFieldSchema(key: 'shoot_seconds', label: 'Atış süresi (sn)'),
        BranchFieldSchema(key: 'collect_seconds', label: 'Ok toplama (sn)'),
        BranchFieldSchema(key: 'rest_seconds', label: 'Dinlenme (sn)'),
        BranchFieldSchema(key: 'max_unit_score', label: 'Bir ok en fazla'),
      ];
}

/// Motorun tanıdığı branşlar. Yeni branş buraya bir satır.
const List<BranchDefinitionContract> kBranchDefinitions = [
  ArcheryDefinition(),
];

/// Branş kodundan tanım. Tanınmayan branş `null` — çağıran taraf genel
/// ("birim", "set") kelimeleri kullanıyor, çökmüyor.
BranchDefinitionContract? branchByCode(String? code) {
  for (final b in kBranchDefinitions) {
    if (b.code == code) return b;
  }
  return null;
}
