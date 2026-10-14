import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../core/day.dart';
import 'database.dart';

const String kBackupFormat = 'tarteeb-backup';
const int kBackupVersion = 1;

class BackupException implements Exception {
  /// Machine code, localized by the UI: 'not_json', 'wrong_format',
  /// 'newer_version', 'invalid_table:<name>', 'invalid_reference:<name>',
  /// 'duplicate_id:<name>', 'finance_invalid'.
  final String code;
  BackupException(this.code);
  @override
  String toString() => 'BackupException($code)';
}

typedef _Check = bool Function(Object? v);

bool _int(Object? v) => v is int;
bool _intN(Object? v) => v == null || v is int;
bool _str(Object? v) => v is String;
bool _strN(Object? v) => v == null || v is String;
bool _nonEmpty(Object? v) => v is String && v.trim().isNotEmpty;
bool _day(Object? v) => v is String && Day.tryParse(v) != null;
bool _dayN(Object? v) => v == null || _day(v);
bool _b01(Object? v) => v == 0 || v == 1;
bool _minutesN(Object? v) => v == null || (v is int && v >= 0 && v < 1440);
bool _mask(Object? v) => v is int && v >= 1 && v <= 0x7F;
bool _oneOf(Object? v, List<String> allowed) => v is String && allowed.contains(v);

const _priorities = ['normal', 'medium', 'high'];
const _statuses = ['notStarted', 'inProgress', 'waiting', 'completed'];

final Map<String, Map<String, _Check>> _coreSchema = {
  'task_categories': {
    'id': _int,
    'name_key': _strN,
    'name': _strN,
    'color': _int,
    'sort_order': _int,
  },
  'tasks': {
    'id': _int,
    'title': _nonEmpty,
    'category_id': _intN,
    'notes': _str,
    'priority': (v) => _oneOf(v, _priorities),
    'status': (v) => _oneOf(v, _statuses),
    'status_before_complete': (v) => v == null || _oneOf(v, _statuses),
    'due_date': _dayN,
    'due_minutes': _minutesN,
    'reminder_at': _intN,
    'follow_up_date': _dayN,
    'waiting_on': _str,
    'sort_order': _int,
    'created_at': _int,
    'updated_at': _int,
    'completed_at': _intN,
    'is_demo': _b01,
  },
  'subtasks': {'id': _int, 'task_id': _int, 'title': _str, 'done': _b01, 'sort_order': _int},
  'task_updates': {'id': _int, 'task_id': _int, 'body': _str, 'created_at': _int},
  'task_activity': {'id': _int, 'task_id': _int, 'kind': _str, 'detail': _str, 'created_at': _int},
  'habits': {
    'id': _int,
    'name': _nonEmpty,
    'icon': _str,
    'color': _int,
    'start_date': _day,
    'reminder_minutes': _minutesN,
    'sort_order': _int,
    'archived': _b01,
    'created_at': _int,
    'is_demo': _b01,
  },
  'habit_schedules': {'id': _int, 'habit_id': _int, 'effective_from': _day, 'weekday_mask': _mask},
  'habit_completions': {'habit_id': _int, 'day': _day, 'created_at': _int},
};

final Map<String, Map<String, _Check>> _financeSchema = {
  'expense_categories': {
    'id': _int,
    'name_key': _strN,
    'name': _strN,
    'icon': _str,
    'color': _int,
    'sort_order': _int,
  },
  'merchant_rules': {'id': _int, 'pattern': _nonEmpty, 'category_id': _int},
  'fin_txns': {
    'id': _int,
    'source': (v) => _oneOf(v, ['sms', 'manual']),
    'status': (v) => _oneOf(v, ['confirmed', 'needsReview']),
    'type': _nonEmpty,
    'amount_minor': _intN,
    'currency': (v) => v is String && RegExp(r'^[A-Z]{3}$').hasMatch(v),
    'sar_amount_minor': _intN,
    'fee_minor': _intN,
    'merchant': _str,
    'category_id': _intN,
    'note': _str,
    'txn_at': _int,
    'ts_source': _str,
    'sms_at': _intN,
    'sender': _str,
    'account_last4': (v) => v is String && v.length <= 4,
    'reference': _str,
    'confidence': _int,
    'parser_version': _str,
    'source_key': _str,
    'body_key': _str,
    'fingerprint': _str,
    'duplicate_of_id': _intN,
    'linked_txn_id': _intN,
    'user_edited': _b01,
    'count_override': (v) => v == null || _b01(v),
    'review_reason': _str,
    'candidates': _str,
    'created_at': _int,
    'updated_at': _int,
  },
  'ignored_sources': {'source_key': _nonEmpty, 'created_at': _int},
};

