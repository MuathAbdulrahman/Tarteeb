import 'package:flutter_test/flutter_test.dart';
import 'package:tarteeb/core/day.dart';
import 'package:tarteeb/core/money.dart';
import 'package:tarteeb/domain/finance_logic.dart';
import 'package:tarteeb/domain/finance_models.dart';
import 'package:tarteeb/domain/habit_logic.dart';
import 'package:tarteeb/domain/habit_models.dart';
import 'package:tarteeb/domain/task_logic.dart';
import 'package:tarteeb/domain/task_models.dart';
import 'package:tarteeb/notifications/reminder_planner.dart';

int ms(int y, int m, int d, [int h = 12, int mi = 0]) => DateTime(y, m, d, h, mi).millisecondsSinceEpoch;

FinTxn tx(TxnType type, int amount,
    {String currency = 'SAR',
    TxnStatus status = TxnStatus.confirmed,
    int? at,
    String merchant = '',
    int? id,
    int? sar,
    bool? countOverride}) {
  return FinTxn(
    id: id,
    source: TxnSource.sms,
    status: status,
    type: type,
    amountMinor: amount,
    currency: currency,
    sarAmountMinor: sar,
    merchant: merchant,
    txnAt: at ?? ms(2024, 10, 10),
    tsSource: TimestampSource.message,
    countOverride: countOverride,
    createdAt: 0,
    updatedAt: 0,
  );
}

