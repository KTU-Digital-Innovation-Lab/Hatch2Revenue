import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'database_service.dart';

/// Local database backup & restore. Until cloud sync is enabled, the
/// phone's SQLite file is the farmer's ONLY copy of their records —
/// this is the safety net.
class BackupService {
  static Future<String> _dbPath() async {
    final dir = await getDatabasesPath();
    return p.join(dir, 'hatch2revenue.db');
  }

  /// Copies the database to a timestamped file and opens the system
  /// share sheet (WhatsApp, Drive, email, USB...).
  static Future<void> shareBackup() async {
    final src = File(await _dbPath());
    if (!await src.exists()) {
      throw Exception('No data to back up yet.');
    }
    // Checkpoint any WAL pages into the main file before copying.
    final db = await DatabaseService.instance.database;
    await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');

    final stamp = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
    final tmpDir = await getTemporaryDirectory();
    final copy = await src.copy(
      p.join(tmpDir.path, 'hatch2revenue_backup_$stamp.db'),
    );

    await SharePlus.instance.share(ShareParams(
      files: [XFile(copy.path)],
      subject: 'Hatch2Revenue backup $stamp',
      text: 'Hatch2Revenue farm data backup ($stamp). '
          'Keep this file safe — it contains all your records.',
    ));
  }

  /// Replaces the current database with a picked backup file.
  /// Returns true when a restore actually happened. The caller must
  /// reload all providers afterwards.
  static Future<bool> restoreFromFile() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Select a Hatch2Revenue backup (.db)',
      type: FileType.any,
    );
    final picked = result?.files.single.path;
    if (picked == null) return false;

    final pickedFile = File(picked);
    // Sanity check: must be an SQLite database, not a random file.
    final header = await pickedFile.openRead(0, 16).first;
    final magic = String.fromCharCodes(header.take(15));
    if (magic != 'SQLite format 3') {
      throw Exception('That file is not a Hatch2Revenue backup.');
    }

    final dest = await _dbPath();

    // Keep the current data as a safety copy before overwriting.
    final current = File(dest);
    if (await current.exists()) {
      await current.copy('$dest.pre-restore');
    }

    await DatabaseService.instance.close();
    await pickedFile.copy(dest);
    // Remove stale WAL/journal files from the previous database.
    for (final suffix in ['-wal', '-shm', '-journal']) {
      final f = File('$dest$suffix');
      if (await f.exists()) await f.delete();
    }
    // Next access reopens (and migrates the backup forward if it came
    // from an older app version).
    await DatabaseService.instance.database;
    return true;
  }
}