List<Map<String, Object?>> _validateTable(Object? raw, String name, Map<String, _Check> schema) {
  if (raw is! List) throw BackupException('invalid_table:$name');
  final out = <Map<String, Object?>>[];
  for (final row in raw) {
    if (row is! Map) throw BackupException('invalid_table:$name');
    final clean = <String, Object?>{};
    for (final e in schema.entries) {
      final v = row[e.key];
      if (!e.value(v)) throw BackupException('invalid_table:$name');
      clean[e.key] = v;
    }
    out.add(clean);
  }
  if (schema.containsKey('id')) {
    final ids = out.map((r) => r['id']).toSet();
    if (ids.length != out.length) throw BackupException('duplicate_id:$name');
  }
  return out;
}

void _checkRefs(List<Map<String, Object?>> rows, String field, Set<Object?> valid, String name, {bool nullable = false}) {
  for (final r in rows) {
    final v = r[field];
    if (v == null && nullable) continue;
    if (!valid.contains(v)) throw BackupException('invalid_reference:$name');
  }
}

class CoreBackup {
  final Map<String, List<Map<String, Object?>>> tables;
  final Map<String, Object?>? financeEnvelope;
  final String createdAt;
  CoreBackup(this.tables, this.financeEnvelope, this.createdAt);

  int count(String table) => tables[table]?.length ?? 0;
}

class FinanceBackup {
  final Map<String, List<Map<String, Object?>>> tables;
  FinanceBackup(this.tables);
  int count(String table) => tables[table]?.length ?? 0;
}

/// Versioned JSON backups. Tasks/habits are plain JSON. Financial data is
/// optional, never includes SMS bodies or excerpts, and is only stored
/// encrypted (AES-256-GCM with a password-derived key; see native side).
class BackupService {
  final AppDatabase db;
  BackupService(this.db);

  static const coreTables = [
    'task_categories',
    'tasks',
    'subtasks',
    'task_updates',
    'task_activity',
    'habits',
    'habit_schedules',
    'habit_completions',
  ];
  static const financeTables = ['expense_categories', 'merchant_rules', 'fin_txns', 'ignored_sources'];

  Future<Map<String, Object?>> exportCore() async {
    final data = <String, Object?>{};
    for (final t in coreTables) {
      List<Map<String, Object?>> rows;
      if (t == 'tasks') {
        rows = await db.main.query('tasks', where: 'deleted_at IS NULL');
      } else if (t == 'subtasks' || t == 'task_updates' || t == 'task_activity') {
        rows = await db.main.rawQuery(
            'SELECT x.* FROM $t x JOIN tasks t ON t.id = x.task_id WHERE t.deleted_at IS NULL');
      } else {
        rows = await db.main.query(t);
      }
      final schema = _coreSchema[t]!;
      data[t] = [
        for (final r in rows) {for (final k in schema.keys) k: r[k]}
      ];
    }
    return {
      'format': kBackupFormat,
      'version': kBackupVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'contents': ['tasks', 'habits'],
      'data': data,
    };
  }

  /// Plain finance payload (to be encrypted before it leaves the device).
  Future<String> exportFinancePayload() async {
    final data = <String, Object?>{'version': kBackupVersion};
    for (final t in financeTables) {
      final rows = await db.fin.query(t);
      final schema = _financeSchema[t]!;
      data[t] = [
        for (final r in rows) {for (final k in schema.keys) k: r[k]}
      ];
    }
    return jsonEncode(data);
  }

