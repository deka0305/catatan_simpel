import 'package:flutter_test/flutter_test.dart';
import 'package:catatan_simpel/pages/sync_all_data_page.dart';

void main() {
  test('splitSqlStatements tidak memecah ; di dalam string', () {
    final out = splitSqlStatements(
        "INSERT INTO notes VALUES(1, 'a;b', 'it''s');\nCOMMIT;\n  ");
    expect(out, ["INSERT INTO notes VALUES(1, 'a;b', 'it''s')", 'COMMIT']);
  });
}
