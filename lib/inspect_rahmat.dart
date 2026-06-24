import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  var databaseFactory = databaseFactoryFfi;

  final rahmatDbPath = 'C:\\Users\\YouthTech\\AppData\\Roaming\\com.rehmatlab\\rehmat_lab\\rahmat_lab.db';
  if (!await File(rahmatDbPath).exists()) {
    print('rahmat_lab.db does not exist.');
    return;
  }
  print('\n================== INSPECTING rahmat_lab.db ==================');
  var db = await databaseFactory.openDatabase(rahmatDbPath);

  try {
    var tests = await db.query('tests');
    print('Test count: ${tests.length}');
    print('Test names: ${tests.map((t) => t['testName']).toList()}');
  } catch (e) {
    print('Error: $e');
  }
  await db.close();
}
