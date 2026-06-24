import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  var databaseFactory = databaseFactoryFfi;

  final supportDir = 'C:\\Users\\YouthTech\\AppData\\Roaming\\com.bashirlab\\bashir_lab';
  final dbNames = ['Bashir_lab.db', 'Bashir_lab.db.bak', 'bashir_lab.db'];

  for (var name in dbNames) {
    final path = join(supportDir, name);
    if (!await File(path).exists()) {
      print('$name does not exist.');
      continue;
    }
    print('\n================== INSPECTING $name ==================');
    var db = await databaseFactory.openDatabase(path);

    // List all tables
    var tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table';");
    print('Tables: ${tables.map((t) => t['name']).toList()}');

    // Count in each table
    for (var tableMap in tables) {
      final tableName = tableMap['name'] as String;
      if (tableName.startsWith('sqlite_')) continue;
      try {
        var countRes = await db.rawQuery('SELECT COUNT(*) as cnt FROM $tableName');
        print('  Table $tableName: ${countRes.first['cnt']} rows');
        if (tableName == 'lab_settings') {
          var settings = await db.query(tableName);
          print('    Settings: $settings');
        }
        if (tableName == 'tests') {
          var testSample = await db.query(tableName, limit: 3);
          print('    Test samples: $testSample');
        }
      } catch (e) {
        print('  Error reading $tableName: $e');
      }
    }
    await db.close();
  }
}
