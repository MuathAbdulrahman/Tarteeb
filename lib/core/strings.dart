import '../domain/finance_models.dart';
import '../domain/habit_logic.dart';
import '../domain/task_logic.dart';
import '../domain/task_models.dart';

/// Current UI strings.
S get tr => S.current;

/// All user-facing strings, Arabic (default) and English.
class S {
  final bool isArabic;
  const S._(this.isArabic);

  static S current = const S._(true);
  static void setLanguage(String code) => current = S._(code != 'en');

  String _t(String ar, String en) => isArabic ? ar : en;

  // ---- general ----
  String get add => _t('إضافة', 'Add');
  String get all => _t('الكل', 'All');
  String get allow => _t('سماح', 'Allow');
  String get cancel => _t('إلغاء', 'Cancel');
  String get clear => _t('مسح', 'Clear');
  String get close => _t('إغلاق', 'Close');
  String get collapse => _t('طي', 'Collapse');
  String get expand => _t('توسيع', 'Expand');
  String get color => _t('اللون', 'Color');
  String get confirm => _t('تأكيد', 'Confirm');
  String get continueLabel => _t('متابعة', 'Continue');
  String get delete => _t('حذف', 'Delete');
  String get done => _t('تم', 'Done');
  String get edit => _t('تعديل', 'Edit');
  String get enable => _t('تفعيل', 'Enable');
  String get ignore => _t('تجاهل', 'Ignore');
  String get name => _t('الاسم', 'Name');
  String get none => _t('لا يوجد', 'None');
  String get notSet => _t('غير محدد', 'Not set');
  String get remove => _t('إزالة', 'Remove');
  String get restore => _t('استعادة', 'Restore');
  String get save => _t('حفظ', 'Save');
  String get search => _t('بحث', 'Search');
  String get showAll => _t('عرض الكل', 'Show all');
  String get undo => _t('تراجع', 'Undo');
  String get viewAll => _t('عرض الكل', 'View all');
  String get yes => _t('نعم', 'Yes');
  String get today => _t('اليوم', 'Today');
  String get tomorrow => _t('غداً', 'Tomorrow');
  String get yesterday => _t('أمس', 'Yesterday');
  String get listSeparator => _t('، ', ', ');
  String get icon => _t('الأيقونة', 'Icon');
  String get password => _t('كلمة المرور', 'Password');
  String get confirmPassword => _t('تأكيد كلمة المرور', 'Confirm password');

  // ---- tabs ----
  String get tabTasks => _t('المهام', 'Tasks');
  String get tabCalendar => _t('التقويم', 'Calendar');
  String get tabHabits => _t('العادات', 'Habits');
  String get tabExpenses => _t('المصاريف', 'Expenses');
  String get tabSettings => _t('الإعدادات', 'Settings');

  // ---- onboarding ----
  String get welcomeTitle => _t('أهلاً بك في ترتيب', 'Welcome to Tarteeb');
  String get welcomeBody => _t(
      'نظّم مهامك وعاداتك ومصاريفك في مكان واحد. كل بياناتك تبقى على جهازك.\n\nهل تريد البدء ببيانات تجريبية يمكنك حذفها لاحقاً؟',
      'Organize your tasks, habits and expenses in one place. All your data stays on your device.\n\nStart with sample data you can remove later?');
  String get startEmpty => _t('البدء فارغاً', 'Start empty');
  String get startWithSamples => _t('إضافة بيانات تجريبية', 'Add sample data');

