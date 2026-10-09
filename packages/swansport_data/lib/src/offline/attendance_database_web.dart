import 'package:sembast_web/sembast_web.dart';

Future<Database> openAttendanceDatabase() =>
    databaseFactoryWeb.openDatabase('swansport-attendance-v1', version: 1);
// IndexedDB persistence is awaited by the transaction itself.
Future<void> attendanceCommitBarrier(Database db) async {}
