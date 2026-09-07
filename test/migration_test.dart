// Migration tests.
//
// The local database is the farmer's only copy of their records, so a
// bad migration does not mean a bug report — it means a year of work is
// gone. These tests build a database at an OLD schema version, put real
// rows in it, run the production upgrade path, and assert that every
// row is still there with the right values.
//
// The v7 fixture below is deliberately the BROKEN fresh-install shape
// that shipped in v1.0.0: batchId columns carrying FOREIGN KEY clauses
// pointing at batches(id) while the app actually stored batch NAMES,
// and an egg_production table with no period column. That combination
// made every feed, vaccination and transaction save fail on phones that
// installed fresh rather than upgrading. It is the defect the v8 branch
// exists to heal, so it is the one worth regression-testing.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hatch2revenue/services/database_service.dart';

/// Creates the v7 fresh-install schema at [path] and returns it open.
Future<Database> _createV7Database(String path) async {
  final db = await databaseFactory.openDatabase(
    path,
    options: OpenDatabaseOptions(version: 7),
  );

  await db.execute('''
    CREATE TABLE batches (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL DEFAULT '',
      description TEXT,
      type INTEGER NOT NULL DEFAULT 0,
      initialCount INTEGER NOT NULL DEFAULT 0,
      currentCount INTEGER NOT NULL DEFAULT 0,
      hatchDate TEXT NOT NULL DEFAULT '',
      source TEXT,
      initialCost REAL,
      coopId TEXT,
      createdAt TEXT NOT NULL DEFAULT '',
      updatedAt TEXT NOT NULL DEFAULT '',
      deletedAt TEXT
    )
  ''');

  // The three tables whose FK clauses broke saving on fresh v7 installs.
  await db.execute('''
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
      deletedAt TEXT,
      FOREIGN KEY (batchId) REFERENCES batches(id)
    )
  ''');
  await db.execute('''
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
      deletedAt TEXT,
      FOREIGN KEY (batchId) REFERENCES batches(id)
    )
  ''');
  await db.execute('''
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
      deletedAt TEXT,
      FOREIGN KEY (batchId) REFERENCES batches(id)
    )
  ''');

  // egg_production as fresh v7 installs got it: NO period column.
  await db.execute('''
    CREATE TABLE egg_production (
      id TEXT PRIMARY KEY,
      batchId TEXT NOT NULL,
      date TEXT NOT NULL,
      eggCount INTEGER NOT NULL DEFAULT 0,
      damagedCount INTEGER NOT NULL DEFAULT 0,
      pricePerEgg REAL NOT NULL DEFAULT 0,
      notes TEXT,
      createdAt TEXT NOT NULL DEFAULT '',
      updatedAt TEXT NOT NULL DEFAULT '',
      deletedAt TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE mortality (
      id TEXT PRIMARY KEY,
      batchId TEXT NOT NULL,
      date TEXT NOT NULL,
      count INTEGER NOT NULL DEFAULT 0,
      cause INTEGER,
      notes TEXT,
      createdAt TEXT NOT NULL DEFAULT '',
      updatedAt TEXT NOT NULL DEFAULT '',
      deletedAt TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE feed_inventory (
      id TEXT PRIMARY KEY,
      feedTypeName TEXT NOT NULL DEFAULT '',
      quantityKg REAL NOT NULL DEFAULT 0,
      unitPrice REAL NOT NULL DEFAULT 0,
      expiryDate TEXT NOT NULL DEFAULT '',
      supplier TEXT,
      batchNumber TEXT,
      createdAt TEXT NOT NULL DEFAULT '',
      updatedAt TEXT NOT NULL DEFAULT '',
      deletedAt TEXT
    )
  ''');
  // Present since v6, so a v7 install has it.
  await db.execute('''
    CREATE TABLE feed_catalog (
      id TEXT PRIMARY KEY,
      feedName TEXT NOT NULL,
      pricePerBag REAL NOT NULL,
      kgPerBag REAL NOT NULL DEFAULT 50,
      marketMin REAL,
      marketMax REAL
    )
  ''');
  await db.execute('''
    CREATE TABLE sync_outbox (
      tableName TEXT NOT NULL,
      rowId TEXT NOT NULL,
      queuedAt TEXT NOT NULL,
      PRIMARY KEY (tableName, rowId)
    )
  ''');
  await db.execute('''
    CREATE TABLE sync_meta (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''');

  return db;
}

