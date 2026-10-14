import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Two SQLite files:
///  * `tarteeb.db` - tasks, habits, settings (included in JSON backups).
///  * `finance.db` - transactions and expense setup. Kept separate so it can be
///    excluded from platform backups and deleted without touching tasks/habits.
class AppDatabase {
  final Database main;
  final Database fin;

  AppDatabase._(this.main, this.fin);

  static const mainFile = 'tarteeb.db';
  static const finFile = 'finance.db';

  static Future<AppDatabase> open({DatabaseFactory? factory, String? directory, bool inMemory = false}) async {
    final f = factory ?? databaseFactory;
    final dir = directory ?? await f.getDatabasesPath();
    final mainPath = inMemory ? inMemoryDatabasePath : p.join(dir, mainFile);
    final finPath = inMemory ? inMemoryDatabasePath : p.join(dir, finFile);
    final main = await f.openDatabase(
      mainPath,
      options: OpenDatabaseOptions(
        version: 1,
        singleInstance: !inMemory,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, v) async => _createMain(db),
      ),
    );
    final fin = await f.openDatabase(
      finPath,
      options: OpenDatabaseOptions(
        version: 1,
        singleInstance: !inMemory,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, v) async => _createFin(db),
      ),
    );
    return AppDatabase._(main, fin);
  }

  Future<void> close() async {
    await main.close();
    await fin.close();
  }

  static Future<void> _createMain(Database db) async {
    final b = db.batch();
    b.execute('CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT)');
    b.execute('''
      CREATE TABLE task_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name_key TEXT,
        name TEXT,
        color INTEGER NOT NULL,
        sort_order INTEGER NOT NULL
      )''');
    b.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        category_id INTEGER REFERENCES task_categories(id) ON DELETE SET NULL,
        notes TEXT NOT NULL DEFAULT '',
        priority TEXT NOT NULL,
        status TEXT NOT NULL,
        status_before_complete TEXT,
        due_date TEXT,
        due_minutes INTEGER,
        reminder_at INTEGER,
        follow_up_date TEXT,
        waiting_on TEXT NOT NULL DEFAULT '',
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        completed_at INTEGER,
        is_demo INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER
      )''');
    b.execute('''
      CREATE TABLE subtasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        done INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0
      )''');
    b.execute('''
      CREATE TABLE task_updates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
        body TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )''');
    b.execute('''
      CREATE TABLE task_activity (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
        kind TEXT NOT NULL,
        detail TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL
      )''');
    b.execute('''
      CREATE TABLE habits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        color INTEGER NOT NULL,
        start_date TEXT NOT NULL,
        reminder_minutes INTEGER,
        sort_order INTEGER NOT NULL DEFAULT 0,
        archived INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        is_demo INTEGER NOT NULL DEFAULT 0
      )''');
    b.execute('''
      CREATE TABLE habit_schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        habit_id INTEGER NOT NULL REFERENCES habits(id) ON DELETE CASCADE,
        effective_from TEXT NOT NULL,
        weekday_mask INTEGER NOT NULL,
        UNIQUE(habit_id, effective_from)
      )''');
    b.execute('''
      CREATE TABLE habit_completions (
        habit_id INTEGER NOT NULL REFERENCES habits(id) ON DELETE CASCADE,
        day TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (habit_id, day)
      )''');
    b.execute('CREATE INDEX idx_subtasks_task ON subtasks(task_id)');
    b.execute('CREATE INDEX idx_updates_task ON task_updates(task_id)');
    b.execute('CREATE INDEX idx_activity_task ON task_activity(task_id)');
    await b.commit(noResult: true);
  }

  static Future<void> _createFin(Database db) async {
    final b = db.batch();
    b.execute('CREATE TABLE fin_meta (key TEXT PRIMARY KEY, value TEXT)');
    b.execute('''
      CREATE TABLE expense_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name_key TEXT,
        name TEXT,
        icon TEXT NOT NULL,
        color INTEGER NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0
      )''');
    b.execute('''
      CREATE TABLE merchant_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pattern TEXT NOT NULL,
        category_id INTEGER NOT NULL REFERENCES expense_categories(id) ON DELETE CASCADE
      )''');
    b.execute('''
      CREATE TABLE fin_txns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source TEXT NOT NULL,
        status TEXT NOT NULL,
        type TEXT NOT NULL,
        amount_minor INTEGER,
        currency TEXT NOT NULL,
        sar_amount_minor INTEGER,
        fee_minor INTEGER,
        merchant TEXT NOT NULL DEFAULT '',
        category_id INTEGER REFERENCES expense_categories(id) ON DELETE SET NULL,
        note TEXT NOT NULL DEFAULT '',
        txn_at INTEGER NOT NULL,
        ts_source TEXT NOT NULL,
        sms_at INTEGER,
        sender TEXT NOT NULL DEFAULT '',
        account_last4 TEXT NOT NULL DEFAULT '',
        reference TEXT NOT NULL DEFAULT '',
        confidence INTEGER NOT NULL DEFAULT 100,
        parser_version TEXT NOT NULL DEFAULT '',
        source_key TEXT NOT NULL DEFAULT '',
        body_key TEXT NOT NULL DEFAULT '',
        fingerprint TEXT NOT NULL DEFAULT '',
        duplicate_of_id INTEGER,
        linked_txn_id INTEGER,
        user_edited INTEGER NOT NULL DEFAULT 0,
        count_override INTEGER,
        review_reason TEXT NOT NULL DEFAULT '',
        excerpt TEXT NOT NULL DEFAULT '',
        candidates TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )''');
    b.execute('CREATE INDEX idx_txn_at ON fin_txns(txn_at)');
    b.execute('CREATE INDEX idx_txn_source_key ON fin_txns(source_key)');
    b.execute('CREATE INDEX idx_txn_body_key ON fin_txns(body_key)');
    b.execute('''
      CREATE TABLE ignored_sources (
        source_key TEXT PRIMARY KEY,
        created_at INTEGER NOT NULL
      )''');
    await b.commit(noResult: true);
  }
}