void main() {
  group('money', () {
    test('parse amounts into integer minor units', () {
      expect(parseAmountToMinor('1,234.50', 'SAR'), 123450);
      expect(parseAmountToMinor('1234.5', 'SAR'), 123450);
      expect(parseAmountToMinor('12,5', 'SAR'), 1250);
      expect(parseAmountToMinor('1.234,56', 'EUR'), 123456);
      expect(parseAmountToMinor('0.1', 'SAR'), 10);
      expect(parseAmountToMinor('12.250', 'KWD'), 12250);
      expect(parseAmountToMinor('100', 'JPY'), 100);
      expect(parseAmountToMinor('abc', 'SAR'), isNull);
    });

    test('0.1 + 0.2 is exact', () {
      final a = parseAmountToMinor('0.1', 'SAR')!;
      final b = parseAmountToMinor('0.2', 'SAR')!;
      expect(formatMinorNumber(a + b, 'SAR'), '0.30');
    });

    test('formatting', () {
      expect(formatMinorNumber(123456789, 'SAR'), '1,234,567.89');
      expect(formatMinorNumber(-500, 'SAR'), '-5.00');
      expect(minorToEditable(123450, 'SAR'), '1234.50');
    });
  });

  group('finance totals', () {
    final range = DayRange(const Day(2024, 10, 1), const Day(2024, 10, 31));

    test('purchases and fees count; transfers, ATM, card payments and income do not', () {
      final s = summarize([
        tx(TxnType.cardPurchase, 10000),
        tx(TxnType.onlinePurchase, 5000),
        tx(TxnType.bankFee, 300),
        tx(TxnType.transferOut, 70000),
        tx(TxnType.atmWithdrawal, 20000),
        tx(TxnType.cardPayment, 250000),
        tx(TxnType.income, 1500000),
        tx(TxnType.transferIn, 1000),
      ], range);
      expect(s.gross.of('SAR'), 15300);
      expect(s.transfersOut.of('SAR'), 70000);
      expect(s.atm.of('SAR'), 20000);
      expect(s.cardPayments.of('SAR'), 250000);
      expect(s.income.of('SAR'), 1500000);
      expect(s.netOf('SAR'), 15300);
    });

    test('refund is shown separately and subtracted once from net', () {
      final s = summarize([tx(TxnType.cardPurchase, 10000), tx(TxnType.refund, 2500)], range);
      expect(s.gross.of('SAR'), 10000);
      expect(s.refunds.of('SAR'), 2500);
      expect(s.netOf('SAR'), 7500);
    });

    test('items needing review are excluded from totals', () {
      final s = summarize([
        tx(TxnType.cardPurchase, 10000),
        tx(TxnType.cardPurchase, 99900, status: TxnStatus.needsReview),
      ], range);
      expect(s.gross.of('SAR'), 10000);
      expect(s.reviewCount, 1);
    });

    test('currencies are never mixed; SAR equivalent is used when present', () {
      final s = summarize([
        tx(TxnType.cardPurchase, 10000),
        tx(TxnType.onlinePurchase, 2000, currency: 'USD'),
        tx(TxnType.onlinePurchase, 1000, currency: 'USD', sar: 3750),
      ], range);
      expect(s.gross.of('SAR'), 13750);
      expect(s.gross.of('USD'), 2000);
      expect(s.foreignCurrencies, {'USD'});
    });

    test('user override can include a transfer as spending', () {
      final s = summarize([tx(TxnType.transferOut, 4000, countOverride: true)], range);
      expect(s.gross.of('SAR'), 4000);
    });

    test('range boundaries', () {
      final s = summarize([
        tx(TxnType.cardPurchase, 100, at: ms(2024, 9, 30, 23, 59)),
        tx(TxnType.cardPurchase, 200, at: ms(2024, 10, 1, 0, 0)),
        tx(TxnType.cardPurchase, 400, at: ms(2024, 10, 31, 23, 59)),
        tx(TxnType.cardPurchase, 800, at: ms(2024, 11, 1, 0, 0)),
      ], range);
      expect(s.gross.of('SAR'), 600);
    });
  });

  group('duplicates and refund linking', () {
    test('two legitimate purchases with the same amount at different times are not duplicates', () {
      final a = tx(TxnType.cardPurchase, 1500, id: 1, merchant: 'Cafe', at: ms(2024, 10, 10, 9, 0));
      final b = tx(TxnType.cardPurchase, 1500, merchant: 'Cafe', at: ms(2024, 10, 10, 9, 20));
      expect(checkDuplicate(b, [a]).kind, DuplicateKind.none);
    });

    test('same message key is an exact duplicate', () {
      final a = tx(TxnType.cardPurchase, 1500, id: 1)..sourceKey = 's:abc';
      final b = tx(TxnType.cardPurchase, 1500)..sourceKey = 's:abc';
      expect(checkDuplicate(b, [a]).kind, DuplicateKind.exact);
    });

    test('same bank reference is an exact duplicate', () {
      final a = tx(TxnType.cardPurchase, 1500, id: 1)..reference = 'REF123456';
      final b = tx(TxnType.cardPurchase, 1500)..reference = 'ref123456';
      expect(checkDuplicate(b, [a]).kind, DuplicateKind.exact);
    });

    test('two alerts for one purchase without bank times -> possible duplicate (reviewable)', () {
      final a = tx(TxnType.cardPurchase, 1500, id: 1, merchant: 'Cafe')
        ..tsSource = TimestampSource.smsFallback
        ..smsAt = ms(2024, 10, 10, 9, 0);
      final b = tx(TxnType.cardPurchase, 1500, merchant: 'CAFE')
        ..tsSource = TimestampSource.smsFallback
        ..smsAt = ms(2024, 10, 10, 9, 1);
      final r = checkDuplicate(b, [a]);
      expect(r.kind, DuplicateKind.possible);
      expect(r.matchId, 1);
    });

    test('refund links only with sufficient evidence', () {
      final p1 = tx(TxnType.cardPurchase, 5000, id: 1, merchant: 'Noon', at: ms(2024, 10, 1));
      final refund = tx(TxnType.refund, 5000, id: 3, merchant: 'NOON', at: ms(2024, 10, 5));
      expect(findRefundOriginal(refund, [p1, refund]), 1);

      // Two equal candidates -> ambiguous -> no link.
      final p2 = tx(TxnType.cardPurchase, 5000, id: 2, merchant: 'Noon', at: ms(2024, 10, 2));
      expect(findRefundOriginal(refund, [p1, p2, refund]), isNull);

      // Different amount -> no link; original is never modified.
      final partial = tx(TxnType.refund, 1000, id: 4, merchant: 'Noon', at: ms(2024, 10, 5));
      expect(findRefundOriginal(partial, [p1, partial]), isNull);
      expect(p1.amountMinor, 5000);
    });
  });

  group('habits', () {
    HabitWithData habit(Day start, int mask, Set<Day> done, {List<HabitSchedule>? schedules}) {
      final h = Habit(id: 1, name: 'h', icon: 'check', color: 0, startDate: start, createdAt: 0);
      return HabitWithData(h, schedules ?? [HabitSchedule(habitId: 1, effectiveFrom: start, weekdayMask: mask)], done);
    }

    const start = Day(2024, 10, 1); // Tuesday

    test('daily streak, unfinished today does not break it', () {
      final h = habit(start, kAllWeekdaysMask, {const Day(2024, 10, 1), const Day(2024, 10, 2), const Day(2024, 10, 3)});
      final s = computeHabitStats(h, const Day(2024, 10, 4));
      expect(s.currentStreak, 3);
      expect(s.longestStreak, 3);
      expect(s.totalCompleted, 3);
      expect(s.doneToday, isFalse);
    });

    test('a missed past day breaks the streak', () {
      final h = habit(start, kAllWeekdaysMask, {const Day(2024, 10, 1), const Day(2024, 10, 3)});
      final s = computeHabitStats(h, const Day(2024, 10, 4));
      expect(s.currentStreak, 1);
      expect(s.longestStreak, 1);
    });

    test('unscheduled days do not break the streak', () {
      // Sunday, Tuesday, Thursday.
      const mask = (1 << 0) | (1 << 2) | (1 << 4);
      final h = habit(start, mask, {const Day(2024, 10, 1), const Day(2024, 10, 3), const Day(2024, 10, 6)});
      final s = computeHabitStats(h, const Day(2024, 10, 7));
      expect(s.currentStreak, 3);
    });

    test('future and duplicate completions are rejected', () {
      final h = habit(start, kAllWeekdaysMask, {const Day(2024, 10, 1)});
      const today = Day(2024, 10, 2);
      expect(validateCompletion(h, const Day(2024, 10, 3), today), CompletionError.future);
      expect(validateCompletion(h, const Day(2024, 10, 1), today), CompletionError.duplicate);
      expect(validateCompletion(h, const Day(2024, 9, 30), today), CompletionError.beforeStart);
      expect(validateCompletion(h, today, today), isNull);
    });

    test('schedule change applies prospectively', () {
      // Daily until Oct 5, then Sundays only.
      final h = habit(start, kAllWeekdaysMask, {}, schedules: [
        HabitSchedule(habitId: 1, effectiveFrom: start, weekdayMask: kAllWeekdaysMask),
        HabitSchedule(habitId: 1, effectiveFrom: const Day(2024, 10, 5), weekdayMask: 1),
      ]);
      expect(isScheduledOn(h, const Day(2024, 10, 3)), isTrue); // Thursday, old schedule
      expect(isScheduledOn(h, const Day(2024, 10, 8)), isFalse); // Tuesday, new schedule
      expect(isScheduledOn(h, const Day(2024, 10, 6)), isTrue); // Sunday
    });
  });

  group('tasks', () {
    TaskItem t(int id, {Day? due, Day? follow, bool done = false}) => TaskItem(
          id: id,
          title: 't$id',
          dueDate: due,
          followUpDate: follow,
          status: done ? TaskStatus.completed : TaskStatus.notStarted,
          createdAt: id,
          updatedAt: id,
        );

    const today = Day(2024, 10, 12);

    test('sections; undated tasks are never overdue; follow-up never makes overdue', () {
      final g = groupTasks([
        t(1, due: const Day(2024, 10, 10)),
        t(2, due: today),
        t(3, due: const Day(2024, 10, 20)),
        t(4),
        t(5, follow: const Day(2024, 10, 1)),
        t(6, due: const Day(2024, 10, 1), done: true),
      ], today, const TaskFilter(), TaskSort.manual);
      expect(g[TaskSection.overdue]!.map((e) => e.id), [1]);
      expect(g[TaskSection.today]!.map((e) => e.id), [2]);
      expect(g[TaskSection.upcoming]!.map((e) => e.id), [3]);
      expect(g[TaskSection.noDate]!.map((e) => e.id), [4, 5]);
      expect(g[TaskSection.completed]!.map((e) => e.id), [6]);
    });

    test('calendar: separate due and follow-up dates show on both days; same day shows once', () {
      final a = t(1, due: const Day(2024, 10, 15), follow: const Day(2024, 10, 13));
      final b = t(2, due: const Day(2024, 10, 15), follow: const Day(2024, 10, 15));
      final d13 = entriesForDay(const Day(2024, 10, 13), [a, b], []);
      final d15 = entriesForDay(const Day(2024, 10, 15), [a, b], []);
      expect(d13.tasks.length, 1);
      expect(d13.tasks.first.isFollowUp, isTrue);
      expect(d13.tasks.first.isDue, isFalse);
      expect(d15.tasks.length, 2);
      final bEntry = d15.tasks.firstWhere((e) => e.task.id == 2);
      expect(bEntry.isDue && bEntry.isFollowUp, isTrue);
    });

    test('search covers subtasks and notes', () {
      final x = t(1)
        ..notes = 'call the vendor'
        ..subtasks = [Subtask(taskId: 1, title: 'prepare invoice', sortOrder: 0)];
      expect(const TaskFilter(query: 'invoice').matches(x), isTrue);
      expect(const TaskFilter(query: 'VENDOR').matches(x), isTrue);
      expect(const TaskFilter(query: 'zzz').matches(x), isFalse);
    });
  });

  group('reminders', () {
    test('completed or past reminders are cancelled; future ones scheduled', () {
      final now = DateTime(2024, 10, 12, 10);
      final future = TaskItem(id: 1, title: 'a', reminderAt: ms(2024, 10, 12, 11), createdAt: 0, updatedAt: 0);
      final past = TaskItem(id: 2, title: 'b', reminderAt: ms(2024, 10, 12, 9), createdAt: 0, updatedAt: 0);
      final done = TaskItem(
          id: 3, title: 'c', reminderAt: ms(2024, 10, 12, 11), status: TaskStatus.completed, createdAt: 0, updatedAt: 0);
      final specs = planReminders(
        tasks: [future, past, done],
        habits: [],
        taskReminders: true,
        habitReminders: true,
        now: now,
        taskBody: (_) => '',
        habitBody: (_) => '',
      );
      expect(specs.map((e) => e.id), [taskReminderId(1)]);

      // Rescheduling = new time in the next full sync.
      future.reminderAt = ms(2024, 10, 13, 8);
      final again = planReminders(
        tasks: [future],
        habits: [],
        taskReminders: true,
        habitReminders: true,
        now: now,
        taskBody: (_) => '',
        habitBody: (_) => '',
      );
      expect(again.single.at, ms(2024, 10, 13, 8));

      // Disabled setting removes all task reminders.
      expect(
          planReminders(
            tasks: [future],
            habits: [],
            taskReminders: false,
            habitReminders: true,
            now: now,
            taskBody: (_) => '',
            habitBody: (_) => '',
          ),
          isEmpty);
    });

    test('habit reminder skips today once completed', () {
      final now = DateTime(2024, 10, 12, 10);
      const today = Day(2024, 10, 12);
      final h = HabitWithData(
        Habit(id: 5, name: 'read', icon: 'book', color: 0, startDate: const Day(2024, 10, 1), reminderMinutes: 20 * 60, createdAt: 0),
        [HabitSchedule(habitId: 5, effectiveFrom: const Day(2024, 10, 1), weekdayMask: kAllWeekdaysMask)],
        {today},
      );
      final specs = planReminders(
        tasks: [],
        habits: [h],
        taskReminders: true,
        habitReminders: true,
        now: now,
        taskBody: (_) => '',
        habitBody: (_) => '',
      );
      expect(specs.single.kind, 'weekly');
      expect(specs.single.skipUntil, today.addDays(1).startLocal.millisecondsSinceEpoch);
    });
  });
}