  // ---- tasks ----
  String get addTask => _t('إضافة مهمة', 'Add task');
  String get newTask => _t('مهمة جديدة', 'New task');
  String get editTask => _t('تعديل المهمة', 'Edit task');
  String get taskTitle => _t('عنوان المهمة', 'Task title');
  String get taskDetails => _t('تفاصيل المهمة', 'Task details');
  String get taskNotFound => _t('لم يتم العثور على المهمة', 'Task not found');
  String get titleRequired => _t('اكتب عنوان المهمة', 'Enter a task title');
  String get category => _t('الفئة', 'Category');
  String get noCategory => _t('بدون فئة', 'No category');
  String get allCategories => _t('الكل', 'All');
  String get manageCategories => _t('إدارة الفئات', 'Manage categories');
  String get priority => _t('الأولوية', 'Priority');
  String get status => _t('الحالة', 'Status');
  String get dueDate => _t('تاريخ الاستحقاق', 'Due date');
  String get dueTime => _t('وقت الاستحقاق', 'Due time');
  String get noDueDate => _t('بدون تاريخ', 'No due date');
  String get reminder => _t('التذكير', 'Reminder');
  String get reminderInPast => _t('وقت التذكير في الماضي', 'Reminder time is in the past');
  String get followUpDate => _t('تاريخ المتابعة', 'Follow-up date');
  String get waitingOn => _t('بانتظار رد من', 'Waiting on');
  String get waitingOnHint => _t('شخص أو جهة (اختياري)', 'Person or organization (optional)');
  String get notes => _t('ملاحظات', 'Notes');
  String get subtasks => _t('المهام الفرعية', 'Subtasks');
  String get addSubtask => _t('إضافة مهمة فرعية', 'Add a subtask');
  String get searchTasks => _t('ابحث في المهام…', 'Search tasks…');
  String get filterAndSort => _t('التصفية والترتيب', 'Filter & sort');
  String get sortBy => _t('الترتيب حسب', 'Sort by');
  String get clearFilters => _t('مسح التصفية', 'Clear filters');
  String get sectionOverdue => _t('متأخرة', 'Overdue');
  String get sectionToday => _t('اليوم', 'Today');
  String get sectionUpcoming => _t('القادمة', 'Upcoming');
  String get sectionNoDate => _t('بدون تاريخ', 'No date');
  String get sectionCompleted => _t('المكتملة', 'Completed');
  String get noTasksTitle => _t('لا توجد مهام بعد', 'No tasks yet');
  String get noTasksBody => _t('اضغط + لإضافة أول مهمة.', 'Tap + to add your first task.');
  String get noMatchingTasks => _t('لا توجد مهام مطابقة', 'No matching tasks');
  String get taskCompleted => _t('تم إكمال المهمة', 'Task completed');
  String get taskDeleted => _t('تم حذف المهمة', 'Task deleted');
  String get deleteTaskQ => _t('حذف المهمة؟', 'Delete task?');
  String get markDone => _t('تحديد كمكتملة', 'Mark as done');
  String get markNotDone => _t('إلغاء الإكمال', 'Mark as not done');
  String get expandSubtasks => _t('عرض المهام الفرعية', 'Show subtasks');
  String get collapseSubtasks => _t('إخفاء المهام الفرعية', 'Hide subtasks');
  String get unfinishedSubtasksTitle => _t('مهام فرعية غير مكتملة', 'Unfinished subtasks');
  String unfinishedSubtasksBody(int n) => _t('يوجد $n من المهام الفرعية غير مكتملة. كيف تريد المتابعة؟',
      '$n subtask(s) are not done yet. How do you want to continue?');
  String get completeTaskOnly => _t('إكمال المهمة فقط', 'Complete task only');
  String get completeAll => _t('إكمال الكل', 'Complete all');
  String get followUpUpdates => _t('تحديثات المتابعة', 'Follow-up updates');
  String get writeUpdate => _t('اكتب تحديثاً جديداً…', 'Write a new update…');
  String get addUpdate => _t('إضافة تحديث', 'Add update');
  String get noUpdates => _t('لا توجد تحديثات بعد', 'No updates yet');
  String get activityHistory => _t('سجل النشاط', 'Activity history');
  String get reminderTaskBody => _t('تذكير بمهمة', 'Task reminder');
  String dueOn(String d) => _t('مستحقة $d', 'Due $d');
  String followUpOn(String d) => _t('متابعة $d', 'Follow up $d');
  String waitingOnName(String n) => _t('بانتظار: $n', 'Waiting: $n');
  String subtasksProgress(int done, int total) =>
      _t('المهام الفرعية (⁦$done/$total⁩)', 'Subtasks ($done/$total)');

  String priorityLabel(TaskPriority p) => switch (p) {
        TaskPriority.normal => _t('عادية', 'Normal'),
        TaskPriority.medium => _t('متوسطة', 'Medium'),
        TaskPriority.high => _t('عالية', 'High'),
      };

  String statusLabel(TaskStatus s) => switch (s) {
        TaskStatus.notStarted => _t('لم تبدأ', 'Not started'),
        TaskStatus.inProgress => _t('قيد التنفيذ', 'In progress'),
        TaskStatus.waiting => _t('بانتظار رد', 'Waiting for response'),
        TaskStatus.completed => _t('مكتملة', 'Completed'),
      };

  String sortLabel(TaskSort s) => switch (s) {
        TaskSort.manual => _t('الافتراضي', 'Default'),
        TaskSort.dueDate => _t('تاريخ الاستحقاق', 'Due date'),
        TaskSort.priority => _t('الأولوية', 'Priority'),
        TaskSort.created => _t('الأحدث', 'Newest'),
      };

  String categoryName(TaskCategory c) {
    if (c.name != null && c.name!.isNotEmpty) return c.name!;
    return switch (c.nameKey) {
      'work' => _t('العمل', 'Work'),
      'personal' => _t('شخصي', 'Personal'),
      'wishlist' => _t('الأمنيات', 'Wishlist'),
      _ => _t('فئة', 'Category'),
    };
  }

  // activity
  String get actCreated => _t('تم إنشاء المهمة', 'Task created');
  String get actEdited => _t('تم تعديل التفاصيل', 'Details edited');
  String actStatus(String a, String b) => _t('تغيّرت الحالة من "$a" إلى "$b"', 'Status changed from "$a" to "$b"');
  String get actCompleted => _t('تم إكمال المهمة', 'Task completed');
  String get actReopened => _t('أُعيد فتح المهمة', 'Task reopened');
  String actDue(String a, String b) => _t('تغيّر الاستحقاق: $a ← $b', 'Due date: $a → $b');
  String actFollowUp(String a, String b) => _t('تغيّرت المتابعة: $a ← $b', 'Follow-up: $a → $b');
  String actSubAdded(String t) => _t('أُضيفت مهمة فرعية: $t', 'Subtask added: $t');
  String actSubDone(String t) => _t('اكتملت مهمة فرعية: $t', 'Subtask done: $t');
  String actSubUndone(String t) => _t('أُعيد فتح مهمة فرعية: $t', 'Subtask reopened: $t');
  String get actUpdate => _t('أُضيف تحديث متابعة', 'Follow-up update added');

