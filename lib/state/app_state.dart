import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../core/day.dart';
import '../core/format.dart';
import '../core/money.dart';
import '../core/strings.dart';
import '../data/backup_service.dart';
import '../data/database.dart';
import '../data/demo_data.dart';
import '../data/finance_repo.dart';
import '../data/habit_repo.dart';
import '../data/settings_repo.dart';
import '../data/task_repo.dart';
import '../domain/finance_logic.dart';
import '../domain/finance_models.dart';
import '../domain/habit_logic.dart';
import '../domain/habit_models.dart';
import '../domain/task_models.dart';
import '../notifications/reminder_planner.dart';
import '../platform/native_bridge.dart';
import '../sms/sms_ingest.dart';
import '../sms/sms_parser.dart';

class ImportProgress {
  final int windowsDone;
  final int windowsTotal;
  final int scanned;
  const ImportProgress(this.windowsDone, this.windowsTotal, this.scanned);
  double get fraction => windowsTotal == 0 ? 0.0 : windowsDone / windowsTotal;
}

/// Central app controller. UI widgets listen to it; all writes go through it
/// so reminders and derived state stay consistent.
class AppState extends ChangeNotifier {
  final AppDatabase db;
  final NativeBridge native;
  late final SettingsRepo settingsRepo = SettingsRepo(db.main);
  late final TaskRepo taskRepo = TaskRepo(db.main);
  late final HabitRepo habitRepo = HabitRepo(db.main);
  late final FinanceRepo finRepo = FinanceRepo(db.fin);
  late final SmsIngestService ingest = SmsIngestService(finRepo);
  late final BackupService backup = BackupService(db);

  AppSettings settings = AppSettings();
  List<TaskCategory> taskCategories = [];
  List<TaskItem> tasks = [];
  List<HabitWithData> habits = [];
  List<FinTxn> txns = [];
  List<ExpenseCategory> expenseCategories = [];
  List<MerchantRule> merchantRules = [];
  SmsPermissions smsPerms = const SmsPermissions(PermState.unavailable, PermState.unavailable);
  bool loaded = false;

  StreamSubscription<void>? _smsSub;
  bool _processingQueue = false;

  AppState(this.db, this.native);

  Day get today => Day.today();

  static const _metaLastScan = 'last_scan_at';
  static const _metaHistoryImported = 'history_imported_at';

  Future<void> init({bool resume = true}) async {
    settings = await settingsRepo.load();
    S.setLanguage(settings.language);
    if (settings.firstLaunchAt == 0) {
      settings.firstLaunchAt = AppClock.now().millisecondsSinceEpoch;
      await settingsRepo.save(settings);
    }
    await taskRepo.seedCategoriesIfEmpty();
    await finRepo.seedIfEmpty();
    await taskRepo.purgeDeleted();
    await reloadAll();
    smsPerms = await native.smsPermissions();
    await native.setSmsProcessingEnabled(settings.smsNewMessages && smsPerms.canReceive);
    _smsSub = native.onSmsQueued.listen((_) => processSmsQueue());
    loaded = true;
    notifyListeners();
    if (resume) unawaited(onResumed());
  }

  @override
  void dispose() {
    _smsSub?.cancel();
    super.dispose();
  }

  Future<void> reloadAll() async {
    taskCategories = await taskRepo.categories();
    tasks = await taskRepo.allTasks();
    habits = await habitRepo.all();
    await reloadFinance(notify: false);
    notifyListeners();
  }

  Future<void> reloadFinance({bool notify = true}) async {
    txns = await finRepo.allTxns();
    expenseCategories = await finRepo.categories();
    merchantRules = await finRepo.rules();
    if (notify) notifyListeners();
  }

  /// Called on app start and whenever the app returns to the foreground.
  Future<void> onResumed() async {
    smsPerms = await native.smsPermissions();
    if (settings.smsNewMessages && !smsPerms.canReceive) {
      // Permission revoked in system settings: stop processing.
      await native.setSmsProcessingEnabled(false);
    }
    await processSmsQueue();
    await catchUpInbox();
    await syncReminders();
    notifyListeners();
  }

  // ---------------------------------------------------------------- settings

  Future<void> updateSettings(void Function(AppSettings s) change) async {
    final oldLang = settings.language;
    change(settings);
    await settingsRepo.save(settings);
    if (settings.language != oldLang) S.setLanguage(settings.language);
    await syncReminders();
    notifyListeners();
  }

  // ---------------------------------------------------------------- reminders

  Future<void> syncReminders() async {
    final specs = planReminders(
      tasks: tasks,
      habits: habits,
      taskReminders: settings.taskReminders,
      habitReminders: settings.habitReminders,
      now: AppClock.now(),
      taskBody: (t) => t.dueDate == null ? tr.reminderTaskBody : tr.dueOn(formatDayShort(t.dueDate!)),
      habitBody: (h) => tr.habitReminderBody,
    );
    await native.syncReminders(specs);
  }