  /// Parses and fully validates a backup file. Throws [BackupException];
  /// never touches the database.
  static CoreBackup parse(String text) {
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      throw BackupException('not_json');
    }
    if (decoded is! Map) throw BackupException('wrong_format');
    if (decoded['format'] != kBackupFormat) throw BackupException('wrong_format');
    final version = decoded['version'];
    if (version is! int) throw BackupException('wrong_format');
    if (version > kBackupVersion) throw BackupException('newer_version');
    final data = decoded['data'];
    if (data is! Map) throw BackupException('wrong_format');
    final tables = <String, List<Map<String, Object?>>>{};
    for (final t in coreTables) {
      tables[t] = _validateTable(data[t] ?? const [], t, _coreSchema[t]!);
    }
    final catIds = tables['task_categories']!.map((r) => r['id']).toSet();
    final taskIds = tables['tasks']!.map((r) => r['id']).toSet();
    final habitIds = tables['habits']!.map((r) => r['id']).toSet();
    _checkRefs(tables['tasks']!, 'category_id', catIds, 'tasks', nullable: true);
    _checkRefs(tables['subtasks']!, 'task_id', taskIds, 'subtasks');
    _checkRefs(tables['task_updates']!, 'task_id', taskIds, 'task_updates');
    _checkRefs(tables['task_activity']!, 'task_id', taskIds, 'task_activity');
    _checkRefs(tables['habit_schedules']!, 'habit_id', habitIds, 'habit_schedules');
    _checkRefs(tables['habit_completions']!, 'habit_id', habitIds, 'habit_completions');
    final seen = <String>{};
    for (final c in tables['habit_completions']!) {
      if (!seen.add('${c['habit_id']}|${c['day']}')) throw BackupException('duplicate_id:habit_completions');
    }
    Map<String, Object?>? env;
    final fin = decoded['finance'];
    if (fin != null) {
      if (fin is! Map) throw BackupException('finance_invalid');
      env = fin.map((k, v) => MapEntry(k.toString(), v));
    }
    return CoreBackup(tables, env, (decoded['createdAt'] as String?) ?? '');
  }

  static FinanceBackup parseFinance(String text) {
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      throw BackupException('finance_invalid');
    }
    if (decoded is! Map) throw BackupException('finance_invalid');
    final tables = <String, List<Map<String, Object?>>>{};
    try {
      for (final t in financeTables) {
        tables[t] = _validateTable(decoded[t] ?? const [], t, _financeSchema[t]!);
      }
      final catIds = tables['expense_categories']!.map((r) => r['id']).toSet();
      _checkRefs(tables['merchant_rules']!, 'category_id', catIds, 'merchant_rules');
      _checkRefs(tables['fin_txns']!, 'category_id', catIds, 'fin_txns', nullable: true);
    } on BackupException {
      throw BackupException('finance_invalid');
    }
    return FinanceBackup(tables);
  }

  /// Replaces all tasks and habits in one transaction. Any failure rolls back
  /// and leaves current data untouched.
  Future<void> restoreCore(CoreBackup b) async {
    await db.main.transaction((tx) async {
      for (final t in coreTables.reversed) {
        await tx.delete(t);
      }
      for (final t in coreTables) {
        for (final row in b.tables[t]!) {
          await tx.insert(t, row, conflictAlgorithm: ConflictAlgorithm.abort);
        }
      }
    });
  }

  Future<void> restoreFinance(FinanceBackup b) async {
    await db.fin.transaction((tx) async {
      for (final t in financeTables.reversed) {
        await tx.delete(t);
      }
      for (final t in financeTables) {
        for (final row in b.tables[t]!) {
          await tx.insert(t, row, conflictAlgorithm: ConflictAlgorithm.abort);
        }
      }
    });
  }
}
