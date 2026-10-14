import 'package:sqflite/sqflite.dart';

enum ThemePref { system, light, dark }

/// Typed app settings backed by the `settings` table.
class AppSettings {
  ThemePref theme;
  String language; // 'ar' | 'en'
  int weekStart; // 0 = Sunday ... 6 = Saturday
  bool taskReminders;
  bool habitReminders;
  bool txnNotifications;
  bool smsNewMessages; // process newly received SMS
  bool onboardingDone;
  int firstLaunchAt;
  bool demoInserted;

  AppSettings({
    this.theme = ThemePref.system,
    this.language = 'ar',
    this.weekStart = 0,
    this.taskReminders = true,
    this.habitReminders = true,
    this.txnNotifications = true,
    this.smsNewMessages = false,
    this.onboardingDone = false,
    this.firstLaunchAt = 0,
    this.demoInserted = false,
  });

  Map<String, String> toKv() => {
        'theme': theme.name,
        'language': language,
        'week_start': '$weekStart',
        'task_reminders': taskReminders ? '1' : '0',
        'habit_reminders': habitReminders ? '1' : '0',
        'txn_notifications': txnNotifications ? '1' : '0',
        'sms_new_messages': smsNewMessages ? '1' : '0',
        'onboarding_done': onboardingDone ? '1' : '0',
        'first_launch_at': '$firstLaunchAt',
        'demo_inserted': demoInserted ? '1' : '0',
      };

  static AppSettings fromKv(Map<String, String> kv) {
    bool b(String k, bool d) => kv[k] == null ? d : kv[k] == '1';
    return AppSettings(
      theme: ThemePref.values.firstWhere((e) => e.name == kv['theme'], orElse: () => ThemePref.system),
      language: kv['language'] == 'en' ? 'en' : 'ar',
      weekStart: _weekStart(int.tryParse(kv['week_start'] ?? '') ?? 0),
      taskReminders: b('task_reminders', true),
      habitReminders: b('habit_reminders', true),
      txnNotifications: b('txn_notifications', true),
      smsNewMessages: b('sms_new_messages', false),
      onboardingDone: b('onboarding_done', false),
      firstLaunchAt: int.tryParse(kv['first_launch_at'] ?? '') ?? 0,
      demoInserted: b('demo_inserted', false),
    );
  }
}

int _weekStart(int v) => (v < 0 || v > 6) ? 0 : v;

class SettingsRepo {
  final Database db;
  SettingsRepo(this.db);

  Future<AppSettings> load() async {
    final rows = await db.query('settings');
    final kv = {for (final r in rows) r['key'] as String: (r['value'] as String?) ?? ''};
    return AppSettings.fromKv(kv);
  }

  Future<void> save(AppSettings s) async {
    final b = db.batch();
    for (final e in s.toKv().entries) {
      b.insert('settings', {'key': e.key, 'value': e.value}, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await b.commit(noResult: true);
  }
}
