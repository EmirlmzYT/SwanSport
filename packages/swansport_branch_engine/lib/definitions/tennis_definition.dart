import '../protocols/official_match_protocol.dart';
import '../schemas/branch_field_schema.dart';
import 'branch_definition_contract.dart';

class TennisDefinition implements BranchDefinitionContract {
  const TennisDefinition();
  @override
  String get code => 'tenis';
  @override
  String get displayName => 'Tenis';
  List<BranchFieldSchema> get fields => const [
        BranchFieldSchema(key: 'best_of', label: 'Üç veya beş setlik format'),
        BranchFieldSchema(key: 'sets', label: 'Set oyunları ve tie-break'),
        BranchFieldSchema(key: 'game_score', label: 'Devam eden oyun puanı'),
      ];
  TennisMatchProtocol validateProtocol(Map<String, dynamic> raw) =>
      validateMatchProtocol(code, raw) as TennisMatchProtocol;
}