  // ---- calendar ----
  String get addTaskOnDay => _t('إضافة مهمة لهذا اليوم', 'Add task for this day');
  String get previousMonth => _t('الشهر السابق', 'Previous month');
  String get nextMonth => _t('الشهر التالي', 'Next month');
  String get labelDue => _t('استحقاق', 'Due');
  String get labelFollowUp => _t('متابعة', 'Follow-up');
  String get labelHabit => _t('عادة', 'Habit');
  String get labelHabitDone => _t('عادة مكتملة', 'Habit done');
  String get nothingScheduled => _t('لا شيء مجدول في هذا اليوم', 'Nothing scheduled for this day');
  String get habitsForDay => _t('العادات', 'Habits');

  // ---- habits ----
  String get addHabit => _t('إضافة عادة', 'Add habit');
  String get newHabit => _t('عادة جديدة', 'New habit');
  String get editHabit => _t('تعديل العادة', 'Edit habit');
  String get habitName => _t('اسم العادة', 'Habit name');
  String get habitNotFound => _t('لم يتم العثور على العادة', 'Habit not found');
  String get nameRequired => _t('اكتب الاسم', 'Enter a name');
  String get noHabitsTitle => _t('لا توجد عادات بعد', 'No habits yet');
  String get noHabitsBody => _t('اضغط + لإضافة عادة تريد الالتزام بها.', 'Tap + to add a habit you want to keep.');
  String get schedule => _t('الجدول', 'Schedule');
  String get daily => _t('يومياً', 'Daily');
  String get specificDays => _t('أيام محددة', 'Specific days');
  String get pickAtLeastOneDay => _t('اختر يوماً واحداً على الأقل', 'Pick at least one day');
  String get scheduleChangeNote =>
      _t('تغيير الجدول يسري من اليوم فصاعداً ولا يغيّر الأيام السابقة.', 'Schedule changes apply from today onward; past days keep their schedule.');
  String get startDate => _t('تاريخ البدء', 'Start date');
  String get startAfterCompletions => _t('لا يمكن أن يكون تاريخ البدء بعد أيام مكتملة مسجلة',
      'Start date cannot be after recorded completions');
  String get notScheduledToday => _t('ليست اليوم', 'Not today');
  String get noStreakYet => _t('لا توجد سلسلة بعد', 'No streak yet');
  String streakDays(int n) => _t('سلسلة: $n ${n == 1 ? 'يوم' : (n == 2 ? 'يومان' : (n <= 10 ? 'أيام' : 'يوماً'))}', 'Streak: $n day${n == 1 ? '' : 's'}');
  String habitsTodayProgress(int done, int total) =>
      _t('أنجزت ⁦$done⁩ من ⁦$total⁩ عادات اليوم', '$done of $total habits done today');
  String archivedCount(int n) => _t('المؤرشفة ($n)', 'Archived ($n)');
  String get archive => _t('أرشفة', 'Archive');
  String get unarchive => _t('إلغاء الأرشفة', 'Unarchive');
  String get deleteHabitQ => _t('حذف العادة؟', 'Delete habit?');
  String get deleteHabitBody =>
      _t('سيتم حذف العادة وكل سجلات الإنجاز الخاصة بها.', 'The habit and all its completion records will be deleted.');
  String get totalCompleted => _t('أيام مكتملة', 'Days completed');
  String get currentStreak => _t('السلسلة الحالية', 'Current streak');
  String get longestStreak => _t('أطول سلسلة', 'Longest streak');
  String startedOn(String d) => _t('بدأت في $d', 'Started $d');
  String reminderAt(String t) => _t('تذكير الساعة $t', 'Reminder at $t');
  String monthCompletion(int done, int scheduled) =>
      _t('هذا الشهر: ⁦$done⁩ من ⁦$scheduled⁩ يوم مجدول حتى الآن', 'This month: $done of $scheduled scheduled days so far');
  String get habitRulesNote => _t(
      'الأيام غير المجدولة لا تقطع السلسلة، ويوم اليوم لا يقطعها قبل انتهائه. لا يمكن تسجيل أيام مستقبلية.',
      'Unscheduled days never break a streak, and today does not break it until it is over. Future days cannot be completed.');
  String get habitReminderBody => _t('حان وقت عادتك اليوم', "Time for today's habit");
  String get habitCompletions => _t('سجلات إنجاز العادات', 'Habit completions');

  String completionError(CompletionError e) => switch (e) {
        CompletionError.future => _t('لا يمكن إكمال يوم في المستقبل', 'You cannot complete a future day'),
        CompletionError.beforeStart => _t('هذا اليوم قبل تاريخ بدء العادة', 'This day is before the habit started'),
        CompletionError.notScheduled => _t('العادة غير مجدولة في هذا اليوم', 'The habit is not scheduled on this day'),
        CompletionError.duplicate => _t('هذا اليوم مسجل مسبقاً', 'Already recorded for this day'),
      };

