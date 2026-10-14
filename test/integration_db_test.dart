// Integration tests against real SQLite (sqflite_common_ffi on the host).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tarteeb/core/day.dart';
import 'package:tarteeb/data/backup_service.dart';
import 'package:tarteeb/data/database.dart';
import 'package:tarteeb/domain/finance_models.dart';
import 'package:tarteeb/domain/habit_logic.dart';
import 'package:tarteeb/domain/habit_models.dart';
import 'package:tarteeb/domain/task_models.dart';
import 'package:tarteeb/platform/native_bridge.dart';
import 'package:tarteeb/sms/sms_parser.dart';
import 'package:tarteeb/state/app_state.dart';

import 'fakes.dart';

late Directory tmp;

Future<AppState> openApp(FakeNativeBridge native) async {
  final db = await AppDatabase.open(factory: databaseFactoryFfi, directory: tmp.path);
  final app = AppState(db, native);
  await app.init(resume: false);
  return app;
}

int ms(int y, int m, int d, [int h = 12, int mi = 0]) => DateTime(y, m, d, h, mi).millisecondsSinceEpoch;

RawSms sms(String body, int at, {String sender = 'TestBank', int? sentAt}) =>
    RawSms(sender: sender, body: body, receivedAt: at, sentAt: sentAt ?? at);

