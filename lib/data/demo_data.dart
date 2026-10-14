import '../core/day.dart';
import '../domain/habit_models.dart';
import '../domain/task_models.dart';
import 'habit_repo.dart';
import 'task_repo.dart';

/// Optional sample content with generic names. Dates are relative to the
/// first launch. Inserted only on explicit request and flagged `is_demo`
/// so it can be removed without touching the user's own data.
class DemoData {
  static Future<void> insert({
    required TaskRepo tasks,
    required HabitRepo habits,
    required Day base,
    required bool arabic,
  }) async {
    String t(String ar, String en) => arabic ? ar : en;
    final cats = await tasks.categories();
    int? workId;
    for (final c in cats) {
      if (c.nameKey == 'work') workId = c.id;
    }
    workId ??= cats.isNotEmpty ? cats.first.id : null;
    final now = AppClock.now().millisecondsSinceEpoch;

    TaskItem task(String title,
        {TaskPriority p = TaskPriority.normal,
        TaskStatus s = TaskStatus.notStarted,
        int? dueIn,
        int? dueMinutes,
        int? followIn,
        String waitingOn = '',
        String notes = '',
        List<String> subs = const []}) {
      return TaskItem(
        title: title,
        categoryId: workId,
        notes: notes,
        priority: p,
        status: s,
        dueDate: dueIn == null ? null : base.addDays(dueIn),
        dueMinutes: dueIn == null ? null : dueMinutes,
        followUpDate: followIn == null ? null : base.addDays(followIn),
        waitingOn: waitingOn,
        createdAt: now,
        updatedAt: now,
        isDemo: true,
        subtasks: [
          for (var i = 0; i < subs.length; i++) Subtask(taskId: 0, title: subs[i], sortOrder: i),
        ],
      );
    }

    final demoTasks = [
      task(t('تمديد العقد', 'Contract extension'),
          p: TaskPriority.high,
          s: TaskStatus.waiting,
          dueIn: 5,
          followIn: 2,
          waitingOn: t('الإدارة القانونية', 'Legal department'),
          subs: [
            t('مراجعة البنود', 'Review the terms'),
            t('إرسال المسودة', 'Send the draft'),
            t('الحصول على الموافقة', 'Get approval'),
          ]),
      task(t('تفعيل خدمة الفرع', 'Branch service activation'),
          p: TaskPriority.medium,
          s: TaskStatus.inProgress,
          dueIn: 1,
          dueMinutes: 10 * 60,
          subs: [t('تجهيز الأجهزة', 'Prepare devices'), t('تدريب الموظفين', 'Train staff')]),
      task(t('متابعة الخطة الاستراتيجية', 'Strategic plan tracking'),
          p: TaskPriority.medium, followIn: 7, notes: t('مراجعة المؤشرات الشهرية', 'Review monthly indicators')),
      task(t('تطوير الخدمة الداخلية', 'Internal service development'),
          s: TaskStatus.inProgress,
          dueIn: 14,
          followIn: 6,
          subs: [
            t('جمع المتطلبات', 'Gather requirements'),
            t('إعداد النموذج الأولي', 'Build a prototype'),
            t('اختبار المستخدمين', 'User testing'),
          ]),
      task(t('مبادرة المكتبة الرقمية', 'Digital library initiative'),
          notes: t('فكرة للمرحلة القادمة', 'Idea for the next phase')),
    ];
    for (final d in demoTasks) {
      await tasks.insertTask(d);
    }

    const sunTueThu = (1 << 0) | (1 << 2) | (1 << 4);
    final demoHabits = <(String, String, int, int?)>[
      (t('تسجيل المصاريف', 'Record expenses'), 'wallet', kAllWeekdaysMask, 21 * 60),
      (t('الرياضة', 'Exercise'), 'fitness', sunTueThu, null),
      (t('القراءة', 'Read'), 'book', kAllWeekdaysMask, null),
      (t('النوم في الوقت المحدد', 'Sleep on time'), 'bed', kAllWeekdaysMask, null),
    ];
    const colors = [0xFF3B7DD8, 0xFF2E9E8F, 0xFFC77D2E, 0xFF7E57C2];
    for (var i = 0; i < demoHabits.length; i++) {
      final h = demoHabits[i];
      await habits.insert(
        Habit(
          name: h.$1,
          icon: h.$2,
          color: colors[i],
          startDate: base,
          reminderMinutes: h.$4,
          createdAt: now,
          isDemo: true,
        ),
        h.$3,
      );
    }
  }

  static Future<void> remove({required TaskRepo tasks, required HabitRepo habits}) async {
    await tasks.deleteDemoTasks();
    await habits.deleteDemo();
  }
}