  // ---- expenses ----
  String get addExpense => _t('إضافة عملية يدوياً', 'Add transaction');
  String get transaction => _t('العملية', 'Transaction');
  String get transactionsLabel => _t('العمليات المالية', 'Transactions');
  String get txnNotFound => _t('لم يتم العثور على العملية', 'Transaction not found');
  String get allTransactions => _t('كل العمليات', 'All transactions');
  String get periodToday => _t('اليوم', 'Today');
  String get periodWeek => _t('الأسبوع', 'Week');
  String get periodMonth => _t('الشهر', 'Month');
  String get periodCustom => _t('مخصص', 'Custom');
  String get netSpending => _t('صافي الإنفاق', 'Net spending');
  String get grossSpending => _t('إجمالي الإنفاق', 'Gross spending');
  String get refunds => _t('المبالغ المستردة', 'Refunds');
  String get foreignCurrencyTotals => _t('عملات أخرى (غير محوّلة)', 'Other currencies (not converted)');
  String foreignLine(String gross, String refunds) => _t('إنفاق $gross · مسترد $refunds', 'Spent $gross · refunded $refunds');
  String get foreignNote => _t('لا تُضاف إلى الريال بدون سعر تحويل موثوق من الرسالة.',
      'Not added to SAR without a reliable conversion from the message.');
  String get totalsDisclaimer => _t(
      'المجاميع تعكس الرسائل المسجلة والإدخالات اليدوية فقط، وقد لا تشمل كل حركات حساباتك. العناصر التي تحتاج مراجعة غير محسوبة.',
      'Totals reflect recorded messages and manual entries only and may not include all account activity. Items needing review are excluded.');
  String get noDataYetDisclaimer => _t(
      'لا توجد بيانات مسجلة بعد. فعّل قراءة الرسائل أو أضف عملية يدوياً.',
      'Nothing recorded yet. Enable SMS reading or add a transaction manually.');
  String get notCountedAsSpending => _t('حركات لا تُحسب كإنفاق', 'Not counted as spending');
  String get dailySpending => _t('الإنفاق اليومي', 'Daily spending');
  String get byCategory => _t('حسب الفئة', 'By category');
  String get noSpendingInPeriod => _t('لا يوجد إنفاق مسجل في هذه الفترة', 'No recorded spending in this period');
  String get recentTransactions => _t('آخر العمليات', 'Recent transactions');
  String get noTransactionsInPeriod => _t('لا توجد عمليات مسجلة في هذه الفترة', 'No recorded transactions in this period');
  String get noTransactionsYet => _t('لا توجد عمليات بعد', 'No transactions yet');
  String get uncategorized => _t('غير مصنف', 'Uncategorized');
  String get needsReview => _t('تحتاج مراجعة', 'Needs review');
  String reviewBanner(int n) => _t('$n عملية تحتاج مراجعة', '$n item(s) need review');
  String reviewItemsWaiting(int n) => _t('$n عملية بانتظار مراجعتك في ترتيب', '$n item(s) are waiting for your review');
  String get reviewEmpty => _t('لا يوجد ما يحتاج مراجعة', 'Nothing needs review');
  String get reviewExplainer => _t(
      'هذه العمليات غير محسوبة في المجاميع حتى تؤكدها. صحّح المبلغ أو النوع عند الحاجة ثم اضغط "تأكيد".',
      'These items are excluded from totals until you confirm them. Fix the amount or type if needed, then tap Confirm.');
  String get manualEntry => _t('يدوي', 'Manual');
  String get searchMerchant => _t('ابحث بالتاجر أو الملاحظة', 'Search merchant or note');
  String get noMatchingTransactions => _t('لا توجد عمليات مطابقة', 'No matching transactions');
  String get type => _t('النوع', 'Type');
  String get account => _t('البطاقة/الحساب', 'Card/account');
  String get amount => _t('المبلغ', 'Amount');
  String get amountUnclear => _t('المبلغ غير واضح', 'Amount unclear');
  String get currency => _t('العملة', 'Currency');
  String get merchant => _t('التاجر / الجهة', 'Merchant / party');
  String get date => _t('التاريخ', 'Date');
  String get time => _t('الوقت', 'Time');
  String get note => _t('ملاحظة', 'Note');
  String get invalidAmount => _t('أدخل مبلغاً صحيحاً أكبر من صفر', 'Enter a valid amount greater than zero');
  String get countAsSpending => _t('احتسابها كإنفاق', 'Count as spending');
  String get countDefaultForType => _t('حسب نوع العملية (افتراضي)', 'Based on type (default)');
  String get countOverridden => _t('تم التغيير يدوياً', 'Changed manually');
  String get confirmTransaction => _t('تأكيد العملية', 'Confirm transaction');
  String get saveKeepInReview => _t('حفظ مع إبقائها للمراجعة', 'Save and keep in review');
  String get rememberCategoryForMerchant =>
      _t('استخدم هذه الفئة لهذا التاجر مستقبلاً', 'Use this category for this merchant in future');
  String get pickCorrectAmount => _t('الرسالة فيها أكثر من مبلغ. اختر المبلغ الصحيح:', 'The message has several amounts. Pick the right one:');
  String get viewPossibleOriginal => _t('عرض العملية المشابهة', 'View the similar transaction');
  String get viewLinkedPurchase => _t('عرض عملية الشراء المرتبطة', 'View linked purchase');
  String get parsingDetails => _t('تفاصيل القراءة', 'Parsing details');
  String get source => _t('المصدر', 'Source');
  String get sourceSms => _t('رسالة نصية', 'SMS');
  String get sourceManual => _t('إدخال يدوي', 'Manual entry');
  String get sender => _t('المرسل', 'Sender');
  String get reference => _t('المرجع', 'Reference');
  String get feeInMessage => _t('رسوم مذكورة', 'Fee mentioned');
  String get sarEquivalent => _t('ما يعادل بالريال', 'SAR equivalent');
  String get timeSource => _t('مصدر الوقت', 'Time source');
  String get smsReceived => _t('وصول الرسالة', 'SMS received');
  String get confidence => _t('درجة الثقة', 'Confidence');
  String get parserVersion => _t('إصدار المحلل', 'Parser version');
  String get edited => _t('معدّلة يدوياً', 'Edited by you');
  String get redactedExcerpt => _t('مقتطف من الرسالة (الأرقام الحساسة مخفية)', 'Message excerpt (sensitive numbers hidden)');
  String get deleteTxnQ => _t('حذف العملية؟', 'Delete transaction?');
  String get ignoreTxnQ => _t('تجاهل هذه العملية؟', 'Ignore this transaction?');
  String get ignoreTxnBody => _t('ستُحذف ولن تُضاف مجدداً عند إعادة فحص الرسائل.',
      'It will be removed and not re-added when messages are rescanned.');
  String get txnRecordedTitle => _t('تم تسجيل عملية', 'Transaction recorded');
  String txnRecordedAt(String amount, String merchant) => _t('$amount لدى $merchant', '$amount at $merchant');
  String txnsRecorded(int n) => _t('تم تسجيل $n عمليات جديدة', '$n new transactions recorded');
  String get noNewTransactions => _t('لا توجد عمليات جديدة', 'No new transactions');
  String newTransactionsSaved(int n) => _t('تم حفظ $n عملية جديدة', '$n new transaction(s) saved');
  String maxPerDay(String v) => _t('الأعلى: $v', 'Max: $v');
  String chartSemantics(String total, int days) =>
      _t('مخطط الإنفاق اليومي، الإجمالي $total خلال $days يوم', 'Daily spending chart, total $total over $days days');
  String expenseCategoryName(ExpenseCategory c) {
    if (c.name != null && c.name!.isNotEmpty) return c.name!;
    return switch (c.nameKey) {
      'food' => _t('مطاعم ومشروبات', 'Food & drinks'),
      'groceries' => _t('بقالة', 'Groceries'),
      'transport' => _t('مواصلات', 'Transport'),
      'shopping' => _t('تسوق', 'Shopping'),
      'bills' => _t('فواتير', 'Bills'),
      'entertainment' => _t('ترفيه', 'Entertainment'),
      'health' => _t('صحة', 'Health'),
      'other' => _t('أخرى', 'Other'),
      _ => _t('فئة', 'Category'),
    };
  }

