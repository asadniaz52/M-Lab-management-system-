import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';

class DBHelper {
  static Database? _database;
  static const String _dbName = 'bashir_lab.db';
  static const int _dbVersion = 6;

  static Future<void> initializeFfi() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    return Future.value();
  }

  static Future<String> getDatabasePath() async {
    final dir = await getApplicationSupportDirectory();
    return join(dir.path, _dbName);
  }

  static Future<void> backupDatabase(String destinationPath) async {
    final dbPath = await getDatabasePath();
    final file = File(dbPath);
    if (await file.exists()) {
      await file.copy(destinationPath);
    }
  }

  static Future<void> restoreDatabase(String sourcePath) async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    final dbPath = await getDatabasePath();
    final srcFile = File(sourcePath);
    if (await srcFile.exists()) {
      await srcFile.copy(dbPath);
    }
  }

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    final dir = await getApplicationSupportDirectory();
    final path = join(dir.path, _dbName);

    final db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    // Auto-update old lab settings to MUHAMMAD MEDICAL LABORATORY
    try {
      final settings = await db.query('lab_settings');
      if (settings.isNotEmpty) {
        final currentLabName = settings.first['labName'] as String? ?? '';
        final lowerLabName = currentLabName.toLowerCase();
        if (lowerLabName.contains('iqra') || lowerLabName.contains('umar') || lowerLabName.contains('umer') || lowerLabName.contains('bashir') || lowerLabName.contains('united')) {
          await db.update('lab_settings', {
            'labName': 'MUHAMMAD MEDICAL LABORATORY',
            'labNameUrdu': 'محمد میڈیکل لیبارٹری',
            'address': 'Opp: gate no 01 Professer Medical Center',
            'phone': '0928-611111 , 03329740305',
            'ceoName': '',
            'ceoEducation': '',
            'inchargeName': '',
            'inchargeEducation': '',
            'watermarkText': 'MUHAMMAD MEDICAL LABORATORY',
          }, where: 'id = ?', whereArgs: [1]);
        }
      }
    } catch (_) {}

    return db;
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        fullName TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'technician',
        phone TEXT,
        createdAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE patients(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        age INTEGER NOT NULL,
        gender TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        nic TEXT DEFAULT '',
        createdAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE tests(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        testName TEXT NOT NULL,
        normalRange TEXT,
        unit TEXT,
        price REAL NOT NULL DEFAULT 0,
        category TEXT DEFAULT 'General',
        printPage INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE test_parameters(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parentTestId INTEGER NOT NULL,
        paramName TEXT NOT NULL,
        normalRange TEXT DEFAULT '',
        unit TEXT DEFAULT '',
        sortOrder INTEGER DEFAULT 0,
        rangeType TEXT DEFAULT 'normal',
        normalRangeMale TEXT DEFAULT '',
        normalRangeFemale TEXT DEFAULT '',
        normalRangeChild TEXT DEFAULT '',
        FOREIGN KEY(parentTestId) REFERENCES tests(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE reports(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        patientId INTEGER NOT NULL,
        patientName TEXT,
        date TEXT NOT NULL,
        status TEXT DEFAULT 'pending',
        remarks TEXT,
        referredBy TEXT,
        verifiedBy TEXT DEFAULT '',
        verifiedAt TEXT DEFAULT '',
        specimen TEXT DEFAULT '',
        FOREIGN KEY(patientId) REFERENCES patients(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE test_results(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reportId INTEGER NOT NULL,
        testId INTEGER NOT NULL,
        testName TEXT,
        result TEXT,
        normalRange TEXT,
        unit TEXT,
        isAbnormal INTEGER DEFAULT 0,
        category TEXT DEFAULT '',
        printPage INTEGER DEFAULT 0,
        FOREIGN KEY(reportId) REFERENCES reports(id),
        FOREIGN KEY(testId) REFERENCES tests(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE invoices(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        patientId INTEGER NOT NULL,
        patientName TEXT,
        reportId INTEGER,
        totalAmount REAL NOT NULL DEFAULT 0,
        discount REAL DEFAULT 0,
        paidAmount REAL DEFAULT 0,
        date TEXT NOT NULL,
        status TEXT DEFAULT 'unpaid',
        FOREIGN KEY(patientId) REFERENCES patients(id),
        FOREIGN KEY(reportId) REFERENCES reports(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE invoice_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoiceId INTEGER NOT NULL,
        testId INTEGER,
        testName TEXT NOT NULL,
        price REAL NOT NULL DEFAULT 0,
        FOREIGN KEY(invoiceId) REFERENCES invoices(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE lab_settings(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        labName TEXT DEFAULT 'Umar Medical Laboratory',
        labNameUrdu TEXT DEFAULT 'Ø¹Ù…Ø± Ù…ÛŒÚˆÛŒÚ©Ù„ Ù„ÛŒØ¨Ø§Ø±Ù¹Ø±ÛŒ',
        address TEXT DEFAULT 'Bannu',
        phone TEXT DEFAULT '',
        email TEXT DEFAULT '',
        logoPath TEXT DEFAULT '',
        headerImagePath TEXT DEFAULT '',
        watermarkText TEXT DEFAULT '',
        doctorName TEXT DEFAULT '',
        ceoName TEXT DEFAULT '',
        inchargeName TEXT DEFAULT '',
        ceoEducation TEXT DEFAULT '',
        inchargeEducation TEXT DEFAULT '',
        printHeaderFooter INTEGER DEFAULT 1,
        registrationNo TEXT DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE employees(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT DEFAULT '',
        type TEXT DEFAULT 'employee',
        department TEXT DEFAULT '',
        joinDate TEXT NOT NULL,
        endDate TEXT DEFAULT '',
        status TEXT DEFAULT 'active'
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employeeId INTEGER NOT NULL,
        date TEXT NOT NULL,
        checkIn TEXT DEFAULT '',
        checkOut TEXT DEFAULT '',
        status TEXT DEFAULT 'present',
        FOREIGN KEY(employeeId) REFERENCES employees(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE footer_signatures(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        designation TEXT DEFAULT '',
        education TEXT DEFAULT '',
        sortOrder INTEGER DEFAULT 0
      )
    ''');

    // Insert default lab settings
    await db.insert('lab_settings', {
      'labName': 'MUHAMMAD MEDICAL LABORATORY',
      'labNameUrdu': 'محمد میڈیکل لیبارٹری',
      'address': 'Opp: gate no 01 Professer Medical Center',
      'phone': '0928-611111 , 03329740305',
      'email': '',
      'logoPath': '',
      'headerImagePath': '',
      'watermarkText': 'MUHAMMAD MEDICAL LABORATORY',
      'doctorName': '',
      'ceoName': '',
      'inchargeName': '',
      'ceoEducation': '',
      'inchargeEducation': '',
      'printHeaderFooter': 1,
      'registrationNo': '',
    });

    // Insert default signatures
    final defaultSignatures = [
      {'name': 'D Khalid Latif', 'designation': '', 'education': 'MBBS(KMC)\nMCPS\nFCPS', 'sortOrder': 1},
      {'name': 'M Razib Khan', 'designation': '', 'education': 'DMLT (PATHOLOGY )\nBSc (Pathology)', 'sortOrder': 2},
      {'name': 'Sher Rehman', 'designation': '', 'education': 'DMLT (PATHOLOGY )\nMSc (Microbiology)', 'sortOrder': 3},
      {'name': 'Abdul Haleem', 'designation': '', 'education': 'DMLT (PATHOLOGY)', 'sortOrder': 4},
    ];
    for (var sig in defaultSignatures) {
      await db.insert('footer_signatures', sig);
    }

    // Insert default tests
    final defaultTests = [
      {'id': 1, 'testName': 'Complete Blood Count (CBC)', 'normalRange': '-', 'unit': '-', 'price': 500.0, 'category': 'Hematology', 'printPage': 0},
      {'id': 2, 'testName': 'Hemoglobin (Hb)', 'normalRange': '12-17 g/dL', 'unit': 'g/dL', 'price': 200.0, 'category': 'Hematology', 'printPage': 0},
      {'id': 3, 'testName': 'WBC Count', 'normalRange': '4000-11000', 'unit': '/cumm', 'price': 200.0, 'category': 'Hematology', 'printPage': 0},
      {'id': 4, 'testName': 'Platelet Count', 'normalRange': '150000-400000', 'unit': '/cumm', 'price': 250.0, 'category': 'Hematology', 'printPage': 0},
      {'id': 5, 'testName': 'ESR', 'normalRange': '0-20 mm/hr', 'unit': 'mm/hr', 'price': 150.0, 'category': 'Hematology', 'printPage': 0},
      {'id': 6, 'testName': 'Blood Group', 'normalRange': '-', 'unit': '-', 'price': 200.0, 'category': 'Hematology', 'printPage': 0},
      {'id': 7, 'testName': 'Fasting Blood Sugar', 'normalRange': '70-110 mg/dL', 'unit': 'mg/dL', 'price': 200.0, 'category': 'Biochemistry', 'printPage': 0},
      {'id': 8, 'testName': 'Random Blood Sugar', 'normalRange': '70-140 mg/dL', 'unit': 'mg/dL', 'price': 200.0, 'category': 'Biochemistry', 'printPage': 0},
      {'id': 9, 'testName': 'HbA1c', 'normalRange': '4-6%', 'unit': '%', 'price': 800.0, 'category': 'Biochemistry', 'printPage': 0},
      {'id': 10, 'testName': 'Urea', 'normalRange': '15-45 mg/dL', 'unit': 'mg/dL', 'price': 250.0, 'category': 'Biochemistry', 'printPage': 0},
      {'id': 11, 'testName': 'Creatinine', 'normalRange': '0.6-1.2 mg/dL', 'unit': 'mg/dL', 'price': 250.0, 'category': 'Biochemistry', 'printPage': 0},
      {'id': 12, 'testName': 'Uric Acid', 'normalRange': '3.5-7.2 mg/dL', 'unit': 'mg/dL', 'price': 300.0, 'category': 'Biochemistry', 'printPage': 0},
      {'id': 13, 'testName': 'Cholesterol', 'normalRange': '<200 mg/dL', 'unit': 'mg/dL', 'price': 300.0, 'category': 'Biochemistry', 'printPage': 0},
      {'id': 14, 'testName': 'Triglycerides', 'normalRange': '<150 mg/dL', 'unit': 'mg/dL', 'price': 350.0, 'category': 'Biochemistry', 'printPage': 0},
      {'id': 15, 'testName': 'SGPT (ALT)', 'normalRange': '7-56 U/L', 'unit': 'U/L', 'price': 300.0, 'category': 'Liver Function', 'printPage': 0},
      {'id': 16, 'testName': 'SGOT (AST)', 'normalRange': '10-40 U/L', 'unit': 'U/L', 'price': 300.0, 'category': 'Liver Function', 'printPage': 0},
      {'id': 17, 'testName': 'Bilirubin Total', 'normalRange': '0.1-1.0 mg/dL', 'unit': 'mg/dL', 'price': 250.0, 'category': 'Liver Function', 'printPage': 0},
      {'id': 18, 'testName': 'Alkaline Phosphatase', 'normalRange': '44-147 U/L', 'unit': 'U/L', 'price': 300.0, 'category': 'Liver Function', 'printPage': 0},
      {'id': 19, 'testName': 'Urine Routine (R/E)', 'normalRange': '-', 'unit': '-', 'price': 200.0, 'category': 'Urine', 'printPage': 0},
      {'id': 20, 'testName': 'Urine Culture', 'normalRange': '-', 'unit': '-', 'price': 600.0, 'category': 'Urine', 'printPage': 0},
      {'id': 21, 'testName': 'Thyroid TSH', 'normalRange': '0.4-4.0 mIU/L', 'unit': 'mIU/L', 'price': 800.0, 'category': 'Thyroid', 'printPage': 0},
      {'id': 22, 'testName': 'T3', 'normalRange': '0.8-2.0 ng/mL', 'unit': 'ng/mL', 'price': 600.0, 'category': 'Thyroid', 'printPage': 0},
      {'id': 23, 'testName': 'T4', 'normalRange': '5.1-14.1 ug/dL', 'unit': 'ug/dL', 'price': 600.0, 'category': 'Thyroid', 'printPage': 0},
      {'id': 24, 'testName': 'Widal Test', 'normalRange': '-', 'unit': '-', 'price': 300.0, 'category': 'Serology', 'printPage': 0},
      {'id': 25, 'testName': 'Hepatitis B (HBsAg)', 'normalRange': 'Negative', 'unit': '-', 'price': 400.0, 'category': 'Serology', 'printPage': 0},
      {'id': 26, 'testName': 'Hepatitis C (Anti-HCV)', 'normalRange': 'Negative', 'unit': '-', 'price': 400.0, 'category': 'Serology', 'printPage': 0},
      {'id': 27, 'testName': 'H Pylori', 'normalRange': 'Negative', 'unit': '', 'price': 600.0, 'category': 'Serology', 'printPage': 0},
      {'id': 28, 'testName': 'ALK', 'normalRange': '', 'unit': '', 'price': 300.0, 'category': 'Biochemistry', 'printPage': 1},
      {'id': 29, 'testName': 'BIL', 'normalRange': '{0-1.0 mg/dl}', 'unit': 'mg/dl', 'price': 300.0, 'category': 'Biochemistry', 'printPage': 0},
      {'id': 30, 'testName': 'HBS HCV', 'normalRange': 'Negative', 'unit': '', 'price': 800.0, 'category': 'Serology', 'printPage': 0},
      {'id': 31, 'testName': 'HIV', 'normalRange': 'Negative', 'unit': '', 'price': 1000.0, 'category': 'Serology', 'printPage': 0},
      {'id': 32, 'testName': 'VDRL', 'normalRange': 'Negative', 'unit': '', 'price': 500.0, 'category': 'Serology', 'printPage': 0},
      {'id': 33, 'testName': 'TPHA', 'normalRange': 'Negative', 'unit': '', 'price': 500.0, 'category': 'Serology', 'printPage': 0},
      {'id': 34, 'testName': 'HBS', 'normalRange': 'Negative', 'unit': '', 'price': 400.0, 'category': 'Serology', 'printPage': 0},
      {'id': 35, 'testName': 'HCV', 'normalRange': 'Negative', 'unit': '', 'price': 400.0, 'category': 'Serology', 'printPage': 0},
      {'id': 36, 'testName': 'HBS HCV HIV', 'normalRange': 'Negative', 'unit': '', 'price': 1700.0, 'category': 'Serology', 'printPage': 0},
      {'id': 37, 'testName': 'Aso Titer', 'normalRange': '200', 'unit': 'iu/ml', 'price': 500.0, 'category': 'Serology', 'printPage': 0},
      {'id': 38, 'testName': 'Ra Factor', 'normalRange': 'Negative', 'unit': '', 'price': 300.0, 'category': 'Serology', 'printPage': 0},
      {'id': 39, 'testName': 'MP Test', 'normalRange': 'Negative', 'unit': '', 'price': 100.0, 'category': 'Serology', 'printPage': 0},
      {'id': 40, 'testName': 'Stool HP', 'normalRange': 'Negative', 'unit': '', 'price': 1000.0, 'category': 'Serology', 'printPage': 0},
      {'id': 41, 'testName': 'CRP Test', 'normalRange': 'Negative', 'unit': '', 'price': 500.0, 'category': 'Serology', 'printPage': 0},
      {'id': 42, 'testName': 'CPK Test', 'normalRange': 'M Less Then 171 F Less Then 145 Ch Less Then 2251', 'unit': 'u/l', 'price': 500.0, 'category': 'Hematology', 'printPage': 0},
      {'id': 43, 'testName': 'Seralogy For Dengue NS 1', 'normalRange': 'Negative', 'unit': '', 'price': 800.0, 'category': 'Serology', 'printPage': 0},
      {'id': 44, 'testName': 'Dengue IgM', 'normalRange': 'Negative', 'unit': '', 'price': 500.0, 'category': 'Serology', 'printPage': 0},
      {'id': 45, 'testName': 'Dengue IgG', 'normalRange': 'Negative', 'unit': '', 'price': 500.0, 'category': 'Serology', 'printPage': 0},
      {'id': 46, 'testName': 'Prothrombin Time', 'normalRange': '11.....15 Sec', 'unit': '', 'price': 300.0, 'category': 'General', 'printPage': 0},
      {'id': 47, 'testName': 'Prothrombin Control', 'normalRange': '', 'unit': '', 'price': 100.0, 'category': 'General', 'printPage': 0},
      {'id': 48, 'testName': 'APTT', 'normalRange': '', 'unit': '', 'price': 500.0, 'category': 'General', 'printPage': 0},
      {'id': 49, 'testName': 'APTT Control', 'normalRange': '', 'unit': '', 'price': 100.0, 'category': 'General', 'printPage': 0},
      {'id': 50, 'testName': 'INR', 'normalRange': '', 'unit': '', 'price': 400.0, 'category': 'General', 'printPage': 0},
      {'id': 51, 'testName': 'HDL', 'normalRange': '{M 35......55}{ F 45.....65}', 'unit': 'mg/dl', 'price': 300.0, 'category': 'Biochemistry', 'printPage': 0},
      {'id': 52, 'testName': 'LDL', 'normalRange': 'Less Than 150', 'unit': 'mg/dl', 'price': 300.0, 'category': 'Biochemistry', 'printPage': 0},
      {'id': 53, 'testName': 'LFTs', 'normalRange': '', 'unit': '', 'price': 600.0, 'category': 'Liver Function', 'printPage': 0},
      {'id': 54, 'testName': 'Lipeod Prifile', 'normalRange': '', 'unit': '', 'price': 1200.0, 'category': 'Biochemistry', 'printPage': 0},
      {'id': 55, 'testName': 'Blood For MP Test', 'normalRange': 'Negative', 'unit': '', 'price': 100.0, 'category': 'Serology', 'printPage': 0},
      {'id': 56, 'testName': 'Serum Calcium', 'normalRange': '8.1.......10.4', 'unit': 'mg/dl', 'price': 400.0, 'category': 'Biochemistry', 'printPage': 0},
      {'id': 57, 'testName': 'Liepod Profile', 'normalRange': '', 'unit': 'mg/dl', 'price': 1200.0, 'category': 'General', 'printPage': 0},
      {'id': 58, 'testName': 'Dengue NS1', 'normalRange': 'Negative', 'unit': '', 'price': 800.0, 'category': 'Serology', 'printPage': 0},
      {'id': 59, 'testName': 'Serum amylase', 'normalRange': '0-120', 'unit': 'u/l', 'price': 600.0, 'category': 'Biochemistry', 'printPage': 0},
      {'id': 60, 'testName': 'Sugar', 'normalRange': 'F 70-110 [R 80-180]', 'unit': 'mg/dl', 'price': 100.0, 'category': 'Biochemistry', 'printPage': 1},
      {'id': 61, 'testName': 'Medical', 'normalRange': '', 'unit': '', 'price': 3000.0, 'category': 'General', 'printPage': 0},
      {'id': 62, 'testName': 'Sugar U Acid RA Factor', 'normalRange': '', 'unit': '', 'price': 700.0, 'category': 'General', 'printPage': 0},
      {'id': 63, 'testName': 'RA Factor', 'normalRange': 'Negative', 'unit': '-', 'price': 300.0, 'category': 'Serology', 'printPage': 0},
      {'id': 64, 'testName': 'RA Uric', 'normalRange': '', 'unit': '', 'price': 600.0, 'category': 'General', 'printPage': 0},
      {'id': 65, 'testName': 'Haemoglobin', 'normalRange': '12.....16', 'unit': 'G/dl', 'price': 100.0, 'category': 'General', 'printPage': 0},
      {'id': 66, 'testName': 'Sugar Uric', 'normalRange': '', 'unit': '', 'price': 400.0, 'category': 'Biochemistry', 'printPage': 0},
      {'id': 67, 'testName': 'Sugar RA', 'normalRange': '', 'unit': '', 'price': 400.0, 'category': 'General', 'printPage': 0},
      {'id': 68, 'testName': 'Craet ALT HB', 'normalRange': '', 'unit': '', 'price': 700.0, 'category': 'General', 'printPage': 0},
      {'id': 69, 'testName': '25 Hydroxy Vitamin-D', 'normalRange': '30-100', 'unit': 'ng/ml', 'price': 2500.0, 'category': 'Endocrinology', 'printPage': 0},
      {'id': 70, 'testName': 'Semon  Analysis', 'normalRange': '', 'unit': '', 'price': 400.0, 'category': 'General', 'printPage': 0},
      {'id': 71, 'testName': 'B.T', 'normalRange': '1-9', 'unit': 'Min', 'price': 200.0, 'category': 'General', 'printPage': 0},
      {'id': 72, 'testName': 'C.T', 'normalRange': '5-11', 'unit': 'Min', 'price': 200.0, 'category': 'General', 'printPage': 0},
      {'id': 73, 'testName': 'ALT', 'normalRange': '0-43', 'unit': 'u/l', 'price': 300.0, 'category': 'Biochemistry', 'printPage': 0},
      {'id': 74, 'testName': 'Typhodot Test', 'normalRange': 'Negative', 'unit': '', 'price': 600.0, 'category': 'Serology', 'printPage': 0},
      {'id': 75, 'testName': 'Trop T Test', 'normalRange': 'Negative', 'unit': '', 'price': 2000.0, 'category': 'Serology', 'printPage': 0},
      {'id': 76, 'testName': 'Cross Match', 'normalRange': '', 'unit': '', 'price': 300.0, 'category': 'Serology', 'printPage': 0},
      {'id': 77, 'testName': 'Serum Lipase', 'normalRange': '', 'unit': 'u/l', 'price': 1500.0, 'category': 'Biochemistry', 'printPage': 0},
      {'id': 78, 'testName': 'PT', 'normalRange': '', 'unit': '', 'price': 500.0, 'category': 'General', 'printPage': 0},
      {'id': 79, 'testName': 'DLC', 'normalRange': '', 'unit': '', 'price': 200.0, 'category': 'Hematology', 'printPage': 0},
      {'id': 80, 'testName': 'Pregnancy Test', 'normalRange': '', 'unit': '', 'price': 200.0, 'category': 'General', 'printPage': 0},
      {'id': 81, 'testName': 'Serum Electrolytes', 'normalRange': '', 'unit': '', 'price': 1200.0, 'category': 'Biochemistry', 'printPage': 0},
    ];

    for (var test in defaultTests) {
      await db.insert('tests', test);
    }

    // Seed default parameters
    final defaultParams = [
      {'id': 1, 'parentTestId': 1, 'paramName': 'Hemoglobin (Hb)', 'normalRange': '12-17 g/dL', 'unit': 'g/dL', 'sortOrder': 1, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 2, 'parentTestId': 1, 'paramName': 'Total Leukocyte Count (TLC)', 'normalRange': '4000-11000', 'unit': '/cumm', 'sortOrder': 2, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 3, 'parentTestId': 1, 'paramName': 'Neutrophils', 'normalRange': '40-70%', 'unit': '%', 'sortOrder': 3, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 4, 'parentTestId': 1, 'paramName': 'Lymphocytes', 'normalRange': '20-40%', 'unit': '%', 'sortOrder': 4, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 5, 'parentTestId': 1, 'paramName': 'Monocytes', 'normalRange': '2-8%', 'unit': '%', 'sortOrder': 5, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 6, 'parentTestId': 1, 'paramName': 'Eosinophils', 'normalRange': '1-6%', 'unit': '%', 'sortOrder': 6, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 7, 'parentTestId': 1, 'paramName': 'Red Blood Cells (RBC)', 'normalRange': '4.5-5.5', 'unit': 'M/uL', 'sortOrder': 7, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 8, 'parentTestId': 1, 'paramName': 'Platelets', 'normalRange': '150000-400000', 'unit': '/cumm', 'sortOrder': 8, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 9, 'parentTestId': 1, 'paramName': 'MPV', 'normalRange': '7.5-11.5', 'unit': 'fL', 'sortOrder': 9, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 10, 'parentTestId': 1, 'paramName': 'MCH', 'normalRange': '27-33', 'unit': 'pg', 'sortOrder': 10, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 11, 'parentTestId': 1, 'paramName': 'MCHC', 'normalRange': '32-36', 'unit': 'g/dL', 'sortOrder': 11, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 12, 'parentTestId': 1, 'paramName': 'Hematocrit (HCT)', 'normalRange': '36-54%', 'unit': '%', 'sortOrder': 12, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 13, 'parentTestId': 1, 'paramName': 'MCV', 'normalRange': '80-100', 'unit': 'fL', 'sortOrder': 13, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 14, 'parentTestId': 53, 'paramName': 'Serum Bilrobin', 'normalRange': '0.6-1.2', 'unit': 'mg/dl', 'sortOrder': 1, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 15, 'parentTestId': 53, 'paramName': 'SGPT', 'normalRange': '0-43', 'unit': 'U/L', 'sortOrder': 2, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 16, 'parentTestId': 53, 'paramName': 'ALK', 'normalRange': 'M: 100-275 | F: 100-275 | C: 100-390', 'unit': 'u/l', 'sortOrder': 3, 'rangeType': 'multi', 'normalRangeMale': '100-275', 'normalRangeFemale': '100-275', 'normalRangeChild': '100-390'},
      {'id': 17, 'parentTestId': 57, 'paramName': 'Serum Cholestrol', 'normalRange': '100.....200', 'unit': 'mg/dl', 'sortOrder': 1, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 18, 'parentTestId': 57, 'paramName': 'Triglycerides', 'normalRange': '70....150', 'unit': 'mg/dl', 'sortOrder': 2, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 19, 'parentTestId': 57, 'paramName': 'HDL', 'normalRange': 'M 35.....55 [F 45....65]', 'unit': '', 'sortOrder': 3, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 20, 'parentTestId': 57, 'paramName': 'HDL', 'normalRange': 'Less Than 150', 'unit': 'mg/dl', 'sortOrder': 4, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 21, 'parentTestId': 61, 'paramName': 'HBS', 'normalRange': 'Negative', 'unit': '', 'sortOrder': 1, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 22, 'parentTestId': 61, 'paramName': 'HCV', 'normalRange': 'Negative', 'unit': '', 'sortOrder': 2, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 23, 'parentTestId': 61, 'paramName': 'HIV', 'normalRange': 'Negative', 'unit': '', 'sortOrder': 3, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 24, 'parentTestId': 61, 'paramName': 'VDRL', 'normalRange': 'Negative', 'unit': '', 'sortOrder': 4, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 25, 'parentTestId': 61, 'paramName': 'TPHA', 'normalRange': 'Negative', 'unit': '', 'sortOrder': 5, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 26, 'parentTestId': 61, 'paramName': 'Mycodat', 'normalRange': 'Negative', 'unit': '', 'sortOrder': 6, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 27, 'parentTestId': 62, 'paramName': 'Serum Uric Acid', 'normalRange': 'M: 3.4-7.0 | F: 2.4-5.7', 'unit': 'mg/dl', 'sortOrder': 1, 'rangeType': 'multi', 'normalRangeMale': '3.4-7.0', 'normalRangeFemale': '2.4-5.7', 'normalRangeChild': ''},
      {'id': 28, 'parentTestId': 62, 'paramName': 'Sugar', 'normalRange': 'F70-110[R 80-180]', 'unit': 'md/dl', 'sortOrder': 2, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 29, 'parentTestId': 62, 'paramName': 'RA Factor', 'normalRange': 'Negative', 'unit': '', 'sortOrder': 3, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 30, 'parentTestId': 28, 'paramName': 'ALK', 'normalRange': 'M: 100-275 | F: 100-275 | C: 100-390', 'unit': 'u/l', 'sortOrder': 1, 'rangeType': 'multi', 'normalRangeMale': '100-275', 'normalRangeFemale': '100-275', 'normalRangeChild': '100-390'},
      {'id': 31, 'parentTestId': 66, 'paramName': 'Sugar', 'normalRange': 'F 70-110[R 80-180]', 'unit': 'mg/dl', 'sortOrder': 1, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 32, 'parentTestId': 66, 'paramName': 'Uric Acid', 'normalRange': 'M: 3.4-7.0 | F: 2.4-5.7', 'unit': 'mg/dl', 'sortOrder': 2, 'rangeType': 'multi', 'normalRangeMale': '3.4-7.0', 'normalRangeFemale': '2.4-5.7', 'normalRangeChild': ''},
      {'id': 33, 'parentTestId': 67, 'paramName': 'Sugar', 'normalRange': 'F 70-110[R80-180]', 'unit': 'mg/dl', 'sortOrder': 1, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 34, 'parentTestId': 67, 'paramName': 'RA Factor', 'normalRange': 'Negative', 'unit': '', 'sortOrder': 2, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 35, 'parentTestId': 68, 'paramName': 'Serum Creatinine', 'normalRange': '06.....1.2', 'unit': 'mg/dl', 'sortOrder': 1, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 36, 'parentTestId': 68, 'paramName': 'SGPT{ ALT }', 'normalRange': '0......43', 'unit': 'u/l', 'sortOrder': 2, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 37, 'parentTestId': 68, 'paramName': 'Hb', 'normalRange': '12....16', 'unit': 'Gm %', 'sortOrder': 3, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 38, 'parentTestId': 64, 'paramName': 'RA FACTOR', 'normalRange': 'Negative', 'unit': '', 'sortOrder': 1, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 39, 'parentTestId': 64, 'paramName': 'URIC ACID', 'normalRange': 'M: 3.4-7.0 | F: 2.4-5.7', 'unit': 'mg/dl', 'sortOrder': 2, 'rangeType': 'multi', 'normalRangeMale': '3.4-7.0', 'normalRangeFemale': '2.4-5.7', 'normalRangeChild': ''},
      {'id': 40, 'parentTestId': 54, 'paramName': 'Serum Cholestrol', 'normalRange': '100-200', 'unit': 'mg/dl', 'sortOrder': 1, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 41, 'parentTestId': 54, 'paramName': 'Triglycerides', 'normalRange': '70-150', 'unit': 'mg/dl', 'sortOrder': 2, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 42, 'parentTestId': 54, 'paramName': 'HDL', 'normalRange': 'M: 35-55 | F: 45-65', 'unit': 'mg/dl', 'sortOrder': 3, 'rangeType': 'multi', 'normalRangeMale': '35-55', 'normalRangeFemale': '45-65', 'normalRangeChild': ''},
      {'id': 43, 'parentTestId': 54, 'paramName': 'LDL', 'normalRange': 'Less Than 150', 'unit': 'mg/dl', 'sortOrder': 4, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 44, 'parentTestId': 36, 'paramName': 'HBS', 'normalRange': 'Negative', 'unit': '', 'sortOrder': 1, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 45, 'parentTestId': 36, 'paramName': 'HCV', 'normalRange': 'Negative', 'unit': '', 'sortOrder': 2, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 46, 'parentTestId': 36, 'paramName': 'HIV', 'normalRange': 'Negative', 'unit': '', 'sortOrder': 3, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 47, 'parentTestId': 30, 'paramName': 'HBS', 'normalRange': 'Negative', 'unit': '', 'sortOrder': 1, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 48, 'parentTestId': 30, 'paramName': 'HCV', 'normalRange': 'Negative', 'unit': '', 'sortOrder': 2, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 49, 'parentTestId': 70, 'paramName': 'Volume;', 'normalRange': '', 'unit': 'ml', 'sortOrder': 1, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 50, 'parentTestId': 70, 'paramName': 'colour', 'normalRange': '', 'unit': '', 'sortOrder': 2, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 51, 'parentTestId': 70, 'paramName': 'Viscosity', 'normalRange': '', 'unit': '', 'sortOrder': 3, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 52, 'parentTestId': 70, 'paramName': 'Microscopic Examination', 'normalRange': '', 'unit': '', 'sortOrder': 4, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 53, 'parentTestId': 70, 'paramName': 'Morphology;', 'normalRange': '', 'unit': '', 'sortOrder': 5, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 54, 'parentTestId': 70, 'paramName': 'Normal', 'normalRange': '', 'unit': '%', 'sortOrder': 6, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 55, 'parentTestId': 70, 'paramName': 'Abnormal', 'normalRange': '', 'unit': '%', 'sortOrder': 7, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 56, 'parentTestId': 70, 'paramName': 'Motillity;', 'normalRange': '', 'unit': '', 'sortOrder': 8, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 57, 'parentTestId': 70, 'paramName': 'Actively;', 'normalRange': '', 'unit': '%', 'sortOrder': 9, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 58, 'parentTestId': 70, 'paramName': 'Sluggish', 'normalRange': '', 'unit': '%', 'sortOrder': 10, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 59, 'parentTestId': 70, 'paramName': 'Dead', 'normalRange': '', 'unit': '%', 'sortOrder': 11, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 60, 'parentTestId': 70, 'paramName': 'Sperm Count', 'normalRange': '', 'unit': 'Million/ ml', 'sortOrder': 12, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 61, 'parentTestId': 70, 'paramName': 'Pus Cell', 'normalRange': '', 'unit': 'Hpf', 'sortOrder': 13, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 62, 'parentTestId': 74, 'paramName': 'Typhodot IgG', 'normalRange': 'Negative', 'unit': '', 'sortOrder': 1, 'rangeType': 'negative', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 63, 'parentTestId': 74, 'paramName': 'Typhodot IgM', 'normalRange': 'Negative', 'unit': '', 'sortOrder': 2, 'rangeType': 'negative', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 64, 'parentTestId': 77, 'paramName': 'Serum Lipase', 'normalRange': 'M: 78 | F: 78 | C: 46', 'unit': 'u/l', 'sortOrder': 1, 'rangeType': 'multi', 'normalRangeMale': '78', 'normalRangeFemale': '78', 'normalRangeChild': '46'},
      {'id': 65, 'parentTestId': 78, 'paramName': 'Prothrombin Control', 'normalRange': '', 'unit': '', 'sortOrder': 1, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 66, 'parentTestId': 78, 'paramName': 'Prothrombin Time', 'normalRange': '11.....15 Sec', 'unit': '', 'sortOrder': 2, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 67, 'parentTestId': 48, 'paramName': 'APTT', 'normalRange': '33......48 Sec', 'unit': '', 'sortOrder': 1, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 68, 'parentTestId': 48, 'paramName': 'APTT Control', 'normalRange': '', 'unit': '', 'sortOrder': 2, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 69, 'parentTestId': 79, 'paramName': 'Neutrophils', 'normalRange': '40---75', 'unit': '%', 'sortOrder': 1, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 70, 'parentTestId': 79, 'paramName': 'Lymphocytes', 'normalRange': '20-50', 'unit': '%', 'sortOrder': 2, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 71, 'parentTestId': 79, 'paramName': 'Monocytes', 'normalRange': '1-15', 'unit': '%', 'sortOrder': 3, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 72, 'parentTestId': 79, 'paramName': 'Eosinophils', 'normalRange': '1-6', 'unit': '%', 'sortOrder': 4, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 73, 'parentTestId': 81, 'paramName': 'K+{ Potassium}', 'normalRange': '3.8  -  5.5', 'unit': 'mmo l/L', 'sortOrder': 1, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 74, 'parentTestId': 81, 'paramName': 'Na+ { Sodium}', 'normalRange': '136  -  145', 'unit': 'mmo l/L', 'sortOrder': 2, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 75, 'parentTestId': 81, 'paramName': 'CL{ Chloride}', 'normalRange': '95.0-  108.0', 'unit': 'mmo l/L', 'sortOrder': 3, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 76, 'parentTestId': 81, 'paramName': 'iCa', 'normalRange': '1.05-  1.35', 'unit': 'mmo l/L', 'sortOrder': 4, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 77, 'parentTestId': 81, 'paramName': 'nCa', 'normalRange': '1.05-  1.35', 'unit': 'mmol/L', 'sortOrder': 5, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 78, 'parentTestId': 81, 'paramName': 'TCa', 'normalRange': '2.10-  2.70', 'unit': 'mmol/L', 'sortOrder': 6, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
      {'id': 79, 'parentTestId': 81, 'paramName': 'Ph', 'normalRange': '7.200----8.000', 'unit': '', 'sortOrder': 7, 'rangeType': 'normal', 'normalRangeMale': '', 'normalRangeFemale': '', 'normalRangeChild': ''},
    ];

    for (var param in defaultParams) {
      await db.insert('test_parameters', param);
    }
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE patients ADD COLUMN nic TEXT DEFAULT ""');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS test_parameters(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          parentTestId INTEGER NOT NULL,
          paramName TEXT NOT NULL,
          normalRange TEXT DEFAULT '',
          unit TEXT DEFAULT '',
          sortOrder INTEGER DEFAULT 0,
          FOREIGN KEY(parentTestId) REFERENCES tests(id) ON DELETE CASCADE
        )
      ''');
      await db.execute('ALTER TABLE lab_settings ADD COLUMN headerImagePath TEXT DEFAULT ""');
      await db.execute('ALTER TABLE lab_settings ADD COLUMN watermarkText TEXT DEFAULT "Bashir Clinical Laboratory"');
      await db.execute('ALTER TABLE lab_settings ADD COLUMN doctorName TEXT DEFAULT ""');
      await db.execute('ALTER TABLE lab_settings ADD COLUMN ceoName TEXT DEFAULT ""');
      await db.execute('ALTER TABLE lab_settings ADD COLUMN inchargeName TEXT DEFAULT ""');
      await db.execute('ALTER TABLE lab_settings ADD COLUMN printHeaderFooter INTEGER DEFAULT 1');

      final cbcTests = await db.query('tests', where: 'testName LIKE ?', whereArgs: ['%CBC%']);
      if (cbcTests.isNotEmpty) {
        final cbcId = cbcTests.first['id'] as int;
        final existing = await db.query('test_parameters', where: 'parentTestId = ?', whereArgs: [cbcId]);
        if (existing.isEmpty) {
          final cbcParams = [
            {'parentTestId': cbcId, 'paramName': 'Hemoglobin (Hb)', 'normalRange': '12-17 g/dL', 'unit': 'g/dL', 'sortOrder': 1},
            {'parentTestId': cbcId, 'paramName': 'Total Leukocyte Count (TLC)', 'normalRange': '4000-11000', 'unit': '/cumm', 'sortOrder': 2},
            {'parentTestId': cbcId, 'paramName': 'Neutrophils', 'normalRange': '40-70%', 'unit': '%', 'sortOrder': 3},
            {'parentTestId': cbcId, 'paramName': 'Lymphocytes', 'normalRange': '20-40%', 'unit': '%', 'sortOrder': 4},
            {'parentTestId': cbcId, 'paramName': 'Monocytes', 'normalRange': '2-8%', 'unit': '%', 'sortOrder': 5},
            {'parentTestId': cbcId, 'paramName': 'Eosinophils', 'normalRange': '1-6%', 'unit': '%', 'sortOrder': 6},
            {'parentTestId': cbcId, 'paramName': 'Red Blood Cells (RBC)', 'normalRange': '4.5-5.5', 'unit': 'M/uL', 'sortOrder': 7},
            {'parentTestId': cbcId, 'paramName': 'Platelets', 'normalRange': '150000-400000', 'unit': '/cumm', 'sortOrder': 8},
            {'parentTestId': cbcId, 'paramName': 'MPV', 'normalRange': '7.5-11.5', 'unit': 'fL', 'sortOrder': 9},
            {'parentTestId': cbcId, 'paramName': 'MCH', 'normalRange': '27-33', 'unit': 'pg', 'sortOrder': 10},
            {'parentTestId': cbcId, 'paramName': 'MCHC', 'normalRange': '32-36', 'unit': 'g/dL', 'sortOrder': 11},
            {'parentTestId': cbcId, 'paramName': 'Hematocrit (HCT)', 'normalRange': '36-54%', 'unit': '%', 'sortOrder': 12},
            {'parentTestId': cbcId, 'paramName': 'MCV', 'normalRange': '80-100', 'unit': 'fL', 'sortOrder': 13},
          ];
          for (var param in cbcParams) {
            await db.insert('test_parameters', param);
          }
        }
      }
    }

    if (oldVersion < 3) {
      // Add verification columns to reports
      try { await db.execute('ALTER TABLE reports ADD COLUMN verifiedBy TEXT DEFAULT ""'); } catch (_) {}
      try { await db.execute('ALTER TABLE reports ADD COLUMN verifiedAt TEXT DEFAULT ""'); } catch (_) {}

      // Add category to test_results
      try { await db.execute('ALTER TABLE test_results ADD COLUMN category TEXT DEFAULT ""'); } catch (_) {}

      // Add testId to invoice_items
      try { await db.execute('ALTER TABLE invoice_items ADD COLUMN testId INTEGER'); } catch (_) {}

      // Add labNameUrdu to lab_settings
      try { await db.execute('ALTER TABLE lab_settings ADD COLUMN labNameUrdu TEXT DEFAULT "Ø¹Ù…Ø± Ù…ÛŒÚˆÛŒÚ©Ù„ Ù„ÛŒØ¨Ø§Ø±Ù¹Ø±ÛŒ"'); } catch (_) {}

      // Create employees table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS employees(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          phone TEXT DEFAULT '',
          type TEXT DEFAULT 'employee',
          department TEXT DEFAULT '',
          joinDate TEXT NOT NULL,
          endDate TEXT DEFAULT '',
          status TEXT DEFAULT 'active'
        )
      ''');

      // Create attendance table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS attendance(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          employeeId INTEGER NOT NULL,
          date TEXT NOT NULL,
          checkIn TEXT DEFAULT '',
          checkOut TEXT DEFAULT '',
          status TEXT DEFAULT 'present',
          FOREIGN KEY(employeeId) REFERENCES employees(id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 4) {
      // Add range type fields to test_parameters
      try { await db.execute('ALTER TABLE test_parameters ADD COLUMN rangeType TEXT DEFAULT "normal"'); } catch (_) {}
      try { await db.execute('ALTER TABLE test_parameters ADD COLUMN normalRangeMale TEXT DEFAULT ""'); } catch (_) {}
      try { await db.execute('ALTER TABLE test_parameters ADD COLUMN normalRangeFemale TEXT DEFAULT ""'); } catch (_) {}
      try { await db.execute('ALTER TABLE test_parameters ADD COLUMN normalRangeChild TEXT DEFAULT ""'); } catch (_) {}

      // Add printPage to tests and test_results
      try { await db.execute('ALTER TABLE tests ADD COLUMN printPage INTEGER DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE test_results ADD COLUMN printPage INTEGER DEFAULT 0'); } catch (_) {}

      // Add education fields to lab_settings
      try { await db.execute('ALTER TABLE lab_settings ADD COLUMN ceoEducation TEXT DEFAULT ""'); } catch (_) {}
      try { await db.execute('ALTER TABLE lab_settings ADD COLUMN inchargeEducation TEXT DEFAULT ""'); } catch (_) {}
    }

    if (oldVersion < 5) {
      // Add registrationNo to lab_settings
      try { await db.execute('ALTER TABLE lab_settings ADD COLUMN registrationNo TEXT DEFAULT ""'); } catch (_) {}
    }

    if (oldVersion < 6) {
      // Create footer_signatures table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS footer_signatures(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            designation TEXT DEFAULT '',
            education TEXT DEFAULT '',
            sortOrder INTEGER DEFAULT 0
          )
        ''');
        
        // Seed default signatures
        final defaultSignatures = [
          {'name': 'D Khalid Latif', 'designation': '', 'education': 'MBBS(KMC)\nMCPS\nFCPS', 'sortOrder': 1},
          {'name': 'M Razib Khan', 'designation': '', 'education': 'DMLT (PATHOLOGY )\nBSc (Pathology)', 'sortOrder': 2},
          {'name': 'Sher Rehman', 'designation': '', 'education': 'DMLT (PATHOLOGY )\nMSc (Microbiology)', 'sortOrder': 3},
          {'name': 'Abdul Haleem', 'designation': '', 'education': 'DMLT (PATHOLOGY)', 'sortOrder': 4},
        ];
        for (var sig in defaultSignatures) {
          await db.insert('footer_signatures', sig);
        }
      } catch (_) {}

      // Add specimen to reports table
      try {
        await db.execute('ALTER TABLE reports ADD COLUMN specimen TEXT DEFAULT ""');
      } catch (_) {}

      // Auto-update old lab settings to MUHAMMAD MEDICAL LABORATORY
      try {
        await db.update('lab_settings', {
          'labName': 'MUHAMMAD MEDICAL LABORATORY',
          'labNameUrdu': 'محمد میڈیکل لیبارٹری',
          'watermarkText': 'MUHAMMAD MEDICAL LABORATORY',
        }, where: 'id = ?', whereArgs: [1]);
      } catch (_) {}
    }
  }

  // ===== USER OPERATIONS =====
  static Future<int> insertUser(Map<String, dynamic> user) async {
    final db = await database;
    return await db.insert('users', user);
  }

  static Future<Map<String, dynamic>?> getUser(String username, String password) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
    );
    return result.isNotEmpty ? result.first : null;
  }

  static Future<Map<String, dynamic>?> getUserById(int id) async {
    final db = await database;
    final result = await db.query('users', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }

  static Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    final db = await database;
    final result = await db.query('users', where: 'username = ?', whereArgs: [username]);
    return result.isNotEmpty ? result.first : null;
  }

  static Future<bool> usernameExists(String username) async {
    final db = await database;
    final result = await db.query('users', where: 'username = ?', whereArgs: [username]);
    return result.isNotEmpty;
  }

  static Future<int> getUserCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM users');
    return result.first['count'] as int;
  }

  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await database;
    return await db.query('users', orderBy: 'id DESC');
  }

  static Future<int> updateUser(int id, Map<String, dynamic> user) async {
    final db = await database;
    return await db.update('users', user, where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> deleteUser(int id) async {
    final db = await database;
    return await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  // ===== PATIENT OPERATIONS =====
  static Future<int> insertPatient(Map<String, dynamic> patient) async {
    final db = await database;
    return await db.insert('patients', patient);
  }

  static Future<List<Map<String, dynamic>>> getAllPatients() async {
    final db = await database;
    return await db.query('patients', orderBy: 'id DESC');
  }

  static Future<Map<String, dynamic>?> getPatientById(int id) async {
    final db = await database;
    final result = await db.query('patients', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }

  static Future<List<Map<String, dynamic>>> searchPatients(String query) async {
    final db = await database;
    return await db.query(
      'patients',
      where: 'name LIKE ? OR phone LIKE ? OR nic LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'id DESC',
    );
  }

  static Future<int> updatePatient(int id, Map<String, dynamic> patient) async {
    final db = await database;
    return await db.update('patients', patient, where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> deletePatient(int id) async {
    final db = await database;
    return await db.delete('patients', where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> getPatientCount() async {
    final db = await database;
    final r = await db.rawQuery('SELECT COUNT(*) as count FROM patients');
    return r.first['count'] as int;
  }

  // ===== TEST OPERATIONS =====
  static Future<int> insertTest(Map<String, dynamic> test) async {
    final db = await database;
    return await db.insert('tests', test);
  }

  static Future<List<Map<String, dynamic>>> getAllTests() async {
    final db = await database;
    return await db.query('tests', orderBy: 'category, testName');
  }

  static Future<Map<String, dynamic>?> getTestById(int id) async {
    final db = await database;
    final result = await db.query('tests', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }

  static Future<int> updateTest(int id, Map<String, dynamic> test) async {
    final db = await database;
    return await db.update('tests', test, where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> deleteTest(int id) async {
    final db = await database;
    await db.delete('test_parameters', where: 'parentTestId = ?', whereArgs: [id]);
    return await db.delete('tests', where: 'id = ?', whereArgs: [id]);
  }

  // ===== TEST PARAMETER OPERATIONS =====
  static Future<int> insertTestParameter(Map<String, dynamic> param) async {
    final db = await database;
    return await db.insert('test_parameters', param);
  }

  static Future<List<Map<String, dynamic>>> getTestParameters(int parentTestId) async {
    final db = await database;
    return await db.query('test_parameters', where: 'parentTestId = ?', whereArgs: [parentTestId], orderBy: 'sortOrder');
  }

  static Future<int> getTestParameterCount(int parentTestId) async {
    final db = await database;
    final r = await db.rawQuery('SELECT COUNT(*) as count FROM test_parameters WHERE parentTestId = ?', [parentTestId]);
    return r.first['count'] as int;
  }

  static Future<int> updateTestParameter(int id, Map<String, dynamic> param) async {
    final db = await database;
    return await db.update('test_parameters', param, where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> deleteTestParameter(int id) async {
    final db = await database;
    return await db.delete('test_parameters', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteAllTestParameters(int parentTestId) async {
    final db = await database;
    await db.delete('test_parameters', where: 'parentTestId = ?', whereArgs: [parentTestId]);
  }

  // ===== REPORT OPERATIONS =====
  static Future<int> insertReport(Map<String, dynamic> report) async {
    final db = await database;
    return await db.insert('reports', report);
  }

  static Future<List<Map<String, dynamic>>> getAllReports() async {
    final db = await database;
    return await db.query('reports', orderBy: 'id DESC');
  }

  static Future<Map<String, dynamic>?> getReportById(int id) async {
    final db = await database;
    final result = await db.query('reports', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }

  static Future<List<Map<String, dynamic>>> getReportsByStatus(String status) async {
    final db = await database;
    return await db.query('reports', where: 'status = ?', whereArgs: [status], orderBy: 'id DESC');
  }

  static Future<int> updateReport(int id, Map<String, dynamic> report) async {
    final db = await database;
    return await db.update('reports', report, where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> deleteReport(int id) async {
    final db = await database;
    await db.delete('test_results', where: 'reportId = ?', whereArgs: [id]);
    return await db.delete('reports', where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> getReportCount() async {
    final db = await database;
    final r = await db.rawQuery('SELECT COUNT(*) as count FROM reports');
    return r.first['count'] as int;
  }

  static Future<int> getTodayReportCount() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final r = await db.rawQuery("SELECT COUNT(*) as count FROM reports WHERE date LIKE '$today%'");
    return r.first['count'] as int;
  }

  static Future<int> getPendingReportCount() async {
    final db = await database;
    final r = await db.rawQuery("SELECT COUNT(*) as count FROM reports WHERE status = 'pending'");
    return r.first['count'] as int;
  }

  static Future<void> verifyReport(int id, String verifierName) async {
    final db = await database;
    await db.update('reports', {
      'verifiedBy': verifierName,
      'verifiedAt': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<Map<String, dynamic>>> getVerificationStats() async {
    final db = await database;
    return await db.rawQuery(
      "SELECT verifiedBy, COUNT(*) as count FROM reports WHERE verifiedBy != '' AND verifiedBy IS NOT NULL GROUP BY verifiedBy ORDER BY count DESC"
    );
  }

  static Future<int> getVerifiedReportCount() async {
    final db = await database;
    final r = await db.rawQuery("SELECT COUNT(*) as count FROM reports WHERE verifiedBy != '' AND verifiedBy IS NOT NULL");
    return r.first['count'] as int;
  }

  static Future<Map<String, dynamic>?> getReportByInvoiceId(int invoiceId) async {
    final db = await database;
    final invoice = await db.query('invoices', where: 'id = ?', whereArgs: [invoiceId]);
    if (invoice.isNotEmpty && invoice.first['reportId'] != null) {
      final reportId = invoice.first['reportId'] as int;
      return await getReportById(reportId);
    }
    return null;
  }

  // ===== TEST RESULT OPERATIONS =====
  static Future<int> insertTestResult(Map<String, dynamic> result) async {
    final db = await database;
    return await db.insert('test_results', result);
  }

  static Future<List<Map<String, dynamic>>> getTestResults(int reportId) async {
    final db = await database;
    return await db.query('test_results', where: 'reportId = ?', whereArgs: [reportId]);
  }

  static Future<int> updateTestResult(int id, Map<String, dynamic> result) async {
    final db = await database;
    return await db.update('test_results', result, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteTestResults(int reportId) async {
    final db = await database;
    await db.delete('test_results', where: 'reportId = ?', whereArgs: [reportId]);
  }

  // ===== INVOICE OPERATIONS =====
  static Future<int> insertInvoice(Map<String, dynamic> invoice) async {
    final db = await database;
    return await db.insert('invoices', invoice);
  }

  static Future<List<Map<String, dynamic>>> getAllInvoices() async {
    final db = await database;
    return await db.query('invoices', orderBy: 'id DESC');
  }

  static Future<Map<String, dynamic>?> getInvoiceById(int id) async {
    final db = await database;
    final result = await db.query('invoices', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }

  static Future<int> updateInvoice(int id, Map<String, dynamic> invoice) async {
    final db = await database;
    return await db.update('invoices', invoice, where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> deleteInvoice(int id) async {
    final db = await database;
    await db.delete('invoice_items', where: 'invoiceId = ?', whereArgs: [id]);
    return await db.delete('invoices', where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> insertInvoiceItem(Map<String, dynamic> item) async {
    final db = await database;
    return await db.insert('invoice_items', item);
  }

  static Future<List<Map<String, dynamic>>> getInvoiceItems(int invoiceId) async {
    final db = await database;
    return await db.query('invoice_items', where: 'invoiceId = ?', whereArgs: [invoiceId]);
  }

  static Future<void> deleteInvoiceItems(int invoiceId) async {
    final db = await database;
    await db.delete('invoice_items', where: 'invoiceId = ?', whereArgs: [invoiceId]);
  }

  static Future<double> getTodayRevenue() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final r = await db.rawQuery("SELECT COALESCE(SUM(paidAmount),0) as total FROM invoices WHERE date LIKE '$today%'");
    return (r.first['total'] as num).toDouble();
  }

  static Future<double> getMonthRevenue() async {
    final db = await database;
    final month = DateTime.now().toIso8601String().substring(0, 7);
    final r = await db.rawQuery("SELECT COALESCE(SUM(paidAmount),0) as total FROM invoices WHERE date LIKE '$month%'");
    return (r.first['total'] as num).toDouble();
  }

  static Future<double> getTotalRevenue() async {
    final db = await database;
    final r = await db.rawQuery('SELECT COALESCE(SUM(paidAmount),0) as total FROM invoices');
    return (r.first['total'] as num).toDouble();
  }

  /// Returns revenue grouped by date for the last [days] days (newest first)
  static Future<List<Map<String, dynamic>>> getRevenueByDate(int days) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT substr(date, 1, 10) as day, COALESCE(SUM(paidAmount), 0) as total
      FROM invoices
      WHERE date >= date('now', '-${days - 1} days')
      GROUP BY day
      ORDER BY day ASC
    ''');
    return result;
  }

  /// Returns top [limit] tests by number of times they appear in invoice_items
  static Future<List<Map<String, dynamic>>> getTopTests(int limit) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT testName, COUNT(*) as count, SUM(price) as revenue
      FROM invoice_items
      WHERE testName != ''
      GROUP BY testName
      ORDER BY count DESC
      LIMIT $limit
    ''');
  }

  /// Find which invoice is linked to a given reportId
  static Future<Map<String, dynamic>?> getInvoiceByReportId(int reportId) async {
    final db = await database;
    final result = await db.query('invoices', where: 'reportId = ?', whereArgs: [reportId]);
    return result.isNotEmpty ? result.first : null;
  }

  /// Get all reports for a specific patient
  static Future<List<Map<String, dynamic>>> getReportsByPatientId(int patientId) async {
    final db = await database;
    return await db.query('reports', where: 'patientId = ?', whereArgs: [patientId], orderBy: 'id DESC');
  }

  /// Get up to [limit] previous completed reports for a patient, excluding the given report
  static Future<List<Map<String, dynamic>>> getPreviousReports(int patientId, int currentReportId, {int limit = 3}) async {
    final db = await database;
    return await db.query(
      'reports',
      where: "patientId = ? AND id != ? AND status = 'completed'",
      whereArgs: [patientId, currentReportId],
      orderBy: 'id DESC',
      limit: limit,
    );
  }

  /// Get all invoices for a specific patient
  static Future<List<Map<String, dynamic>>> getInvoicesByPatientId(int patientId) async {
    final db = await database;
    return await db.query('invoices', where: 'patientId = ?', whereArgs: [patientId], orderBy: 'id DESC');
  }

  // ===== LAB SETTINGS =====
  static Future<Map<String, dynamic>?> getLabSettings() async {
    final db = await database;
    final result = await db.query('lab_settings');
    return result.isNotEmpty ? result.first : null;
  }

  static Future<int> updateLabSettings(Map<String, dynamic> settings) async {
    final db = await database;
    return await db.update('lab_settings', settings, where: 'id = ?', whereArgs: [1]);
  }

  // ===== EMPLOYEE OPERATIONS =====
  static Future<int> insertEmployee(Map<String, dynamic> emp) async {
    final db = await database;
    return await db.insert('employees', emp);
  }

  static Future<List<Map<String, dynamic>>> getAllEmployees() async {
    final db = await database;
    return await db.query('employees', orderBy: 'name');
  }

  static Future<List<Map<String, dynamic>>> getEmployeesByType(String type) async {
    final db = await database;
    return await db.query('employees', where: 'type = ?', whereArgs: [type], orderBy: 'name');
  }

  static Future<int> updateEmployee(int id, Map<String, dynamic> emp) async {
    final db = await database;
    return await db.update('employees', emp, where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> deleteEmployee(int id) async {
    final db = await database;
    await db.delete('attendance', where: 'employeeId = ?', whereArgs: [id]);
    return await db.delete('employees', where: 'id = ?', whereArgs: [id]);
  }

  // ===== ATTENDANCE OPERATIONS =====
  static Future<int> insertAttendance(Map<String, dynamic> att) async {
    final db = await database;
    return await db.insert('attendance', att);
  }

  static Future<List<Map<String, dynamic>>> getAttendanceByDate(String date) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT a.*, e.name as employeeName, e.type as employeeType, e.department
      FROM attendance a
      JOIN employees e ON a.employeeId = e.id
      WHERE a.date = ?
      ORDER BY e.name
    ''', [date]);
  }

  static Future<List<Map<String, dynamic>>> getAttendanceByEmployee(int employeeId) async {
    final db = await database;
    return await db.query('attendance', where: 'employeeId = ?', whereArgs: [employeeId], orderBy: 'date DESC');
  }

  static Future<Map<String, dynamic>?> getAttendanceRecord(int employeeId, String date) async {
    final db = await database;
    final result = await db.query('attendance', where: 'employeeId = ? AND date = ?', whereArgs: [employeeId, date]);
    return result.isNotEmpty ? result.first : null;
  }

  static Future<int> updateAttendance(int id, Map<String, dynamic> att) async {
    final db = await database;
    return await db.update('attendance', att, where: 'id = ?', whereArgs: [id]);
  }

  static Future<Map<String, dynamic>> getEmployeeAttendanceSummary(int employeeId) async {
    final db = await database;
    final present = await db.rawQuery("SELECT COUNT(*) as c FROM attendance WHERE employeeId = ? AND status = 'present'", [employeeId]);
    final absent = await db.rawQuery("SELECT COUNT(*) as c FROM attendance WHERE employeeId = ? AND status = 'absent'", [employeeId]);
    final leave = await db.rawQuery("SELECT COUNT(*) as c FROM attendance WHERE employeeId = ? AND status = 'leave'", [employeeId]);
    return {
      'present': present.first['c'] as int,
      'absent': absent.first['c'] as int,
      'leave': leave.first['c'] as int,
    };
  }

  // ===== FOOTER SIGNATURE OPERATIONS =====
  static Future<int> insertFooterSignature(Map<String, dynamic> sig) async {
    final db = await database;
    return await db.insert('footer_signatures', sig);
  }

  static Future<int> updateFooterSignature(int id, Map<String, dynamic> sig) async {
    final db = await database;
    return await db.update('footer_signatures', sig, where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> deleteFooterSignature(int id) async {
    final db = await database;
    return await db.delete('footer_signatures', where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<Map<String, dynamic>>> getFooterSignatures() async {
    final db = await database;
    return await db.query('footer_signatures', orderBy: 'sortOrder ASC, id ASC');
  }

  // ===== INVESTIGATIONS SUMMARY REPORT =====
  static Future<List<Map<String, dynamic>>> getInvestigationsReport(String fromDate, String toDate) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        inv.id as invoiceId,
        inv.patientName,
        p.age,
        inv.date,
        inv.totalAmount,
        inv.discount
      FROM invoices inv
      JOIN patients p ON inv.patientId = p.id
      WHERE substr(inv.date, 1, 10) >= ? AND substr(inv.date, 1, 10) <= ?
      ORDER BY inv.date ASC
    ''', [fromDate, toDate]);
    
    final List<Map<String, dynamic>> reportRows = [];
    for (final row in result) {
      final invoiceId = row['invoiceId'] as int;
      final items = await db.query('invoice_items', columns: ['testName'], where: 'invoiceId = ?', whereArgs: [invoiceId]);
      final testsString = items.map((e) => e['testName'] as String? ?? '').where((t) => t.isNotEmpty).join(', ');
      
      reportRows.add({
        'patientName': row['patientName'],
        'age': row['age'],
        'date': row['date'],
        'tests': testsString,
        'price': row['totalAmount'],
        'discount': row['discount'],
      });
    }
    return reportRows;
  }
}
