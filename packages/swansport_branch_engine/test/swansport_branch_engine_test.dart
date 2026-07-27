import 'package:swansport_branch_engine/swansport_branch_engine.dart';
import 'package:test/test.dart';

void main() {
  test('creates a branch field schema', () {
    const schema = BranchFieldSchema(key: 'level', label: 'Level');

    expect(schema.key, 'level');
  });
}