  String txnTypeLabel(TxnType t) => switch (t) {
        TxnType.cardPurchase => _t('شراء بالبطاقة', 'Card purchase'),
        TxnType.onlinePurchase => _t('شراء عبر الإنترنت', 'Online purchase'),
        TxnType.billPayment => _t('سداد فاتورة', 'Bill payment'),
        TxnType.refund => _t('استرداد', 'Refund'),
        TxnType.reversal => _t('عكس / إلغاء عملية', 'Reversal / cancellation'),
        TxnType.transferOut => _t('حوالة صادرة', 'Outgoing transfer'),
        TxnType.transferIn => _t('حوالة واردة', 'Incoming transfer'),
        TxnType.atmWithdrawal => _t('سحب من الصراف', 'ATM withdrawal'),
        TxnType.bankFee => _t('رسوم بنكية', 'Bank fee'),
        TxnType.cardPayment => _t('سداد البطاقة الائتمانية', 'Credit card payment'),
        TxnType.income => _t('دخل / إيداع', 'Income / deposit'),
        TxnType.unknown => _t('عملية غير معروفة', 'Unknown transaction'),
      };

  String tsSourceLabel(TimestampSource s) => switch (s) {
        TimestampSource.message => _t('من نص الرسالة', 'From message text'),
        TimestampSource.messageDateOnly => _t('التاريخ من الرسالة، والوقت من وصولها', 'Date from message, time from arrival'),
        TimestampSource.smsFallback => _t('وقت وصول الرسالة (بديل)', 'SMS arrival time (fallback)'),
        TimestampSource.manual => _t('أدخلته يدوياً', 'Entered by you'),
      };

  String reviewReasonLabel(String code) => switch (code) {
        'ambiguous_amount' => _t('الرسالة تحتوي أكثر من مبلغ', 'The message contains several amounts'),
        'no_amount' => _t('لم يتم التعرف على المبلغ', 'Amount not recognized'),
        'unknown_type' => _t('نوع العملية غير واضح', 'Transaction type unclear'),
        'weak_type' => _t('النوع مستنتج من كلمات عامة', 'Type guessed from generic wording'),
        'low_confidence' => _t('ثقة منخفضة في القراءة', 'Low parsing confidence'),
        'possible_duplicate' => _t('قد تكون مكررة لعملية مسجلة', 'May duplicate a recorded transaction'),
        'unlinked_reversal' => _t('عكس عملية لم يُعثر على أصلها', 'Reversal without a matching original'),
        _ => code,
      };