void main() {
  sqfliteFfiInit();

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('tarteeb_test');
    AppClock.now = () => DateTime(2024, 10, 12, 10, 0);
  });

  tearDown(() async {
    AppClock.now = DateTime.now;
    await tmp.delete(recursive: true);
  });

  test('tasks, subtasks and completion persist across restart', () async {
    final native = FakeNativeBridge();
    var app = await openApp(native);
    expect(app.taskCategories.length, 3); // Work, Personal, Wishlist

    final t = await app.addTask(TaskItem(
      title: 'Prepare report',
      dueDate: const Day(2024, 10, 15),
      followUpDate: const Day(2024, 10, 13),
      reminderAt: ms(2024, 10, 14, 9),
      createdAt: 0,
      updatedAt: 0,
      subtasks: [
        Subtask(taskId: 0, title: 'collect data', sortOrder: 0),
        Subtask(taskId: 0, title: 'write summary', sortOrder: 1),
      ],
    ));
    expect(native.reminders.length, 1);

    final loaded = app.taskById(t.id!)!;
    await app.setSubtaskDone(loaded, loaded.subtasks.first, true);
    await app.setTaskCompleted(app.taskById(t.id!)!, true, completeSubtasks: true);
    expect(native.reminders, isEmpty, reason: 'completing cancels the reminder');
    await app.addTaskUpdate(t.id!, 'Sent to manager');
    await app.addTaskUpdate(t.id!, 'Manager replied');
    await app.db.close();

    app = await openApp(native);
    final again = app.taskById(t.id!)!;
    expect(again.isCompleted, isTrue);
    expect(again.subtasks.every((s) => s.done), isTrue);
    expect(again.followUpDate, const Day(2024, 10, 13));
    expect(again.dueDate, const Day(2024, 10, 15));
    final updates = await app.taskRepo.updates(t.id!);
    expect(updates.map((u) => u.body), ['Manager replied', 'Sent to manager']);
    final activity = await app.taskRepo.activity(t.id!);
    expect(activity.any((a) => a.kind == ActivityKind.completed), isTrue);

    // Reopen restores the previous status.
    await app.setTaskCompleted(again, false);
    expect(app.taskById(t.id!)!.status, TaskStatus.notStarted);
    await app.db.close();
  });

  test('soft delete and undo', () async {
    final app = await openApp(FakeNativeBridge());
    final t = await app.addTask(TaskItem(title: 'x', createdAt: 0, updatedAt: 0));
    await app.deleteTask(t);
    expect(app.taskById(t.id!), isNull);
    await app.undoDeleteTask(t.id!);
    expect(app.taskById(t.id!), isNotNull);
    await app.db.close();
  });

  test('habit completion rules and prospective schedule change', () async {
    final app = await openApp(FakeNativeBridge());
    await app.addHabit(
      Habit(name: 'Read', icon: 'book', color: 0, startDate: const Day(2024, 10, 1), createdAt: 0),
      kAllWeekdaysMask,
    );
    var h = app.habits.single;
    expect(await app.toggleHabitDay(h, const Day(2024, 10, 13)), CompletionError.future);
    expect(await app.toggleHabitDay(h, const Day(2024, 10, 10)), isNull);
    expect(await app.toggleHabitDay(app.habits.single, const Day(2024, 10, 11)), isNull);
    h = app.habits.single;
    expect(computeHabitStats(h, const Day(2024, 10, 12)).currentStreak, 2);

    // Change to Sundays only from today: Oct 10/11 history stays valid.
    await app.saveHabit(h.habit, 1);
    h = app.habits.single;
    expect(h.schedules.length, 2);
    expect(isScheduledOn(h, const Day(2024, 10, 10)), isTrue);
    expect(isScheduledOn(h, const Day(2024, 10, 15)), isFalse);
    expect(computeHabitStats(h, const Day(2024, 10, 12)).currentStreak, 2);

    // Undo a day.
    await app.toggleHabitDay(h, const Day(2024, 10, 11));
    expect(app.habits.single.completions, {const Day(2024, 10, 10)});
    await app.db.close();
  });

  group('SMS ingest', () {
    final purchase = sms('Purchase of SAR 45.00 at CAFE ONE on 2024-10-10 08:05', ms(2024, 10, 10, 8, 6));
    final purchase2 = sms('Purchase of SAR 45.00 at CAFE ONE on 2024-10-10 08:40', ms(2024, 10, 10, 8, 41));
    final refund = sms('Refund of SAR 45.00 from CAFE ONE on 2024-10-11 10:00', ms(2024, 10, 11, 10, 1));
    final transfer = sms('Outgoing transfer of SAR 1,000.00 to OMAR on 2024-10-11 12:00', ms(2024, 10, 11, 12, 1));
    final otp = sms('Your OTP is 445566 for SAR 45.00 at CAFE ONE', ms(2024, 10, 10, 8, 4));
    final personal = sms('Meet at 7?', ms(2024, 10, 10, 9), sender: '+966500000000');

    test('historical import, re-import without duplicates, same-amount purchases kept', () async {
      final native = FakeNativeBridge()..inbox = [purchase, purchase2, refund, transfer, otp, personal];
      final app = await openApp(native);

      final (cands, scanned) = await app.scanHistory(const Day(2024, 10, 1), const Day(2024, 10, 12), (_) {});
      expect(scanned, 6);
      final report = await app.commitImport(cands, scanned);
      expect(report.saved, 4);
      expect(app.txns.length, 4);

      final purchases = app.txns.where((t) => t.type == TxnType.cardPurchase).toList();
      expect(purchases.length, 2, reason: 'two legitimate purchases with the same amount');
      final r = app.txns.firstWhere((t) => t.type == TxnType.refund);
      expect(r.linkedTxnId, isNull, reason: 'two equal purchases -> refund link is ambiguous');

      // Re-import the same period: nothing new.
      final (cands2, scanned2) = await app.scanHistory(const Day(2024, 10, 1), const Day(2024, 10, 12), (_) {});
      final report2 = await app.commitImport(cands2, scanned2);
      expect(report2.saved, 0);
      expect(report2.duplicates, 4);
      expect(app.txns.length, 4);
      await app.db.close();
    });

    test('receiver delivery + inbox rescan of the same message is saved once', () async {
      final native = FakeNativeBridge()..inbox = [purchase];
      final app = await openApp(native);
      await app.setNewMessageProcessing(true);
      // Broadcast copy delivered twice.
      native.queue.add(QueuedSms('q1', purchase));
      native.queue.add(QueuedSms('q2', purchase));
      await app.processSmsQueue();
      expect(app.txns.length, 1);
      expect(native.queue, isEmpty);
      // Inbox copy (same sentAt) via catch-up.
      await app.finRepo.setMeta('last_scan_at', '${ms(2024, 10, 10, 8)}');
      final rep = await app.catchUpInbox();
      expect(rep!.saved, 0);
      expect(app.txns.length, 1);
      await app.db.close();
    });

    test('user corrections and ignored items survive rescans', () async {
      final native = FakeNativeBridge()..inbox = [purchase, transfer];
      final app = await openApp(native);
      final (c1, s1) = await app.scanHistory(const Day(2024, 10, 1), const Day(2024, 10, 12), (_) {});
      await app.commitImport(c1, s1);

      final p = app.txns.firstWhere((t) => t.type == TxnType.cardPurchase).copy()
        ..merchant = 'Cafe One (edited)'
        ..amountMinor = 4400;
      await app.saveTxn(p);
      final tr = app.txns.firstWhere((t) => t.type == TxnType.transferOut);
      await app.deleteTxn(tr); // ignore

      final (c2, s2) = await app.scanHistory(const Day(2024, 10, 1), const Day(2024, 10, 12), (_) {});
      await app.commitImport(c2, s2);
      expect(app.txns.length, 1);
      expect(app.txns.single.merchant, 'Cafe One (edited)');
      expect(app.txns.single.amountMinor, 4400);
      expect(app.txns.single.userEdited, isTrue);
      await app.db.close();
    });

    test('processing disabled or permission revoked', () async {
      final native = FakeNativeBridge();
      final app = await openApp(native);
      native.queue.add(QueuedSms('q1', purchase));
      await app.processSmsQueue();
      expect(app.txns, isEmpty, reason: 'disabled by default: queue is discarded');

      native.perms = const SmsPermissions(PermState.denied, PermState.denied);
      expect(await app.setNewMessageProcessing(true), isFalse);
      expect(app.settings.smsNewMessages, isFalse);
      // Manual entry still works.
      await app.addManualTxn(FinTxn(
        source: TxnSource.manual,
        status: TxnStatus.confirmed,
        type: TxnType.cardPurchase,
        amountMinor: 1000,
        txnAt: ms(2024, 10, 12),
        tsSource: TimestampSource.manual,
        createdAt: 0,
        updatedAt: 0,
      ));
      expect(app.txns.length, 1);
      await app.db.close();
    });

    test('deleting financial data keeps tasks and habits', () async {
      final native = FakeNativeBridge()..inbox = [purchase];
      final app = await openApp(native);
      await app.addTask(TaskItem(title: 'keep me', createdAt: 0, updatedAt: 0));
      final (c, s) = await app.scanHistory(const Day(2024, 10, 1), const Day(2024, 10, 12), (_) {});
      await app.commitImport(c, s);
      expect(app.txns, isNotEmpty);
      await app.deleteAllFinancialData();
      expect(app.txns, isEmpty);
      expect(app.tasks.single.title, 'keep me');
      expect(app.expenseCategories.length, 8);
      await app.db.close();
    });
  });

  group('backup', () {
    test('round trip restores tasks and habits; finance only when included', () async {
      final native = FakeNativeBridge()..inbox = [sms('Purchase of SAR 12.00 at SHOP', ms(2024, 10, 10))];
      final app = await openApp(native);
      await app.insertDemoData();
      final taskCount = app.tasks.length;
      final habitCount = app.habits.length;
      expect(taskCount, 5);
      expect(habitCount, 4);
      final (c, s) = await app.scanHistory(const Day(2024, 10, 1), const Day(2024, 10, 12), (_) {});
      await app.commitImport(c, s);

      final plain = await app.buildBackup();
      final json = utf8.decode(plain);
      expect(json.contains('fin_txns'), isFalse, reason: 'finance excluded by default');
      expect(json.contains('SHOP'), isFalse);

      final withFin = await app.buildBackup(financePassword: 'password123');
      final core = BackupService.parse(utf8.decode(withFin));
      expect(core.financeEnvelope, isNotNull);
      final fin = await app.decryptFinance(core.financeEnvelope!, 'password123');
      expect(fin!.count('fin_txns'), 1);
      expect(await app.decryptFinance(core.financeEnvelope!, 'wrong'), isNull);

      await app.removeDemoData();
      expect(app.tasks, isEmpty);
      await app.restore(core, null);
      expect(app.tasks.length, taskCount);
      expect(app.habits.length, habitCount);
      expect(app.txns.length, 1, reason: 'finance untouched when not restored');
      await app.db.close();
    });

    test('invalid files are rejected and do not change data', () async {
      final app = await openApp(FakeNativeBridge());
      await app.addTask(TaskItem(title: 'existing', createdAt: 0, updatedAt: 0));
      expect(() => BackupService.parse('not json'), throwsA(isA<BackupException>()));
      expect(() => BackupService.parse('{"format":"other"}'), throwsA(isA<BackupException>()));
      expect(
          () => BackupService.parse(jsonEncode({
                'format': kBackupFormat,
                'version': 99,
                'data': {},
              })),
          throwsA(isA<BackupException>()));
      // Subtask pointing at a missing task.
      final bad = jsonEncode({
        'format': kBackupFormat,
        'version': 1,
        'data': {
          'subtasks': [
            {'id': 1, 'task_id': 42, 'title': 'orphan', 'done': 0, 'sort_order': 0}
          ],
        },
      });
      expect(() => BackupService.parse(bad), throwsA(isA<BackupException>()));
      expect(app.tasks.single.title, 'existing');
      await app.db.close();
    });
  });
}
