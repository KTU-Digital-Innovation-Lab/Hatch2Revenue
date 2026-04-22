import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('hatch2revenue.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades if needed
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE batches (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        type INTEGER NOT NULL,
        initialCount INTEGER NOT NULL,
        currentCount INTEGER NOT NULL,
        hatchDate TEXT NOT NULL,
        source TEXT,
        initialCost REAL,
        coopId TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE vaccinations (
        id TEXT PRIMARY KEY,
        batchId TEXT NOT NULL,
        vaccineName TEXT NOT NULL,
        type INTEGER NOT NULL,
        scheduledDate TEXT NOT NULL,
        administeredDate TEXT,
        status INTEGER NOT NULL,
        dosage REAL,
        unit TEXT,
        administeredBy TEXT,
        notes TEXT,
        reminderEnabled INTEGER NOT NULL,
        reminderDaysBefore INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (batchId) REFERENCES batches (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE feed_records (
        id TEXT PRIMARY KEY,
        batchId TEXT NOT NULL,
        date TEXT NOT NULL,
        feedType INTEGER NOT NULL,
        bagsUsed INTEGER NOT NULL,
        kgPerBag REAL NOT NULL DEFAULT 50.0,
        unitPricePerBag REAL NOT NULL,
        supplier TEXT,
        batchNumber TEXT,
        notes TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (batchId) REFERENCES batches (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE feed_inventory (
        id TEXT PRIMARY KEY,
        feedType TEXT NOT NULL,
        bagsInStock INTEGER NOT NULL,
        kgPerBag REAL NOT NULL DEFAULT 50.0,
        unitPricePerBag REAL NOT NULL,
        expiryDate TEXT NOT NULL,
        supplier TEXT,
        batchNumber TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE mortality (
        id TEXT PRIMARY KEY,
        batchId TEXT NOT NULL,
        date TEXT NOT NULL,
        count INTEGER NOT NULL,
        cause INTEGER NOT NULL,
        notes TEXT,
        estimatedLoss REAL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (batchId) REFERENCES batches (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE egg_production (
        id TEXT PRIMARY KEY,
        batchId TEXT NOT NULL,
        date TEXT NOT NULL,
        totalCrates INTEGER NOT NULL,
        eggsPerCrate INTEGER NOT NULL DEFAULT 30,
        pricePerCrate REAL NOT NULL,
        notes TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (batchId) REFERENCES batches (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE financial_transactions (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        type INTEGER NOT NULL,
        category INTEGER NOT NULL,
        amount REAL NOT NULL,
        description TEXT,
        batchId TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (batchId) REFERENCES batches (id)
      )
    ''');
  }

  // Batch CRUD
  Future<void> insertBatch(Map<String, dynamic> batch) async {
    final db = await database;
    await db.insert('batches', batch);
  }

  Future<List<Map<String, dynamic>>> getAllBatches() async {
    final db = await database;
    return await db.query('batches', orderBy: 'createdAt DESC');
  }

  Future<void> updateBatch(Map<String, dynamic> batch) async {
    final db = await database;
    await db.update(
      'batches',
      batch,
      where: 'id = ?',
      whereArgs: [batch['id']],
    );
  }

  Future<void> deleteBatch(String id) async {
    final db = await database;
    await db.delete('batches', where: 'id = ?', whereArgs: [id]);
  }

  // Vaccination CRUD
  Future<void> insertVaccination(Map<String, dynamic> vac) async {
    final db = await database;
    await db.insert('vaccinations', vac);
  }

  Future<List<Map<String, dynamic>>> getAllVaccinations() async {
    final db = await database;
    return await db.query('vaccinations', orderBy: 'scheduledDate ASC');
  }

  Future<List<Map<String, dynamic>>> getVaccinationsByBatch(
    String batchId,
  ) async {
    final db = await database;
    return await db.query(
      'vaccinations',
      where: 'batchId = ?',
      whereArgs: [batchId],
    );
  }

  Future<void> updateVaccination(Map<String, dynamic> vac) async {
    final db = await database;
    await db.update(
      'vaccinations',
      vac,
      where: 'id = ?',
      whereArgs: [vac['id']],
    );
  }

  Future<void> deleteVaccination(String id) async {
    final db = await database;
    await db.delete('vaccinations', where: 'id = ?', whereArgs: [id]);
  }

  // Feed Records CRUD
  Future<void> insertFeedRecord(Map<String, dynamic> feed) async {
    final db = await database;
    await db.insert('feed_records', feed);
  }

  Future<List<Map<String, dynamic>>> getAllFeedRecords() async {
    final db = await database;
    return await db.query('feed_records', orderBy: 'date DESC');
  }

  Future<void> updateFeedRecord(Map<String, dynamic> feed) async {
    final db = await database;
    await db.update(
      'feed_records',
      feed,
      where: 'id = ?',
      whereArgs: [feed['id']],
    );
  }

  Future<void> deleteFeedRecord(String id) async {
    final db = await database;
    await db.delete('feed_records', where: 'id = ?', whereArgs: [id]);
  }

  // Mortality CRUD
  Future<void> insertMortality(Map<String, dynamic> mort) async {
    final db = await database;
    await db.insert('mortality', mort);
  }

  Future<List<Map<String, dynamic>>> getAllMortality() async {
    final db = await database;
    return await db.query('mortality', orderBy: 'date DESC');
  }

  Future<void> updateMortality(Map<String, dynamic> mort) async {
    final db = await database;
    await db.update(
      'mortality',
      mort,
      where: 'id = ?',
      whereArgs: [mort['id']],
    );
  }

  Future<void> deleteMortality(String id) async {
    final db = await database;
    await db.delete('mortality', where: 'id = ?', whereArgs: [id]);
  }

  // Egg Production CRUD
  Future<void> insertEggProduction(Map<String, dynamic> prod) async {
    final db = await database;
    await db.insert('egg_production', prod);
  }

  Future<List<Map<String, dynamic>>> getAllEggProduction() async {
    final db = await database;
    return await db.query('egg_production', orderBy: 'date DESC');
  }

  Future<void> updateEggProduction(Map<String, dynamic> prod) async {
    final db = await database;
    await db.update(
      'egg_production',
      prod,
      where: 'id = ?',
      whereArgs: [prod['id']],
    );
  }

  Future<void> deleteEggProduction(String id) async {
    final db = await database;
    await db.delete('egg_production', where: 'id = ?', whereArgs: [id]);
  }

  // Financial Transactions CRUD
  Future<void> insertTransaction(Map<String, dynamic> txn) async {
    final db = await database;
    await db.insert('financial_transactions', txn);
  }

  Future<List<Map<String, dynamic>>> getAllTransactions() async {
    final db = await database;
    return await db.query('financial_transactions', orderBy: 'date DESC');
  }

  Future<void> updateTransaction(Map<String, dynamic> txn) async {
    final db = await database;
    await db.update(
      'financial_transactions',
      txn,
      where: 'id = ?',
      whereArgs: [txn['id']],
    );
  }

  Future<void> deleteTransaction(String id) async {
    final db = await database;
    await db.delete('financial_transactions', where: 'id = ?', whereArgs: [id]);
  }
}
