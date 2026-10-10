import '../protocols/official_match_protocol.dart';
import '../schemas/branch_field_schema.dart';
import 'branch_definition_contract.dart';

class FootballDefinition implements BranchDefinitionContract {
  const FootballDefinition();
  @override
  String get code => 'futbol';
  @override
  String get displayName => 'Futbol';
  List<BranchFieldSchema> get fields => const [
        BranchFieldSchema(key: 'halves', label: 'İlk ve ikinci yarı'),
        BranchFieldSchema(key: 'extra_time', label: 'Uzatma devreleri'),
        BranchFieldSchema(key: 'penalties', label: 'Seri penaltı atışları'),
        BranchFieldSchema(key: 'goals', label: 'Gol dakikası ve oyuncu'),
        BranchFieldSchema(key: 'cards', label: 'Sarı ve kırmızı kartlar'),
      ];
  FootballMatchProtocol validateProtocol(Map<String, dynamic> raw) =>
      validateMatchProtocol(code, raw) as FootballMatchProtocol;
}