/// A day's worth of a real farm's records, keyed by batch NAME the way
/// pre-v9 builds stored them.
Future<void> _seedFarmData(Database db) async {
  await db.insert('batches', {
    'id': 'batch-uuid-1',
    'name': 'Layer House A',
    'type': 2,
    'description': 'Isa Brown layers',
    'initialCount': 500,
    'currentCount': 486,
    'hatchDate': '2026-01-15T00:00:00.000',
    'source': 'Akate Farms',
    'initialCost': 4500.0,
    'createdAt': '2026-01-15T08:00:00.000',
    'updatedAt': '2026-01-15T08:00:00.000',
  });

  await db.insert('vaccinations', {
    'id': 'vacc-1',
    'batchId': 'Layer House A', // name, not id
    'vaccineName': 'Newcastle Disease',
    'type': 1,
    'scheduledDate': '2026-02-01T00:00:00.000',
    'status': 1,
    'reminderEnabled': 1,
    'reminderDaysBefore': 1,
    'createdAt': '2026-01-20T08:00:00.000',
    'updatedAt': '2026-01-20T08:00:00.000',
  });
  await db.insert('feed_records', {
    'id': 'feed-1',
    'batchId': 'Layer House A',
    'date': '2026-03-01T00:00:00.000',
    'feedType': 2,
    'bagsUsed': 3,
    'kgPerBag': 50.0,
    'unitPricePerBag': 230.0,
    'createdAt': '2026-03-01T08:00:00.000',
    'updatedAt': '2026-03-01T08:00:00.000',
  });
  await db.insert('egg_production', {
    'id': 'egg-1',
    'batchId': 'Layer House A',
    'date': '2026-06-10T00:00:00.000',
    'eggCount': 420,
    'damagedCount': 6,
    'pricePerEgg': 1.2,
    'createdAt': '2026-06-10T18:00:00.000',
    'updatedAt': '2026-06-10T18:00:00.000',
  });
  await db.insert('mortality', {
    'id': 'mort-1',
    'batchId': 'Layer House A',
    'date': '2026-05-02T00:00:00.000',
    'count': 14,
    'cause': 3,
    'createdAt': '2026-05-02T09:00:00.000',
    'updatedAt': '2026-05-02T09:00:00.000',
  });
  await db.insert('financial_transactions', {
    'id': 'txn-1',
    'date': '2026-01-15T00:00:00.000',
    'type': 1,
    'category': 4,
    'amount': 4500.0,
    'description': 'Day-old chicks',
    'batchId': 'Layer House A',
    'createdAt': '2026-01-15T08:00:00.000',
    'updatedAt': '2026-01-15T08:00:00.000',
  });
  await db.insert('feed_inventory', {
    'id': 'stock-1',
    'feedTypeName': 'Layer Mash',
    'quantityKg': 250.0,
    'unitPrice': 230.0,
    'expiryDate': '2026-12-31T00:00:00.000',
    'supplier': 'Agricare',
    'createdAt': '2026-03-01T08:00:00.000',
    'updatedAt': '2026-03-01T08:00:00.000',
  });
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tmp;
  late String dbPath;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('h2r_migration_test');
    dbPath = '${tmp.path}/hatch2revenue.db';
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('v7 to current upgrade', () {
    late Database db;

    setUp(() async {
      final legacy = await _createV7Database(dbPath);
      await _seedFarmData(legacy);
      await legacy.close();
      // Reopen through the production path: this runs _upgradeDB.
      db = await DatabaseService.instance.openAt(dbPath);
    });

    tearDown(() async => db.close());

    test('reaches the current schema version', () async {
      final v = await db.getVersion();
      expect(v, DatabaseService.schemaVersion);
      expect(v, 15);
    });

    test('every seeded row survives the upgrade', () async {
      for (final entry in {
        'batches': 1,
        'vaccinations': 1,
        'feed_records': 1,
        'egg_production': 1,
        'mortality': 1,
        'financial_transactions': 1,
        'feed_inventory': 1,
      }.entries) {
        final rows = await db.query(entry.key);
        expect(rows.length, entry.value,
            reason: '${entry.key} lost rows during migration');
      }
    });

    test('column values are carried across unchanged', () async {
      final batch = (await db.query('batches')).single;
      expect(batch['name'], 'Layer House A');
      expect(batch['initialCount'], 500);
      expect(batch['currentCount'], 486);
      expect(batch['initialCost'], 4500.0);
      expect(batch['description'], 'Isa Brown layers');
      expect(batch['hatchDate'], '2026-01-15T00:00:00.000');

      final feed = (await db.query('feed_records')).single;
      expect(feed['bagsUsed'], 3);
      expect(feed['kgPerBag'], 50.0);
      expect(feed['unitPricePerBag'], 230.0);

      final eggs = (await db.query('egg_production')).single;
      expect(eggs['eggCount'], 420);
      expect(eggs['damagedCount'], 6);
      expect(eggs['pricePerEgg'], 1.2);

      final txn = (await db.query('financial_transactions')).single;
      expect(txn['amount'], 4500.0);
      expect(txn['description'], 'Day-old chicks');

      final death = (await db.query('mortality')).single;
      expect(death['count'], 14);
      expect(death['cause'], 3);
    });

    test('v8 removes the foreign keys that broke saving', () async {
      // With FK enforcement on, these inserts failed on fresh v7
      // installs because batchId held a name, not a batches.id.
      await db.insert('feed_records', {
        'id': 'feed-new',
        'batchId': 'All',
        'date': '2026-07-20T00:00:00.000',
        'feedType': 2,
        'bagsUsed': 1,
        'kgPerBag': 50.0,
        'unitPricePerBag': 230.0,
        'createdAt': '2026-07-20T08:00:00.000',
        'updatedAt': '2026-07-20T08:00:00.000',
      });
      await db.insert('vaccinations', {
        'id': 'vacc-new',
        'batchId': 'All',
        'vaccineName': 'Gumboro',
        'scheduledDate': '2026-08-01T00:00:00.000',
        'createdAt': '2026-07-20T08:00:00.000',
        'updatedAt': '2026-07-20T08:00:00.000',
      });
      await db.insert('financial_transactions', {
        'id': 'txn-new',
        'date': '2026-07-20T00:00:00.000',
        'amount': 120.0,
        'batchId': 'All',
        'createdAt': '2026-07-20T08:00:00.000',
        'updatedAt': '2026-07-20T08:00:00.000',
      });

      expect((await db.query('feed_records')).length, 2);
      expect((await db.query('vaccinations')).length, 2);
      expect((await db.query('financial_transactions')).length, 2);
    });

    test('v8 adds the period column fresh installs missed', () async {
      final info = await db.rawQuery('PRAGMA table_info(egg_production)');
      expect(info.any((c) => c['name'] == 'period'), isTrue);
    });

    test('v9 rewrites name references to batch ids', () async {
      for (final table in [
        'vaccinations',
        'feed_records',
        'egg_production',
        'mortality',
        'financial_transactions',
      ]) {
        final row = (await db.query(table, where: 'id NOT LIKE ?',
                whereArgs: ['%-new']))
            .single;
        expect(row['batchId'], 'batch-uuid-1',
            reason: '$table still references the batch by name');
      }
    });

    test('v9 queues the rewritten rows for upload', () async {
      final queued = await db.query('sync_outbox');
      expect(queued, isNotEmpty);
      final tables = queued.map((r) => r['tableName']).toSet();
      expect(tables, contains('feed_records'));
      expect(tables, contains('egg_production'));
    });

    test('egg_sales exists with its tombstone column', () async {
      final info = await db.rawQuery('PRAGMA table_info(egg_sales)');
      expect(info, isNotEmpty, reason: 'egg_sales table was never created');
      expect(info.any((c) => c['name'] == 'deletedAt'), isTrue);

      await db.insert('egg_sales', {
        'id': 'sale-1',
        'date': '2026-07-20T00:00:00.000',
        'buyer': 'Mensah Provisions',
        'eggCount': 300,
        'pricePerEgg': 1.2,
        'amountPaid': 200.0,
        'createdAt': '2026-07-20T10:00:00.000',
        'updatedAt': '2026-07-20T10:00:00.000',
      });
      expect((await db.query('egg_sales')).length, 1);
    });

    test('indexes dropped by the table rebuilds are restored', () async {
      final idx = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='index' AND name LIKE 'idx_%'");
      final names = idx.map((r) => r['name']).toSet();
      expect(names, contains('idx_vaccinations_batch'));
    });

    test('v13 adds the supplier column and flock-monitoring tables', () async {
      final batchCols = await db.rawQuery('PRAGMA table_info(batches)');
      expect(batchCols.any((c) => c['name'] == 'supplier'), isTrue,
          reason: 'batches is missing the v13 supplier column');

      for (final t in ['measurements', 'poultry_houses']) {
        final info = await db.rawQuery('PRAGMA table_info($t)');
        expect(info, isNotEmpty, reason: '$t table was not created');
      }

      await db.insert('measurements', {
        'id': 'm-1',
        'batchId': 'batch-uuid-1',
        'date': '2026-07-20T00:00:00.000',
        'type': 0,
        'value': 1450.0,
        'createdAt': '2026-07-20T08:00:00.000',
        'updatedAt': '2026-07-20T08:00:00.000',
      });
      await db.insert('poultry_houses', {
        'id': 'h-1',
        'name': 'House 1',
        'capacity': 2000,
        'createdAt': '2026-07-20T08:00:00.000',
        'updatedAt': '2026-07-20T08:00:00.000',
      });
      expect((await db.query('measurements')).length, 1);
      expect((await db.query('poultry_houses')).length, 1);
    });

    test('v14 adds the local-only stockItemId column to feed_records', () async {
      final cols = await db.rawQuery('PRAGMA table_info(feed_records)');
      expect(cols.any((c) => c['name'] == 'stockItemId'), isTrue,
          reason: 'feed_records is missing the v14 stockItemId column');

      // A consumption log can now carry the stock item it drew from.
      await db.insert('feed_records', {
        'id': 'fr-1',
        'batchId': 'All',
        'date': '2026-07-20T00:00:00.000',
        'feedType': 2,
        'bagsUsed': 1,
        'kgPerBag': 150.0,
        'unitPricePerBag': 480.0,
        'stockItemId': 'stock-1',
        'createdAt': '2026-07-20T08:00:00.000',
        'updatedAt': '2026-07-20T08:00:00.000',
      });
      final row = (await db.query('feed_records', where: 'id = ?', whereArgs: ['fr-1'])).single;
      expect(row['stockItemId'], 'stock-1');
    });

    test('v15 adds the local-only sourceId column to financial_transactions', () async {
      final cols = await db.rawQuery('PRAGMA table_info(financial_transactions)');
      expect(cols.any((c) => c['name'] == 'sourceId'), isTrue,
          reason: 'financial_transactions is missing the v15 sourceId column');

      // An auto-posted transaction can now carry the record it came from.
      await db.insert('financial_transactions', {
        'id': 'tx-1',
        'date': '2026-07-20T00:00:00.000',
        'type': 1,
        'category': 0,
        'amount': 400.0,
        'description': 'Feed: 2 bags Layer',
        'batchId': 'All',
        'sourceId': 'feed-rec-1',
        'createdAt': '2026-07-20T08:00:00.000',
        'updatedAt': '2026-07-20T08:00:00.000',
      });
      final row = (await db.query('financial_transactions', where: 'id = ?', whereArgs: ['tx-1'])).single;
      expect(row['sourceId'], 'feed-rec-1');
    });
  });

  group('fresh install matches upgraded install', () {
    // The v1.0.0 disaster was a fresh-install schema that differed from
    // the one upgrading phones had. Two farmers running the same version
    // must get the same database, or a save that works on one phone
    // fails on the other. These tests compare the two paths directly.

    late Database fresh;
    late Database migrated;

    setUp(() async {
      fresh = await DatabaseService.instance.openAt('${tmp.path}/fresh.db');

      final legacyPath = '${tmp.path}/legacy.db';
      final legacy = await _createV7Database(legacyPath);
      await _seedFarmData(legacy);
      await legacy.close();
      migrated = await DatabaseService.instance.openAt(legacyPath);
    });

    tearDown(() async {
      await fresh.close();
      await migrated.close();
    });

    test('both report the current schema version', () async {
      expect(await fresh.getVersion(), DatabaseService.schemaVersion);
      expect(await migrated.getVersion(), DatabaseService.schemaVersion);
    });

    test('both contain the same tables', () async {
      Future<Set<Object?>> tablesOf(Database db) async => (await db.rawQuery(
              "SELECT name FROM sqlite_master WHERE type='table' "
              "AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'"))
          .map((r) => r['name'])
          .toSet();
      expect(await tablesOf(fresh), await tablesOf(migrated));
    });

    test('every table has identical columns, types and nullability',
        () async {
      const tables = [
        'batches',
        'vaccinations',
        'feed_records',
        'feed_inventory',
        'egg_production',
        'egg_sales',
        'mortality',
        'financial_transactions',
        'measurements',
        'poultry_houses',
      ];
      for (final t in tables) {
        String describe(List<Map<String, Object?>> info) => (info
                .map((c) => '${c['name']}:${c['type']}:'
                    'notnull=${c['notnull']}:default=${c['dflt_value']}')
                .toList()
              ..sort())
            .join('\n');

        final a = describe(await fresh.rawQuery('PRAGMA table_info($t)'));
        final b = describe(await migrated.rawQuery('PRAGMA table_info($t)'));
        expect(a, b,
            reason: 'schema for "$t" differs between a fresh install and '
                'an upgraded one. A save that works on one phone will '
                'fail on the other.');
      }
    });

    test('a minimal insert succeeds on both', () async {
      // Mirrors the leanest row the app can write. On a fresh v1.0.0
      // install this failed while working fine on upgraded phones.
      for (final db in [fresh, migrated]) {
        await db.insert('feed_records', {
          'id': 'f-min',
          'batchId': 'All',
          'kgPerBag': 50.0,
        });
        await db.insert('egg_production', {
          'id': 'e-min',
          'batchId': 'All',
          'date': '2026-07-20T00:00:00.000',
        });
        expect(
            (await db.query('feed_records', where: 'id = ?', whereArgs: ['f-min']))
                .length,
            1);
        expect(
            (await db.query('egg_production', where: 'id = ?', whereArgs: ['e-min']))
                .length,
            1);
      }
    });
  });

  group('upgrade is data-preserving from every shipped version', () {
    // A farmer may skip releases. Every historical version must land on
    // v11 with its rows intact, not just the newest one.
    for (final from in [7, 8, 9, 10, 11, 12]) {
      test('v$from to current keeps the farmer\'s rows', () async {
        final legacy = await _createV7Database(dbPath);
        await _seedFarmData(legacy);
        // Walk the real upgrade path up to `from`, then close and let
        // the production opener finish the journey to v11.
        if (from > 7) {
          await legacy.close();
          final partial = await databaseFactory.openDatabase(
            dbPath,
            options: OpenDatabaseOptions(
              version: from,
              onUpgrade: (db, o, n) =>
                  DatabaseService.instance.runUpgradeForTest(db, o, n),
            ),
          );
          await partial.close();
        } else {
          await legacy.close();
        }

        final db = await DatabaseService.instance.openAt(dbPath);
        addTearDown(db.close);

        expect(await db.getVersion(), DatabaseService.schemaVersion);
        expect((await db.query('batches')).length, 1);
        expect((await db.query('egg_production')).single['eggCount'], 420);
        expect((await db.query('financial_transactions')).single['amount'],
            4500.0);
      });
    }
  });
}
