import '../protocols/official_match_protocol.dart';
import '../schemas/branch_field_schema.dart';
import 'branch_definition_contract.dart';

/// Kulvarlı zaman yarışları. Atletizm atma/atlama protokolü değildir.
class AthleticsSwimmingDefinition implements BranchDefinitionContract {
  const AthleticsSwimmingDefinition.swimming() : code = 'yuzme';
  const AthleticsSwimmingDefinition.athletics() : code = 'atletizm';
  @override
  final String code;
  @override
  String get displayName => code == 'yuzme' ? 'Yüzme' : 'Atletizm';
  List<BranchFieldSchema> get fields => const [
        BranchFieldSchema(
          key: 'performances',
          label: 'Kulvar ve seri dereceleri',
        ),
        BranchFieldSchema(key: 'time_ms', label: 'Resmi derece (milisaniye)'),
        BranchFieldSchema(key: 'rank', label: 'Resmi sıralama'),
        BranchFieldSchema(key: 'dq', label: 'Diskalifiye'),
        BranchFieldSchema(key: 'dnf', label: 'Terk'),
      ];
  AthleticsSwimmingMatchProtocol validateProtocol(Map<String, dynamic> raw) =>
      validateMatchProtocol(code, raw) as AthleticsSwimmingMatchProtocol;
}