  // ---- SMS ----
  String get smsUnavailable =>
      _t('قراءة الرسائل غير متاحة على هذا الجهاز. يمكنك إدخال العمليات يدوياً.', 'SMS reading is not available on this device. You can add transactions manually.');
  String get smsActive => _t('تتم معالجة الرسائل المالية الجديدة على جهازك.', 'New financial messages are processed on your device.');
  String get smsOnboardTitle => _t('سجّل مصاريفك تلقائياً من رسائل البنك', 'Track spending from bank SMS');
  String get smsOnboardBody => _t(
      'يمكن لترتيب قراءة رسائل البنك على جهازك فقط لاستخراج عمليات الشراء. لا تُرفع أي رسالة، ويتم تجاهل رموز التحقق والرسائل غير المالية. القراءة معطلة حتى تفعّلها.',
      'Tarteeb can read bank messages on your device only to extract purchases. Nothing is uploaded, and verification codes and non-financial messages are ignored. Off until you enable it.');
  String get smsDeniedBody => _t(
      'تم رفض إذن الرسائل. لتفعيله افتح إعدادات التطبيق ← الأذونات ← الرسائل القصيرة. الإدخال اليدوي يعمل دائماً.',
      'SMS permission was denied. To enable it, open App settings → Permissions → SMS. Manual entry always works.');
  String get smsRevokedTitle => _t('تم إيقاف إذن الرسائل', 'SMS permission was turned off');
  String get smsRevokedBody => _t(
      'معالجة الرسائل الجديدة متوقفة لأن الإذن أُلغي من إعدادات النظام.',
      'New-message processing is paused because the permission was revoked in system settings.');
  String get openAppSettings => _t('إعدادات التطبيق', 'App settings');
  String get importSmsHistory => _t('استيراد الرسائل السابقة', 'Import past messages');
  String get importSmsHistoryHint => _t('فحص الرسائل خلال فترة تختارها', 'Scan messages in a period you choose');
  String get processNewSms => _t('معالجة الرسائل الجديدة', 'Process new messages');
  String get processNewSmsHint => _t('تسجيل عمليات البطاقة تلقائياً عند وصول رسالة البنك', 'Record card transactions automatically when a bank SMS arrives');
  String get enableNewSmsTitle => _t('معالجة الرسائل الجديدة؟', 'Process new messages?');
  String get enableNewSmsBody => _t(
      'سيطلب التطبيق إذن قراءة واستقبال الرسائل. تتم المعالجة على جهازك فقط، ويمكنك الإيقاف في أي وقت. إذا أُغلق التطبيق قسراً فلن تصل الرسائل حتى تفتحه، وعندها يستعيد ما فاته.',
      'The app will ask for permission to read and receive SMS. Processing happens on your device only and you can turn it off anytime. If the app is force-stopped, messages are not received until you open it again; it then recovers what it missed.');
  String get permissionDenied => _t('لم يتم منح الإذن', 'Permission not granted');
  String get smsExplainTitle => _t('كيف يعمل استيراد الرسائل', 'How message import works');
  List<String> get smsExplainPoints => isArabic
      ? const [
          'يتم الفحص على جهازك فقط، ولا تُرسل الرسائل أو العمليات لأي جهة.',
          'تُقرأ الرسائل المالية فقط. رموز التحقق والرسائل الأخرى يتم تجاهلها ولا تُحفظ.',
          'نحفظ أقل قدر من البيانات: المبلغ، التاجر، التاريخ، وآخر 4 أرقام فقط من البطاقة.',
          'ستراجع النتائج قبل الحفظ، والعناصر غير المؤكدة تذهب إلى قائمة المراجعة.',
          'الاستيراد المتكرر لا ينشئ عمليات مكررة.',
        ]
      : const [
          'Scanning happens on your device only. Messages and transactions are never sent anywhere.',
          'Only financial messages are read. Verification codes and other messages are ignored and not stored.',
          'Minimal data is kept: amount, merchant, date and only the last 4 digits of the card.',
          'You review the results before saving; uncertain items go to the review queue.',
          'Importing again never creates duplicates.',
        ];
  String get smsPermissionTitle => _t('إذن قراءة الرسائل', 'SMS read permission');
  String get smsPermissionBody => _t(
      'يحتاج الاستيراد إلى إذن قراءة الرسائل القصيرة. سيظهر طلب النظام الآن.',
      'Importing needs permission to read SMS. The system prompt will appear now.');
  String get grantPermission => _t('منح الإذن', 'Grant permission');
  String get checkAgain => _t('تحقق مرة أخرى', 'Check again');
  String get manualStillWorks => _t('يمكنك دائماً إضافة العمليات يدوياً.', 'You can always add transactions manually.');
  String get chooseRange => _t('اختر فترة الاستيراد', 'Choose the import period');
  String lastNDays(int n) => _t('آخر $n يوماً', 'Last $n days');
  String get scanMessages => _t('فحص الرسائل', 'Scan messages');
  String get scanLocalNote => _t('يتم الفحص محلياً. لن يُحفظ شيء قبل موافقتك.', 'Scanning is local. Nothing is saved until you confirm.');
  String scanningProgress(int n) => _t('جارٍ الفحص… تم فحص $n رسالة', 'Scanning… $n messages checked');
  String get messagesScanned => _t('الرسائل المفحوصة', 'Messages scanned');
  String get transactionsRecognized => _t('عمليات تم التعرف عليها', 'Transactions recognized');
  String get duplicatesSkipped => _t('مكررة تم تخطيها', 'Duplicates skipped');
  String get itemsNeedingReview => _t('تحتاج مراجعة', 'Need review');
  String get notTransactions => _t('رسائل ليست عمليات (تم تجاهلها)', 'Not transactions (ignored)');
  String get nothingToImport => _t('لا توجد عمليات جديدة للاستيراد', 'No new transactions to import');
  String get nothingToImportBody => _t(
      'قد تكون الرسائل مستوردة مسبقاً، أو بصيغة غير مدعومة بعد.',
      'Messages may already be imported, or be in a format not supported yet.');
  String readyToImport(int n) => _t('جاهزة للاستيراد ($n)', 'Ready to import ($n)');
  String importAsReview(int n) => _t('ستُضاف للمراجعة ($n)', 'Will be added for review ($n)');
  String importN(int n) => _t('استيراد $n', 'Import $n');
  String get importDone => _t('اكتمل الاستيراد', 'Import complete');
  String get saved => _t('تم حفظها', 'Saved');
  String get alsoProcessNew => _t('معالجة الرسائل الجديدة أيضاً', 'Also process new messages');
  String get smsSection => _t('الرسائل القصيرة', 'SMS');
  String get smsReadPermission => _t('إذن قراءة الرسائل', 'Read SMS permission');
  String get smsReceivePermission => _t('إذن استقبال الرسائل', 'Receive SMS permission');
  String get rescanRecent => _t('إعادة فحص الرسائل الأخيرة', 'Rescan recent messages');
  String get rescanRecentHint => _t('يستعيد العمليات الفائتة دون تكرار', 'Recovers missed transactions without duplicates');
  String get rescanUnavailable => _t('فعّل معالجة الرسائل الجديدة أولاً', 'Enable new-message processing first');
  String get revokeHint => _t('لإلغاء الأذونات أو مراجعتها', 'To review or revoke permissions');

