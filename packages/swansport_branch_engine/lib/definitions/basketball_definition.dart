import '../protocols/official_match_protocol.dart';
import '../schemas/branch_field_schema.dart';
import 'branch_definition_contract.dart';

class BasketballDefinition implements BranchDefinitionContract {
  const BasketballDefinition();
  @override
  String get code => 'basketbol';
  @override
  String get displayName => 'Basketbol';
  List<BranchFieldSchema> get fields => const [
        BranchFieldSchema(key: 'periods', label: 'Çeyrekler ve uzatmalar'),
        BranchFieldSchema(key: 'team_fouls', label: 'Periyot takım faulleri'),
        BranchFieldSchema(
          key: 'players',
          label: 'Sayı, ribaund, asist ve faul',
        ),
      ];
  BasketballMatchProtocol validateProtocol(Map<String, dynamic> raw) =>
      validateMatchProtocol(code, raw) as BasketballMatchProtocol;
}
