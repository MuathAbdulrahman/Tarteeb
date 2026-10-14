import 'package:sqflite/sqflite.dart';

import '../core/day.dart';
import '../domain/finance_logic.dart';
import '../domain/finance_models.dart';
import '../sms/normalizer.dart';

List<ExpenseCategory> defaultExpenseCategories() => [
      ExpenseCategory(nameKey: 'food', icon: 'food', color: 0xFFE07A3F, sortOrder: 0),
      ExpenseCategory(nameKey: 'groceries', icon: 'groceries', color: 0xFF4F9D5D, sortOrder: 1),
      ExpenseCategory(nameKey: 'transport', icon: 'transport', color: 0xFF3B7DD8, sortOrder: 2),
      ExpenseCategory(nameKey: 'shopping', icon: 'shopping', color: 0xFFB45AC2, sortOrder: 3),
      ExpenseCategory(nameKey: 'bills', icon: 'bills', color: 0xFF5C6BC0, sortOrder: 4),
      ExpenseCategory(nameKey: 'entertainment', icon: 'entertainment', color: 0xFFD8556B, sortOrder: 5),
      ExpenseCategory(nameKey: 'health', icon: 'health', color: 0xFF2E9E8F, sortOrder: 6),
      ExpenseCategory(nameKey: 'other', icon: 'other', color: 0xFF7D8794, sortOrder: 7),
    ];

class FinanceRepo {
  final Database db;
  FinanceRepo(this.db);

  int _now() => AppClock.now().millisecondsSinceEpoch;

  // ---- meta ----
  Future<String?> meta(String key) async {
    final r = await db.query('fin_meta', where: 'key = ?', whereArgs: [key]);
    return r.isEmpty ? null : r.first['value'] as String?;
  }