  // ---- settings ----
  String get appearance => _t('المظهر', 'Appearance');
  String get theme => _t('السمة', 'Theme');
  String get themeSystem => _t('النظام', 'System');
  String get themeLight => _t('فاتح', 'Light');
  String get themeDark => _t('داكن', 'Dark');
  String get language => _t('اللغة', 'Language');
  String get weekStartsOn => _t('بداية الأسبوع', 'Week starts on');
  String weekdayFull(int i) => isArabic
      ? const ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'][i]
      : const ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'][i];
  String get categoriesSection => _t('الفئات', 'Categories');
  String get taskCategories => _t('فئات المهام', 'Task categories');
  String get expenseCategories => _t('فئات المصاريف', 'Expense categories');
  String get newCategory => _t('فئة جديدة', 'New category');
  String get editCategory => _t('تعديل الفئة', 'Edit category');
  String get categoriesHint => _t('اضغط للتعديل، واسحب المقبض لإعادة الترتيب.', 'Tap to edit; drag the handle to reorder.');
  String deleteCategoryQ(String n) => _t('حذف "$n"؟', 'Delete "$n"?');
  String get deleteTaskCategoryBody => _t('ستبقى المهام لكن بدون فئة.', 'Tasks are kept without a category.');
  String get deleteExpenseCategoryBody =>
      _t('ستبقى العمليات لكن بدون فئة، وتُحذف قواعد التجار المرتبطة.', 'Transactions are kept uncategorized; related merchant rules are removed.');
  String get merchantRules => _t('قواعد التجار', 'Merchant rules');
  String get merchantRulesHint => _t(
      'عند احتواء اسم التاجر على النص المحدد، تُصنّف العمليات الجديدة تلقائياً. لا تغيّر القواعد العمليات السابقة.',
      'When a merchant name contains the text, new transactions get the category automatically. Rules never change past transactions.');
  String get newRule => _t('قاعدة جديدة', 'New rule');
  String get merchantContains => _t('اسم التاجر يحتوي على', 'Merchant contains');
  String get noRules => _t('لا توجد قواعد', 'No rules');
  String get deleteRuleQ => _t('حذف القاعدة؟', 'Delete rule?');
  String get notifications => _t('التنبيهات', 'Notifications');
  String get notificationPermission => _t('إذن الإشعارات', 'Notification permission');
  String get exactReminders => _t('تذكيرات في الوقت المحدد', 'On-time reminders');
  String get exactOn => _t('مفعّلة', 'Enabled');
  String get exactOff => _t('غير مفعّلة؛ قد تتأخر التذكيرات بضع دقائق', 'Off; reminders may arrive a few minutes late');
  String get taskRemindersSetting => _t('تذكيرات المهام', 'Task reminders');
  String get habitRemindersSetting => _t('تذكيرات العادات', 'Habit reminders');
  String get txnNotificationsSetting => _t('إشعار عند تسجيل عملية', 'Notify when a transaction is recorded');
  String get permGranted => _t('ممنوح', 'Granted');
  String get permNotGranted => _t('غير ممنوح', 'Not granted');
  String get permBlocked => _t('مرفوض – يمكن تغييره من إعدادات التطبيق', 'Denied – change it in App settings');
  String get permUnavailable => _t('غير متاح', 'Unavailable');
  String get dataSection => _t('البيانات والنسخ الاحتياطي', 'Data & backup');
  String get exportBackup => _t('تصدير نسخة احتياطية', 'Export backup');
  String get exportBackupHint => _t('ملف JSON للمهام والعادات', 'JSON file with tasks and habits');
  String get exportContentsBody => _t(
      'تتضمن النسخة المهام والعادات. البيانات المالية غير مضمّنة افتراضياً؛ إذا ضمّنتها فستُشفّر بكلمة مرور (بدون نصوص الرسائل).',
      'The backup contains tasks and habits. Financial data is excluded by default; if included it is encrypted with a password (no SMS text).');
  String get includeFinanceEncrypted => _t('مع البيانات المالية (مشفرة)', 'Include finance (encrypted)');
  String get tasksAndHabitsOnly => _t('المهام والعادات فقط', 'Tasks & habits only');
  String get setBackupPassword => _t('كلمة مرور النسخة', 'Backup password');
  String get backupPasswordHint => _t(
      'تُستخدم لتشفير البيانات المالية. لا يمكن استعادتها إذا نسيتها.',
      'Used to encrypt financial data. It cannot be recovered if forgotten.');
  String get passwordTooShort => _t('8 أحرف على الأقل', 'At least 8 characters');
  String get passwordsDontMatch => _t('كلمتا المرور غير متطابقتين', 'Passwords do not match');
  String get backupSaved => _t('تم حفظ النسخة الاحتياطية', 'Backup saved');
  String get backupNotSaved => _t('لم يتم حفظ الملف', 'File was not saved');
  String get backupFailed => _t('تعذر إنشاء النسخة', 'Could not create the backup');
  String get restoreBackup => _t('استعادة نسخة احتياطية', 'Restore backup');
  String get restoreBackupHint => _t('سيتم التحقق من الملف قبل أي تغيير', 'The file is validated before anything changes');
  String backupInvalid(String code) => _t('ملف غير صالح ولم يتغير شيء ($code)', 'Invalid file; nothing was changed ($code)');
  String get enterBackupPassword => _t('كلمة مرور البيانات المالية', 'Finance data password');
  String get leaveEmptyToSkipFinance => _t('اتركها فارغة لتخطي البيانات المالية', 'Leave empty to skip financial data');
  String get wrongPasswordOrCorrupt =>
      _t('كلمة المرور خاطئة أو البيانات تالفة. لم يتغير شيء.', 'Wrong password or corrupted data. Nothing was changed.');
  String previewLine(String label, int n) => '$label: $n';
  String get restoreConfirmTitle => _t('استبدال البيانات الحالية؟', 'Replace current data?');
  String get restoreReplacesTasksHabits =>
      _t('سيتم استبدال كل المهام والعادات الحالية. البيانات المالية لن تتغير.', 'All current tasks and habits will be replaced. Financial data is unchanged.');
  String get restoreReplacesAll =>
      _t('سيتم استبدال المهام والعادات والبيانات المالية الحالية.', 'Current tasks, habits and financial data will be replaced.');
  String get restoreDone => _t('تمت الاستعادة', 'Restore complete');
  String get restoreFailedUnchanged => _t('فشلت الاستعادة ولم تتغير بياناتك', 'Restore failed; your data was not changed');
  String get deleteFinanceTitle => _t('حذف البيانات المالية', 'Delete financial data');
  String get deleteFinanceHint => _t('العمليات والقواعد فقط؛ تبقى المهام والعادات', 'Transactions and rules only; tasks and habits stay');
  String get deleteFinanceBody => _t(
      'سيتم حذف كل العمليات المستوردة واليدوية وقواعد التجار وعلامات التجاهل. لن تتأثر المهام والعادات. لا يمكن التراجع.',
      'All imported and manual transactions, merchant rules and ignore markers will be deleted. Tasks and habits are not affected. This cannot be undone.');
  String get deleteFinanceConfirm => _t('حذف نهائياً', 'Delete permanently');
  String get financeDeleted => _t('تم حذف البيانات المالية', 'Financial data deleted');
  String get addSampleData => _t('إضافة بيانات تجريبية', 'Add sample data');
  String get addSampleDataHint => _t('مهام وعادات بأسماء عامة يمكن حذفها', 'Generic tasks and habits you can remove');
  String get removeSampleData => _t('حذف البيانات التجريبية', 'Remove sample data');
  String get removeSampleDataBody =>
      _t('ستُحذف المهام والعادات التجريبية فقط.', 'Only the sample tasks and habits will be removed.');
  String get privacy => _t('الخصوصية', 'Privacy');
  String get privacyText => _t(
      'ترتيب يعمل بدون إنترنت وبدون حساب. لا توجد إعلانات أو تحليلات أو خدمات ذكاء اصطناعي سحابية. تُحلَّل الرسائل على جهازك فقط ولا تُحفظ نصوصها؛ نحتفظ بالحد الأدنى من بيانات العملية وآخر 4 أرقام من البطاقة. البيانات المالية مستبعدة من النسخ الاحتياطي التلقائي للنظام.',
      'Tarteeb works offline with no account. No ads, analytics or cloud AI. Messages are parsed on your device and their text is not stored; only minimal transaction data and the last 4 card digits are kept. Financial data is excluded from automatic system backups.');
}