  // ---------------------------------------------------------------- tasks

  TaskCategory? categoryById(int? id) {
    if (id == null) return null;
    for (final c in taskCategories) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<TaskItem> addTask(TaskItem t) async {
    await taskRepo.insertTask(t);
    tasks = await taskRepo.allTasks();
    await syncReminders();
    notifyListeners();
    return t;
  }

  Future<void> saveTask(TaskItem edited, TaskItem before) async {
    await taskRepo.updateTask(edited, before);
    tasks = await taskRepo.allTasks();
    await syncReminders();
    notifyListeners();
  }

  Future<void> setTaskCompleted(TaskItem t, bool done, {bool completeSubtasks = false}) async {
    await taskRepo.setCompleted(t, done, completeSubtasks: completeSubtasks);
    tasks = await taskRepo.allTasks();
    await syncReminders();
    notifyListeners();
  }

  Future<void> setSubtaskDone(TaskItem t, Subtask st, bool done) async {
    await taskRepo.setSubtaskDone(t, st, done);
    tasks = await taskRepo.allTasks();
    notifyListeners();
  }

  Future<void> addSubtask(TaskItem t, String title) async {
    await taskRepo.addSubtask(t, title);
    tasks = await taskRepo.allTasks();
    notifyListeners();
  }

  Future<void> reorderSubtasks(TaskItem t, List<Subtask> ordered) async {
    await taskRepo.reorderSubtasks(ordered);
    tasks = await taskRepo.allTasks();
    notifyListeners();
  }

  Future<void> reorderTasks(List<int> ids) async {
    await taskRepo.reorderTasks(ids);
    tasks = await taskRepo.allTasks();
    notifyListeners();
  }

  /// Soft delete; [undoDeleteTask] restores it. Purged on next start.
  Future<void> deleteTask(TaskItem t) async {
    await taskRepo.softDelete(t.id!);
    tasks = await taskRepo.allTasks();
    await syncReminders();
    notifyListeners();
  }

  Future<void> undoDeleteTask(int id) async {
    await taskRepo.restore(id);
    tasks = await taskRepo.allTasks();
    await syncReminders();
    notifyListeners();
  }

  Future<void> addTaskUpdate(int taskId, String body) async {
    await taskRepo.addUpdate(taskId, body);
    tasks = await taskRepo.allTasks();
    notifyListeners();
  }

  TaskItem? taskById(int id) {
    for (final t in tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  Future<void> addTaskCategory(String name, int color) async {
    await taskRepo.insertCategory(TaskCategory(name: name, color: color, sortOrder: 0));
    taskCategories = await taskRepo.categories();
    notifyListeners();
  }

  Future<void> updateTaskCategory(TaskCategory c) async {
    await taskRepo.updateCategory(c);
    taskCategories = await taskRepo.categories();
    notifyListeners();
  }

  Future<void> deleteTaskCategory(int id) async {
    await taskRepo.deleteCategory(id);
    taskCategories = await taskRepo.categories();
    tasks = await taskRepo.allTasks();
    notifyListeners();
  }

  Future<void> reorderTaskCategories(List<int> ids) async {
    await taskRepo.reorderCategories(ids);
    taskCategories = await taskRepo.categories();
    notifyListeners();
  }

  // ---------------------------------------------------------------- habits

  Future<void> addHabit(Habit h, int mask) async {
    await habitRepo.insert(h, mask);
    habits = await habitRepo.all();
    await syncReminders();
    notifyListeners();
  }

  Future<void> saveHabit(Habit h, int mask) async {
    await habitRepo.update(h, mask, today: today);
    habits = await habitRepo.all();
    await syncReminders();
    notifyListeners();
  }

  Future<void> deleteHabit(int id) async {
    await habitRepo.delete(id);
    habits = await habitRepo.all();
    await syncReminders();
    notifyListeners();
  }

  Future<void> setHabitArchived(int id, bool archived) async {
    await habitRepo.setArchived(id, archived);
    habits = await habitRepo.all();
    await syncReminders();
    notifyListeners();
  }

  HabitWithData? habitById(int id) {
    for (final h in habits) {
      if (h.habit.id == id) return h;
    }
    return null;
  }

  /// Toggles completion for [day]. Returns an error when completing is not allowed.
  Future<CompletionError?> toggleHabitDay(HabitWithData h, Day day) async {
    if (h.completions.contains(day)) {
      await habitRepo.removeCompletion(h.habit.id!, day);
    } else {
      final err = validateCompletion(h, day, today);
      if (err != null) return err;
      await habitRepo.addCompletion(h.habit.id!, day);
    }
    habits = await habitRepo.all();
    await syncReminders();
    notifyListeners();
    return null;
  }

  // ---------------------------------------------------------------- demo

  Future<void> insertDemoData() async {
    if (settings.demoInserted) return;
    final base = Day.fromDateTime(DateTime.fromMillisecondsSinceEpoch(settings.firstLaunchAt));
    await DemoData.insert(tasks: taskRepo, habits: habitRepo, base: base, arabic: settings.language == 'ar');
    settings.demoInserted = true;
    await settingsRepo.save(settings);
    await reloadAll();
    await syncReminders();
  }

  Future<void> removeDemoData() async {
    await DemoData.remove(tasks: taskRepo, habits: habitRepo);
    await reloadAll();
    await syncReminders();
  }

  bool get hasDemoData => tasks.any((t) => t.isDemo) || habits.any((h) => h.habit.isDemo);

  // ---------------------------------------------------------------- finance

  ExpenseCategory? expenseCategoryById(int? id) {
    if (id == null) return null;
    for (final c in expenseCategories) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<FinTxn> get reviewQueue => txns.where((t) => t.status == TxnStatus.needsReview).toList();

  Future<void> addManualTxn(FinTxn t) async {
    t.fingerprint = fingerprintOf(t);
    await finRepo.insertTxn(finRepo.db, t);
    await reloadFinance();
  }

  Future<void> saveTxn(FinTxn t) async {
    t.userEdited = true;
    t.fingerprint = fingerprintOf(t);
    await finRepo.updateTxn(t);
    await reloadFinance();
  }

  Future<void> confirmTxn(FinTxn t) async {
    confirmReviewed(t);
    if (typeIsRefundLike(t.type) && t.linkedTxnId == null) {
      t.linkedTxnId = findRefundOriginal(t, txns);
    }
    await saveTxn(t);
  }

  /// Delete or ignore. SMS items leave an ignore marker so rescans skip them.
  Future<void> deleteTxn(FinTxn t) async {
    await finRepo.deleteTxn(t);
    await reloadFinance();
  }

  Future<void> addExpenseCategory(String name, int color) async {
    await finRepo.insertCategory(ExpenseCategory(name: name, icon: 'other', color: color, sortOrder: 0));
    await reloadFinance();
  }

  Future<void> updateExpenseCategory(ExpenseCategory c) async {
    await finRepo.updateCategory(c);
    await reloadFinance();
  }

  Future<void> deleteExpenseCategory(int id) async {
    await finRepo.deleteCategory(id);
    await reloadFinance();
  }

  Future<void> reorderExpenseCategories(List<int> ids) async {
    await finRepo.reorderCategories(ids);
    await reloadFinance();
  }

  Future<void> addMerchantRule(String pattern, int categoryId) async {
    await finRepo.insertRule(MerchantRule(pattern: pattern.trim(), categoryId: categoryId));
    await reloadFinance();
  }

  Future<void> deleteMerchantRule(int id) async {
    await finRepo.deleteRule(id);
    await reloadFinance();
  }

  Future<void> deleteAllFinancialData() async {
    await native.clearSmsQueue();
    await finRepo.deleteAllFinancialData();
    if (settings.smsNewMessages) {
      await finRepo.setMeta(_metaLastScan, '${AppClock.now().millisecondsSinceEpoch}');
    }
    await reloadFinance();
  }

  // ---------------------------------------------------------------- SMS

  Future<SmsPermissions> refreshSmsPermissions() async {
    smsPerms = await native.smsPermissions();
    notifyListeners();
    return smsPerms;
  }

  Future<SmsPermissions> requestSmsRead() async {
    smsPerms = await native.requestSms(['read']);
    notifyListeners();
    return smsPerms;
  }

  /// Turns processing of new messages on/off. Turning on requests READ_SMS and
  /// RECEIVE_SMS; only messages arriving after this moment are processed
  /// automatically (history is a separate, explicit import).
  Future<bool> setNewMessageProcessing(bool enabled) async {
    if (enabled) {
      smsPerms = await native.requestSms(['read', 'receive']);
      if (!smsPerms.canReceive) {
        notifyListeners();
        return false;
      }
      final last = await finRepo.meta(_metaLastScan);
      if (last == null) {
        await finRepo.setMeta(_metaLastScan, '${AppClock.now().millisecondsSinceEpoch}');
      }
    }
    settings.smsNewMessages = enabled;
    await settingsRepo.save(settings);
    await native.setSmsProcessingEnabled(enabled);
    if (!enabled) {
      await native.clearSmsQueue();
      await finRepo.setMeta(_metaLastScan, '');
    }
    notifyListeners();
    return true;
  }

  /// Saves messages queued by the native receiver while the app was not running.
  Future<void> processSmsQueue() async {
    if (_processingQueue) return;
    _processingQueue = true;
    try {
      final q = await native.peekSmsQueue();
      if (q.isEmpty) return;
      final ids = q.map((e) => e.id).toList();
      if (!settings.smsNewMessages) {
        await native.ackSmsQueue(ids);
        return;
      }
      final report = await ingest.ingest(q.map((e) => e.sms).toList());
      await native.ackSmsQueue(ids);
      await _afterIngest(report);
    } finally {
      _processingQueue = false;
    }
  }

  /// Recovers messages the receiver may have missed (app force-stopped,
  /// process killed) by re-reading the inbox since the last scan. Safe to
  /// repeat: duplicates are skipped.
  Future<IngestReport?> catchUpInbox() async {
    if (!settings.smsNewMessages || !smsPerms.canRead) return null;
    final lastText = await finRepo.meta(_metaLastScan);
    final now = AppClock.now().millisecondsSinceEpoch;
    final last = int.tryParse(lastText ?? '') ?? now;
    final from = last - const Duration(hours: 6).inMilliseconds;
    final chunk = await native.queryInbox(from, now + 60000);
    final report = await ingest.ingest(chunk.candidates);
    report.scanned = chunk.scanned;
    await finRepo.setMeta(_metaLastScan, '$now');
    await _afterIngest(report);
    return report;
  }

  Future<void> _afterIngest(IngestReport report) async {
    if (report.saved == 0) return;
    await reloadFinance();
    if (!settings.txnNotifications) return;
    final confirmed = report.savedTxns.where((t) => t.status == TxnStatus.confirmed).toList();
    if (confirmed.length == 1) {
      final t = confirmed.first;
      final amount = formatMoney(t.amountMinor ?? 0, t.currency, arabic: settings.language == 'ar');
      await native.showTxnNotification(
          tr.txnRecordedTitle, t.merchant.isEmpty ? amount : tr.txnRecordedAt(amount, t.merchant));
    } else if (confirmed.length > 1) {
      await native.showTxnNotification(tr.txnRecordedTitle, tr.txnsRecorded(confirmed.length));
    }
    if (report.review > 0) {
      await native.showTxnNotification(tr.needsReview, tr.reviewItemsWaiting(report.review));
    }
  }

  /// Historical import: scans the inbox in weekly windows (newest first) and
  /// returns candidates for the preview. Nothing is saved here.
  Future<(List<IngestCandidate>, int)> scanHistory(
      Day from, Day to, void Function(ImportProgress) onProgress) async {
    final start = from.startLocal.millisecondsSinceEpoch;
    final end = to.endLocalExclusive.millisecondsSinceEpoch;
    const week = 7 * 24 * 60 * 60 * 1000;
    final windows = <(int, int)>[];
    for (var e = end; e > start; e -= week) {
      windows.add((e - week < start ? start : e - week, e));
    }
    final all = <RawSms>[];
    var scanned = 0;
    for (var i = 0; i < windows.length; i++) {
      final chunk = await native.queryInbox(windows[i].$1, windows[i].$2);
      scanned += chunk.scanned;
      all.addAll(chunk.candidates);
      onProgress(ImportProgress(i + 1, windows.length, scanned));
    }
    all.sort((a, b) => a.receivedAt.compareTo(b.receivedAt));
    final cands = await ingest.analyze(all);
    return (cands, scanned);
  }

  Future<IngestReport> commitImport(List<IngestCandidate> cands, int scanned) async {
    final report = await ingest.commit(cands, scanned: scanned);
    await finRepo.setMeta(_metaHistoryImported, '${AppClock.now().millisecondsSinceEpoch}');
    await reloadFinance();
    return report;
  }

  // ---------------------------------------------------------------- backup

  Future<Uint8List> buildBackup({String? financePassword}) async {
    final core = await backup.exportCore();
    if (financePassword != null) {
      final payload = await backup.exportFinancePayload();
      final env = await native.encrypt(Uint8List.fromList(utf8.encode(payload)), financePassword);
      if (env == null) throw BackupException('encryption_failed');
      core['finance'] = env;
      core['contents'] = ['tasks', 'habits', 'finance-encrypted'];
    }
    return Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent(' ').convert(core)));
  }

  Future<FinanceBackup?> decryptFinance(Map<String, Object?> env, String password) async {
    final plain = await native.decrypt(env, password);
    if (plain == null) return null;
    return BackupService.parseFinance(utf8.decode(plain));
  }

  Future<void> restore(CoreBackup core, FinanceBackup? fin) async {
    await backup.restoreCore(core);
    if (fin != null) await backup.restoreFinance(fin);
    await reloadAll();
    await syncReminders();
  }
}