  Future<void> setMeta(String key, String value) async {
    await db.insert('fin_meta', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---- categories ----
  Future<void> seedIfEmpty() async {
    final n = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM expense_categories')) ?? 0;
    if (n > 0) return;
    final b = db.batch();
    for (final c in defaultExpenseCategories()) {
      b.insert('expense_categories', c.toMap()..remove('id'));
    }
    await b.commit(noResult: true);
  }

  Future<List<ExpenseCategory>> categories() async =>
      (await db.query('expense_categories', orderBy: 'sort_order, id')).map(ExpenseCategory.fromMap).toList();

  Future<void> insertCategory(ExpenseCategory c) async {
    final maxOrder =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COALESCE(MAX(sort_order), -1) FROM expense_categories')) ?? -1;
    c.sortOrder = maxOrder + 1;
    c.id = await db.insert('expense_categories', c.toMap()..remove('id'));
  }

  Future<void> updateCategory(ExpenseCategory c) async {
    await db.update('expense_categories', c.toMap()..remove('id'), where: 'id = ?', whereArgs: [c.id]);
  }

  Future<void> deleteCategory(int id) async {
    await db.delete('expense_categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> reorderCategories(List<int> ids) async {
    final b = db.batch();
    for (var i = 0; i < ids.length; i++) {
      b.update('expense_categories', {'sort_order': i}, where: 'id = ?', whereArgs: [ids[i]]);
    }
    await b.commit(noResult: true);
  }

  // ---- merchant rules ----
  Future<List<MerchantRule>> rules() async =>
      (await db.query('merchant_rules', orderBy: 'id')).map(MerchantRule.fromMap).toList();

  Future<void> insertRule(MerchantRule r) async {
    r.id = await db.insert('merchant_rules', r.toMap()..remove('id'));
  }

  Future<void> deleteRule(int id) async {
    await db.delete('merchant_rules', where: 'id = ?', whereArgs: [id]);
  }

  /// Category from the first rule whose pattern appears in the merchant name.
  static int? categoryFromRules(String merchant, List<MerchantRule> rules) {
    final m = normalizeMerchant(merchant);
    if (m.isEmpty) return null;
    for (final r in rules) {
      final p = normalizeMerchant(foldString(r.pattern));
      if (p.isNotEmpty && m.contains(p)) return r.categoryId;
    }
    return null;
  }

  // ---- transactions ----
  Future<List<FinTxn>> allTxns() async =>
      (await db.query('fin_txns', orderBy: 'txn_at DESC, id DESC')).map(FinTxn.fromMap).toList();

  Future<FinTxn?> getTxn(int id) async {
    final r = await db.query('fin_txns', where: 'id = ?', whereArgs: [id]);
    return r.isEmpty ? null : FinTxn.fromMap(r.first);
  }

  /// Existing rows that could duplicate a new item.
  Future<List<FinTxn>> nearby(DatabaseExecutor ex, FinTxn c) async {
    const window = 3 * 24 * 60 * 60 * 1000;
    final t = c.smsAt ?? c.txnAt;
    final rows = await ex.query(
      'fin_txns',
      where: '(txn_at BETWEEN ? AND ?) OR (sms_at BETWEEN ? AND ?) OR (source_key != \'\' AND source_key = ?) '
          'OR (body_key != \'\' AND body_key = ?) OR (reference != \'\' AND reference = ?)',
      whereArgs: [
        c.txnAt - window,
        c.txnAt + window,
        t - window,
        t + window,
        c.sourceKey,
        c.bodyKey,
        c.reference,
      ],
    );
    return rows.map(FinTxn.fromMap).toList();
  }

  Future<int> insertTxn(DatabaseExecutor ex, FinTxn t) async {
    t.id = await ex.insert('fin_txns', t.toMap()..remove('id'));
    return t.id!;
  }

  Future<void> updateTxn(FinTxn t) async {
    t.updatedAt = _now();
    await db.update('fin_txns', t.toMap()..remove('id'), where: 'id = ?', whereArgs: [t.id]);
  }

  /// Deletes a transaction. SMS-derived items get an ignore marker so routine
  /// rescans do not recreate them.
  Future<void> deleteTxn(FinTxn t, {bool ignoreSource = true}) async {
    await db.transaction((tx) async {
      if (ignoreSource && t.source == TxnSource.sms) {
        for (final key in ignoreKeysFor(t)) {
          await tx.insert('ignored_sources', {'source_key': key, 'created_at': _now()},
              conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
      await tx.update('fin_txns', {'linked_txn_id': null}, where: 'linked_txn_id = ?', whereArgs: [t.id]);
      await tx.update('fin_txns', {'duplicate_of_id': null}, where: 'duplicate_of_id = ?', whereArgs: [t.id]);
      await tx.delete('fin_txns', where: 'id = ?', whereArgs: [t.id]);
    });
  }

  /// Ignore markers: the source key plus a body key bucketed to 10 minutes,
  /// so the same message read back from the inbox is also recognised.
  static List<String> ignoreKeysFor(FinTxn t) {
    final keys = <String>[];
    if (t.sourceKey.isNotEmpty) keys.add(t.sourceKey);
    if (t.bodyKey.isNotEmpty) {
      final bucket = (t.smsAt ?? t.txnAt) ~/ 600000;
      keys.add('b:${t.bodyKey}:$bucket');
    }
    return keys;
  }

  static List<String> ignoreLookupKeys(FinTxn t) {
    final keys = <String>[];
    if (t.sourceKey.isNotEmpty) keys.add(t.sourceKey);
    if (t.bodyKey.isNotEmpty) {
      final bucket = (t.smsAt ?? t.txnAt) ~/ 600000;
      for (final b in [bucket - 1, bucket, bucket + 1]) {
        keys.add('b:${t.bodyKey}:$b');
      }
    }
    return keys;
  }

  Future<bool> isIgnored(DatabaseExecutor ex, FinTxn t) async {
    final keys = ignoreLookupKeys(t);
    if (keys.isEmpty) return false;
    final placeholders = List.filled(keys.length, '?').join(',');
    final r = await ex.rawQuery('SELECT 1 FROM ignored_sources WHERE source_key IN ($placeholders) LIMIT 1', keys);
    return r.isNotEmpty;
  }

  /// Removes all financial records (transactions, ignore markers, rules,
  /// custom categories, scan state) and restores default categories.
  /// Tasks and habits live in another database and are untouched.
  Future<void> deleteAllFinancialData() async {
    await db.transaction((tx) async {
      await tx.delete('fin_txns');
      await tx.delete('ignored_sources');
      await tx.delete('merchant_rules');
      await tx.delete('expense_categories');
      await tx.delete('fin_meta');
    });
    await db.execute('VACUUM');
    await seedIfEmpty();
  }
}
