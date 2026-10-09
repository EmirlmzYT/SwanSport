import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

Future<Database> openAttendanceDatabase() async {
  final dir = await getApplicationSupportDirectory();
  await dir.create(recursive: true);
  return databaseFactoryIo.openDatabase(
    '${dir.path}/attendance-v1.db',
    version: 1,
  );
}

// IO transactions append lazily. An atomic compaction is the durable write barrier.
Future<void> attendanceCommitBarrier(Database db) => db.compact();
