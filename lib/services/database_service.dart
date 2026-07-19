import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Local SQLite store — the offline source of truth.
///
/// Sync design: every insert/update/soft-delete also queues the row id
/// in `sync_outbox`. The SyncService drains that queue to Supabase when
/// the farmer has internet, and applies remote changes back through the
/// `applyRemote` methods (which do NOT touch the outbox, so pulled rows
/// are never echoed back up).
class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  /// Tables that participate in cloud sync.
  static const syncedTables = [
    'batches',
    'vaccinations',
    'feed_records',
    'feed_inventory',
    'mortality',
    'egg_production',
    'financial_transactions',
  ];

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('hatch2revenue.db');
    return _database!;
  }

  /// Closes the connection (used before restoring a backup). The next
  /// [database] access reopens it and runs any pending migrations.
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 10,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  /// Rebuilds [table] using [createSql], preserving every column that
  /// exists in both the old and new schema. NOT NULL columns that have
  /// no old counterpart are filled with the schema default, or a
  /// type-appropriate zero value. Runs in a transaction so a failure
  /// leaves the original table untouched. NEVER drop a table in a
  /// migration — the local database is the farmer's only copy.
  Future<void> _rebuildTable(
    Database db,
    String table,
    String createSql,
  ) async {
    await db.transaction((txn) async {
      final oldInfo = await txn.rawQuery('PRAGMA table_info($table)');
      if (oldInfo.isEmpty) {
        // Table doesn't exist yet — just create it.
        await txn.execute(createSql);
        return;
      }
      final oldCols = oldInfo.map((r) => r['name'] as String).toSet();

      await txn.execute('ALTER TABLE $table RENAME TO ${table}_migrating');
      await txn.execute(createSql);

      final newInfo = await txn.rawQuery('PRAGMA table_info($table)');
      final dst = <String>[];
      final src = <String>[];
      for (final col in newInfo) {
        final name = col['name'] as String;
        dst.add(name);
        if (oldCols.contains(name)) {
          src.add(name);
        } else if (col['dflt_value'] != null) {
          src.add(col['dflt_value'] as String);
        } else if ((col['notnull'] as int) == 1) {
          final type = (col['type'] as String).toUpperCase();
          src.add(
            type.contains('INT') || type.contains('REAL') ? '0' : "''",
          );
        } else {
          src.add('NULL');
        }
      }
      await txn.execute(
        'INSERT INTO $table (${dst.join(', ')}) '
        'SELECT ${src.join(', ')} FROM ${table}_migrating',
      );
      await txn.execute('DROP TABLE ${table}_migrating');
    });
  }

  Future<void> _createSyncTables(DatabaseExecutor db) async {
    // One outbox row per changed record: pushing always sends the row's
    // CURRENT state, so repeated edits collapse into a single upload.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_outbox (
        tableName TEXT NOT NULL,
        rowId TEXT NOT NULL,
        queuedAt TEXT NOT NULL,
        PRIMARY KEY (tableName, rowId)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createIndexes(DatabaseExecutor db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_vaccinations_batch ON vaccinations(batchId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_feed_records_batch ON feed_records(batchId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_mortality_batch ON mortality(batchId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_egg_production_batch ON egg_production(batchId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_egg_production_date ON egg_production(date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_date ON financial_transactions(date)',
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      // v3: egg_production and mortality columns aligned with the app
      // models. Rebuilt in place — shared columns carry over.
      await _rebuildTable(db, 'egg_production', '''
        CREATE TABLE egg_production (
          id TEXT PRIMARY KEY,
          batchId TEXT NOT NULL,
          date TEXT NOT NULL,
          eggCount INTEGER NOT NULL DEFAULT 0,
          damagedCount INTEGER NOT NULL DEFAULT 0,
          pricePerEgg REAL NOT NULL DEFAULT 0,
          notes TEXT,
          createdAt TEXT NOT NULL DEFAULT '',
          updatedAt TEXT NOT NULL DEFAULT ''
        )
      ''');
      await _rebuildTable(db, 'mortality', '''
        CREATE TABLE mortality (
          id TEXT PRIMARY KEY,
          batchId TEXT NOT NULL,
          date TEXT NOT NULL,
          count INTEGER NOT NULL DEFAULT 0,
          cause INTEGER,
          notes TEXT,
          createdAt TEXT NOT NULL DEFAULT '',
          updatedAt TEXT NOT NULL DEFAULT ''
        )
      ''');
    }
    if (oldVersion < 4) {
      // v4: feed_inventory columns aligned with the FeedInventory model.
      await _rebuildTable(db, 'feed_inventory', '''
        CREATE TABLE feed_inventory (
          id TEXT PRIMARY KEY,
          feedTypeName TEXT NOT NULL DEFAULT '',
          quantityKg REAL NOT NULL DEFAULT 0,
          unitPrice REAL NOT NULL DEFAULT 0,
          expiryDate TEXT NOT NULL DEFAULT '',
          supplier TEXT,
          batchNumber TEXT,
          createdAt TEXT NOT NULL DEFAULT '',
          updatedAt TEXT NOT NULL DEFAULT ''
        )
      ''');
    }
    if (oldVersion < 5) {
      // v5: cloud-sync groundwork — soft-delete tombstones on every
      // synced table, the outbox queue, sync cursors, and indexes.
      for (final table in syncedTables) {
        final info = await db.rawQuery('PRAGMA table_info($table)');
        final hasDeletedAt = info.any((c) => c['name'] == 'deletedAt');
        if (!hasDeletedAt) {
          await db.execute('ALTER TABLE $table ADD COLUMN deletedAt TEXT');
        }
      }
      await _createSyncTables(db);
      await _createIndexes(db);
    }
    if (oldVersion < 6) {
      // v6: local cache of the owner-priced feed catalog.
      await _createCatalogTable(db);
    }
    if (oldVersion < 7) {
      // v7: egg collection period (morning/afternoon/evening).
      final info = await db.rawQuery('PRAGMA table_info(egg_production)');
      if (!info.any((c) => c['name'] == 'period')) {
        await db.execute('ALTER TABLE egg_production ADD COLUMN period TEXT');
      }
    }
    if (oldVersion < 8) {
      // v8: heal fresh-v7 installs, whose onCreate schema broke saving.
      //
      // batchId holds the batch NAME (or 'All'), never batches.id — the
      // FOREIGN KEY (batchId) REFERENCES batches(id) clauses that fresh
      // installs got made every feed/vaccination/transaction insert fail
      // with enforcement on. Rebuild those tables without the FK.
      await _rebuildTable(db, 'vaccinations', '''
        CREATE TABLE vaccinations (
          id TEXT PRIMARY KEY,
          batchId TEXT NOT NULL,
          vaccineName TEXT NOT NULL DEFAULT '',
          type INTEGER NOT NULL DEFAULT 0,
          scheduledDate TEXT NOT NULL DEFAULT '',
          administeredDate TEXT,
          status INTEGER NOT NULL DEFAULT 0,
          dosage REAL,
          unit TEXT,
          administeredBy TEXT,
          notes TEXT,
          reminderEnabled INTEGER NOT NULL DEFAULT 0,
          reminderDaysBefore INTEGER NOT NULL DEFAULT 1,
          createdAt TEXT NOT NULL DEFAULT '',
          updatedAt TEXT NOT NULL DEFAULT '',
          deletedAt TEXT
        )
      ''');
      await _rebuildTable(db, 'feed_records', '''
        CREATE TABLE feed_records (
          id TEXT PRIMARY KEY,
          batchId TEXT NOT NULL,
          date TEXT NOT NULL DEFAULT '',
          feedType INTEGER NOT NULL DEFAULT 0,
          bagsUsed INTEGER NOT NULL DEFAULT 0,
          kgPerBag REAL NOT NULL DEFAULT 50.0,
          unitPricePerBag REAL NOT NULL DEFAULT 0,
          supplier TEXT,
          batchNumber TEXT,
          notes TEXT,
          createdAt TEXT NOT NULL DEFAULT '',
          updatedAt TEXT NOT NULL DEFAULT '',
          deletedAt TEXT
        )
      ''');
      await _rebuildTable(db, 'financial_transactions', '''
        CREATE TABLE financial_transactions (
          id TEXT PRIMARY KEY,
          date TEXT NOT NULL DEFAULT '',
          type INTEGER NOT NULL DEFAULT 0,
          category INTEGER NOT NULL DEFAULT 0,
          amount REAL NOT NULL DEFAULT 0,
          description TEXT,
          batchId TEXT,
          createdAt TEXT NOT NULL DEFAULT '',
          updatedAt TEXT NOT NULL DEFAULT '',
          deletedAt TEXT
        )
      ''');
      // Fresh-v7 installs also missed the period column (onCreate lacked
      // it and the v7 ALTER never ran for them).
      final eggInfo = await db.rawQuery('PRAGMA table_info(egg_production)');
      if (!eggInfo.any((c) => c['name'] == 'period')) {
        await db.execute('ALTER TABLE egg_production ADD COLUMN period TEXT');
      }
      // Rebuilds drop secondary indexes with the old tables — restore.
      await _createIndexes(db);
    }
    if (oldVersion < 9) {
      // v9: children now reference batches by ID, not display name.
      // Name-keyed references broke on rename races (an offline worker
      // logging against a name the owner just changed orphans the row).
      // Convert every child row whose batchId matches a batch NAME to
      // that batch's id, bump updatedAt so LWW propagates, and queue
      // the rows for upload. 'All' and unknown refs stay as-is.
      const childTables = [
        'vaccinations',
        'feed_records',
        'egg_production',
        'mortality',
        'financial_transactions',
      ];
      final now = DateTime.now().toIso8601String();
      await db.transaction((txn) async {
        for (final table in childTables) {
          await txn.execute('''
            UPDATE $table SET
              batchId = (SELECT b.id FROM batches b WHERE b.name = $table.batchId),
              updatedAt = ?
            WHERE EXISTS (SELECT 1 FROM batches b WHERE b.name = $table.batchId)
          ''', [now]);
          await txn.execute('''
            INSERT OR REPLACE INTO sync_outbox (tableName, rowId, queuedAt)
            SELECT ?, id, ? FROM $table
            WHERE batchId IN (SELECT id FROM batches)
          ''', [table, now]);
        }
      });
    }
    if (oldVersion < 10) {
      // v10: egg sales & debtors ledger.
      await _createEggSalesTable(db);
    }
  }

  /// Egg sales & debtors. Local-only for now (NOT in [syncedTables] —
  /// the cloud has no h2r_egg_sales mirror yet); the income these sales
  /// generate still syncs via financial_transactions. IF EXISTS guard so
  /// fresh installs and migrations share one definition.
  Future<void> _createEggSalesTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS egg_sales (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        buyer TEXT NOT NULL DEFAULT '',
        eggCount INTEGER NOT NULL DEFAULT 0,
        pricePerEgg REAL NOT NULL DEFAULT 0,
        amountPaid REAL NOT NULL DEFAULT 0,
        notes TEXT,
        createdAt TEXT NOT NULL DEFAULT '',
        updatedAt TEXT NOT NULL DEFAULT ''
      )
    ''');
  }

  Future<void> _createCatalogTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS feed_catalog (
        id TEXT PRIMARY KEY,
        feedName TEXT NOT NULL,
        pricePerBag REAL NOT NULL,
        kgPerBag REAL NOT NULL DEFAULT 50,
        marketMin REAL,
        marketMax REAL
      )
    ''');
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
        updatedAt TEXT NOT NULL,
        deletedAt TEXT
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
        deletedAt TEXT
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
        deletedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE feed_inventory (
        id TEXT PRIMARY KEY,
        feedTypeName TEXT NOT NULL,
        quantityKg REAL NOT NULL,
        unitPrice REAL NOT NULL DEFAULT 0,
        expiryDate TEXT NOT NULL,
        supplier TEXT,
        batchNumber TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        deletedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE mortality (
        id TEXT PRIMARY KEY,
        batchId TEXT NOT NULL,
        date TEXT NOT NULL,
        count INTEGER NOT NULL,
        cause INTEGER,
        notes TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        deletedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE egg_production (
        id TEXT PRIMARY KEY,
        batchId TEXT NOT NULL,
        date TEXT NOT NULL,
        eggCount INTEGER NOT NULL,
        damagedCount INTEGER NOT NULL DEFAULT 0,
        pricePerEgg REAL NOT NULL DEFAULT 0,
        period TEXT,
        notes TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        deletedAt TEXT
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
        deletedAt TEXT
      )
    ''');

    await _createSyncTables(db);
    await _createIndexes(db);
    await _createCatalogTable(db);
    await _createEggSalesTable(db);
  }

  // ---------------------------------------------------------------
  // Feed catalog cache (owner-set prices, refreshed on every sync so
  // workers see current prices even when they go offline again).
  // ---------------------------------------------------------------

  Future<void> replaceCatalog(List<Map<String, dynamic>> rows) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('feed_catalog');
      for (final row in rows) {
        await txn.insert('feed_catalog', row);
      }
    });
  }

  Future<List<Map<String, dynamic>>> getCatalog() async {
    final db = await database;
    return db.query('feed_catalog', orderBy: 'feedName');
  }

  // ---------------------------------------------------------------
  // Generic synced mutations. All app writes flow through these so
  // every change lands in the outbox atomically with the data.
  // ---------------------------------------------------------------

  Future<void> _enqueue(
    DatabaseExecutor db,
    String table,
    String rowId,
  ) async {
    await db.insert('sync_outbox', {
      'tableName': table,
      'rowId': rowId,
      'queuedAt': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _insertSynced(String table, Map<String, dynamic> row) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(table, row);
      await _enqueue(txn, table, row['id'] as String);
    });
  }

  Future<void> _updateSynced(String table, Map<String, dynamic> row) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(table, row, where: 'id = ?', whereArgs: [row['id']]);
      await _enqueue(txn, table, row['id'] as String);
    });
  }

  /// Deletes are tombstones, never real DELETEs: the row must survive
  /// locally so the deletion can reach the cloud (and other devices).
  Future<void> _softDeleteSynced(String table, String id) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.update(
        table,
        {'deletedAt': now, 'updatedAt': now},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _enqueue(txn, table, id);
    });
  }

  Future<List<Map<String, dynamic>>> _liveRows(
    String table, {
    String? orderBy,
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await database;
    final liveFilter = 'deletedAt IS NULL';
    return db.query(
      table,
      where: where == null ? liveFilter : '$liveFilter AND ($where)',
      whereArgs: whereArgs,
      orderBy: orderBy,
    );
  }

  // ---------------------------------------------------------------
  // Sync plumbing used by SyncService.
  // ---------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getOutbox() async {
    final db = await database;
    return db.query('sync_outbox', orderBy: 'queuedAt ASC');
  }

  Future<int> getOutboxCount() async {
    final db = await database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM sync_outbox');
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<void> clearOutboxEntry(String table, String rowId) async {
    final db = await database;
    await db.delete(
      'sync_outbox',
      where: 'tableName = ? AND rowId = ?',
      whereArgs: [table, rowId],
    );
  }

  Future<Map<String, dynamic>?> getRowById(String table, String id) async {
    final db = await database;
    final rows = await db.query(table, where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  /// Writes a row that arrived from the cloud. Bypasses the outbox so
  /// pulled data is never echoed back up.
  Future<void> applyRemote(String table, Map<String, dynamic> row) async {
    final db = await database;
    await db.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Queues every existing row for upload — used right after the user
  /// signs in for the first time so their history reaches the cloud.
  Future<void> enqueueAllExisting() async {
    final db = await database;
    await db.transaction((txn) async {
      for (final table in syncedTables) {
        final rows = await txn.query(table, columns: ['id']);
        for (final row in rows) {
          await _enqueue(txn, table, row['id'] as String);
        }
      }
    });
  }

  Future<String?> getMeta(String key) async {
    final db = await database;
    final rows = await db.query(
      'sync_meta',
      where: 'key = ?',
      whereArgs: [key],
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setMeta(String key, String value) async {
    final db = await database;
    await db.insert('sync_meta', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---------------------------------------------------------------
  // Batch CRUD
  // ---------------------------------------------------------------

  Future<void> insertBatch(Map<String, dynamic> batch) =>
      _insertSynced('batches', batch);

  Future<List<Map<String, dynamic>>> getAllBatches() =>
      _liveRows('batches', orderBy: 'createdAt DESC');

  Future<void> updateBatch(Map<String, dynamic> batch) =>
      _updateSynced('batches', batch);

  Future<void> deleteBatch(String id) => _softDeleteSynced('batches', id);

  // Vaccination CRUD
  Future<void> insertVaccination(Map<String, dynamic> vac) =>
      _insertSynced('vaccinations', vac);

  Future<List<Map<String, dynamic>>> getAllVaccinations() =>
      _liveRows('vaccinations', orderBy: 'scheduledDate ASC');

  Future<List<Map<String, dynamic>>> getVaccinationsByBatch(String batchId) =>
      _liveRows('vaccinations', where: 'batchId = ?', whereArgs: [batchId]);

  Future<void> updateVaccination(Map<String, dynamic> vac) =>
      _updateSynced('vaccinations', vac);

  Future<void> deleteVaccination(String id) =>
      _softDeleteSynced('vaccinations', id);

  // Feed Records CRUD
  Future<void> insertFeedRecord(Map<String, dynamic> feed) =>
      _insertSynced('feed_records', feed);

  Future<List<Map<String, dynamic>>> getAllFeedRecords() =>
      _liveRows('feed_records', orderBy: 'date DESC');

  Future<void> updateFeedRecord(Map<String, dynamic> feed) =>
      _updateSynced('feed_records', feed);

  Future<void> deleteFeedRecord(String id) =>
      _softDeleteSynced('feed_records', id);

  // Feed Inventory CRUD
  Future<void> insertFeedInventory(Map<String, dynamic> item) =>
      _insertSynced('feed_inventory', item);

  Future<List<Map<String, dynamic>>> getAllFeedInventory() =>
      _liveRows('feed_inventory', orderBy: 'expiryDate ASC');

  Future<void> updateFeedInventory(Map<String, dynamic> item) =>
      _updateSynced('feed_inventory', item);

  Future<void> deleteFeedInventory(String id) =>
      _softDeleteSynced('feed_inventory', id);

  // Mortality CRUD
  Future<void> insertMortality(Map<String, dynamic> mort) =>
      _insertSynced('mortality', mort);

  Future<List<Map<String, dynamic>>> getAllMortality() =>
      _liveRows('mortality', orderBy: 'date DESC');

  Future<void> updateMortality(Map<String, dynamic> mort) =>
      _updateSynced('mortality', mort);

  Future<void> deleteMortality(String id) => _softDeleteSynced('mortality', id);

  // Egg Production CRUD
  Future<void> insertEggProduction(Map<String, dynamic> prod) =>
      _insertSynced('egg_production', prod);

  Future<List<Map<String, dynamic>>> getAllEggProduction() =>
      _liveRows('egg_production', orderBy: 'date DESC');

  Future<void> updateEggProduction(Map<String, dynamic> prod) =>
      _updateSynced('egg_production', prod);

  Future<void> deleteEggProduction(String id) =>
      _softDeleteSynced('egg_production', id);

  // Egg Sales CRUD (local-only — plain writes, no sync outbox)
  Future<void> insertEggSale(Map<String, dynamic> sale) async {
    final db = await database;
    await db.insert('egg_sales', sale);
  }

  Future<List<Map<String, dynamic>>> getAllEggSales() async {
    final db = await database;
    return db.query('egg_sales', orderBy: 'date DESC');
  }

  Future<void> updateEggSale(Map<String, dynamic> sale) async {
    final db = await database;
    await db.update('egg_sales', sale, where: 'id = ?', whereArgs: [sale['id']]);
  }

  Future<void> deleteEggSale(String id) async {
    final db = await database;
    await db.delete('egg_sales', where: 'id = ?', whereArgs: [id]);
  }

  // Financial Transactions CRUD
  Future<void> insertTransaction(Map<String, dynamic> txn) =>
      _insertSynced('financial_transactions', txn);

  Future<List<Map<String, dynamic>>> getAllTransactions() =>
      _liveRows('financial_transactions', orderBy: 'date DESC');

  Future<void> updateTransaction(Map<String, dynamic> txn) =>
      _updateSynced('financial_transactions', txn);

  Future<void> deleteTransaction(String id) =>
      _softDeleteSynced('financial_transactions', id);
}
