import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/day.dart';
import '../../core/strings.dart';
import '../../data/backup_service.dart';
import '../../data/settings_repo.dart';
import '../../platform/native_bridge.dart';
import '../app_scope.dart';
import '../common.dart';
import '../expenses/sms_import_screen.dart';
import '../theme.dart';
import 'categories_screen.dart';
import 'merchant_rules_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PermState _notifPerm = PermState.unavailable;
  bool _exact = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshPerms());
  }

  Future<void> _refreshPerms() async {
    final app = AppScope.read(context);
    final n = await app.native.notificationPermission();
    final e = await app.native.canScheduleExact();
    await app.refreshSmsPermissions();
    if (!mounted) return;
    setState(() {
      _notifPerm = n;
      _exact = e;
    });
  }

  String _permText(PermState s) => switch (s) {
        PermState.granted => tr.permGranted,
        PermState.denied => tr.permNotGranted,
        PermState.permanentlyDenied => tr.permBlocked,
        PermState.unavailable => tr.permUnavailable,
      };

  // ------------------------------------------------------------ backup

  Future<String?> _askPassword() async {
    final a = TextEditingController();
    final b = TextEditingController();
    String? error;
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(tr.setBackupPassword),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tr.backupPasswordHint, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 8),
                TextField(controller: a, obscureText: true, decoration: InputDecoration(labelText: tr.password)),
                TextField(
                  controller: b,
                  obscureText: true,
                  decoration: InputDecoration(labelText: tr.confirmPassword, errorText: error),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr.cancel)),
            FilledButton(
              onPressed: () {
                if (a.text.length < 8) {
                  setSt(() => error = tr.passwordTooShort);
                } else if (a.text != b.text) {
                  setSt(() => error = tr.passwordsDontMatch);
                } else {
                  Navigator.pop(ctx, a.text);
                }
              },
              child: Text(tr.confirm),
            ),
          ],
        ),
      ),
    );
    a.dispose();
    b.dispose();
    return r;
  }

  Future<void> _export() async {
    final app = AppScope.read(context);
    final includeFinance = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr.exportBackup),
        content: Text(tr.exportContentsBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr.includeFinanceEncrypted)),
          FilledButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr.tasksAndHabitsOnly)),
        ],
      ),
    );
    if (includeFinance == null || !mounted) return;
    String? password;
    if (includeFinance) {
      password = await _askPassword();
      if (password == null) return;
    }
    try {
      final bytes = await app.buildBackup(financePassword: password);
      final d = Day.today();
      final name = 'tarteeb-backup-${d.toIso()}.json';
      final ok = await app.native.saveDocument(name, 'application/json', bytes);
      if (mounted) showInfoSnack(context, ok ? tr.backupSaved : tr.backupNotSaved);
    } catch (_) {
      if (mounted) showInfoSnack(context, tr.backupFailed);
    }
  }

  Future<void> _restore() async {
    final app = AppScope.read(context);
    final bytes = await app.native.openDocument();
    if (bytes == null || !mounted) return;
    CoreBackup core;
    try {
      core = BackupService.parse(utf8.decode(bytes, allowMalformed: false));
    } on BackupException catch (e) {
      showInfoSnack(context, tr.backupInvalid(e.code));
      return;
    } on FormatException {
      showInfoSnack(context, tr.backupInvalid('not_json'));
      return;
    }

    FinanceBackup? fin;
    if (core.financeEnvelope != null) {
      final pass = await promptText(context, title: tr.enterBackupPassword, hint: tr.leaveEmptyToSkipFinance);
      if (!mounted) return;
      if (pass != null) {
        try {
          fin = await app.decryptFinance(core.financeEnvelope!, pass);
        } on BackupException {
          fin = null;
        }
        if (!mounted) return;
        if (fin == null) {
          showInfoSnack(context, tr.wrongPasswordOrCorrupt);
          return;
        }
      }
    }

    final lines = <String>[
      tr.previewLine(tr.tabTasks, core.count('tasks')),
      tr.previewLine(tr.subtasks, core.count('subtasks')),
      tr.previewLine(tr.followUpUpdates, core.count('task_updates')),
      tr.previewLine(tr.taskCategories, core.count('task_categories')),
      tr.previewLine(tr.tabHabits, core.count('habits')),
      tr.previewLine(tr.habitCompletions, core.count('habit_completions')),
      if (fin != null) tr.previewLine(tr.transactionsLabel, fin.count('fin_txns')),
    ];
    final ok = await confirmDialog(
      context,
      title: tr.restoreConfirmTitle,
      body: '${lines.join('\n')}\n\n${fin != null ? tr.restoreReplacesAll : tr.restoreReplacesTasksHabits}',
      confirmLabel: tr.restore,
      destructive: true,
    );
    if (!ok) return;
    try {
      await app.restore(core, fin);
      if (mounted) showInfoSnack(context, tr.restoreDone);
    } catch (_) {
      if (mounted) showInfoSnack(context, tr.restoreFailedUnchanged);
    }
  }

  Future<void> _deleteFinance() async {
    final app = AppScope.read(context);
    final ok = await confirmDialog(
      context,
      title: tr.deleteFinanceTitle,
      body: tr.deleteFinanceBody,
      confirmLabel: tr.deleteFinanceConfirm,
      destructive: true,
    );
    if (!ok) return;
    await app.deleteAllFinancialData();
    if (mounted) showInfoSnack(context, tr.financeDeleted);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Palette.of(context);
    final st = app.settings;

    Widget header(String text) => SectionLabel(text);

    return Scaffold(
      appBar: AppBar(title: Text(tr.tabSettings)),
      body: RefreshIndicator(
        onRefresh: _refreshPerms,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            header(tr.appearance),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr.theme, style: TextStyle(color: p.textMuted, fontSize: 13)),
                  const SizedBox(height: 6),
                  SegmentedButton<ThemePref>(
                    segments: [
                      ButtonSegment(value: ThemePref.system, label: Text(tr.themeSystem)),
                      ButtonSegment(value: ThemePref.light, label: Text(tr.themeLight)),
                      ButtonSegment(value: ThemePref.dark, label: Text(tr.themeDark)),
                    ],
                    selected: {st.theme},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => app.updateSettings((x) => x.theme = s.first),
                  ),
                  const SizedBox(height: 12),
                  Text(tr.language, style: TextStyle(color: p.textMuted, fontSize: 13)),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'ar', label: Text('العربية')),
                      ButtonSegment(value: 'en', label: Text('English')),
                    ],
                    selected: {st.language},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => app.updateSettings((x) => x.language = s.first),
                  ),
                  const SizedBox(height: 4),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(tr.weekStartsOn),
                    trailing: DropdownButton<int>(
                      value: st.weekStart,
                      underline: const SizedBox.shrink(),
                      items: [
                        for (final d in const [0, 1, 6]) DropdownMenuItem(value: d, child: Text(tr.weekdayFull(d))),
                      ],
                      onChanged: (v) => app.updateSettings((x) => x.weekStart = v ?? 0),
                    ),
                  ),
                ],
              ),
            ),
            header(tr.categoriesSection),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                ListTile(
                  leading: const Icon(Icons.label_outline),
                  title: Text(tr.taskCategories),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const CategoriesScreen(kind: CategoryKind.task))),
                ),
                ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: Text(tr.expenseCategories),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const CategoriesScreen(kind: CategoryKind.expense))),
                ),
                ListTile(
                  leading: const Icon(Icons.storefront_outlined),
                  title: Text(tr.merchantRules),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MerchantRulesScreen())),
                ),
              ]),
            ),
            header(tr.notifications),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: Text(tr.notificationPermission),
                  subtitle: Text(_permText(_notifPerm)),
                  trailing: _notifPerm == PermState.granted
                      ? null
                      : TextButton(
                          onPressed: () async {
                            final r = await app.native.requestNotificationPermission();
                            if (r == PermState.permanentlyDenied) await app.native.openAppSettings();
                            await _refreshPerms();
                          },
                          child: Text(tr.allow),
                        ),
                ),
                ListTile(
                  leading: const Icon(Icons.alarm),
                  title: Text(tr.exactReminders),
                  subtitle: Text(_exact ? tr.exactOn : tr.exactOff),
                  trailing: _exact
                      ? null
                      : TextButton(
                          onPressed: () async {
                            await app.native.openExactAlarmSettings();
                          },
                          child: Text(tr.allow),
                        ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.task_alt),
                  title: Text(tr.taskRemindersSetting),
                  value: st.taskReminders,
                  onChanged: (v) => app.updateSettings((x) => x.taskReminders = v),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.repeat),
                  title: Text(tr.habitRemindersSetting),
                  value: st.habitReminders,
                  onChanged: (v) => app.updateSettings((x) => x.habitReminders = v),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.receipt_long_outlined),
                  title: Text(tr.txnNotificationsSetting),
                  value: st.txnNotifications,
                  onChanged: (v) => app.updateSettings((x) => x.txnNotifications = v),
                ),
              ]),
            ),
            header(tr.smsSection),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                ListTile(
                  leading: const Icon(Icons.sms_outlined),
                  title: Text(tr.smsReadPermission),
                  subtitle: Text(_permText(app.smsPerms.read)),
                ),
                ListTile(
                  leading: const Icon(Icons.mark_email_unread_outlined),
                  title: Text(tr.smsReceivePermission),
                  subtitle: Text(_permText(app.smsPerms.receive)),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.bolt_outlined),
                  title: Text(tr.processNewSms),
                  subtitle: Text(tr.processNewSmsHint),
                  value: st.smsNewMessages,
                  onChanged: (v) async {
                    final ok = await app.setNewMessageProcessing(v);
                    if (!ok && context.mounted) showInfoSnack(context, tr.permissionDenied);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(tr.importSmsHistory),
                  subtitle: Text(tr.importSmsHistoryHint),
                  onTap: () =>
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SmsImportScreen())),
                ),
                ListTile(
                  leading: const Icon(Icons.refresh),
                  title: Text(tr.rescanRecent),
                  subtitle: Text(tr.rescanRecentHint),
                  enabled: st.smsNewMessages && app.smsPerms.canRead,
                  onTap: () async {
                    final r = await app.catchUpInbox();
                    if (!context.mounted) return;
                    showInfoSnack(context,
                        r == null ? tr.rescanUnavailable : (r.saved == 0 ? tr.noNewTransactions : tr.newTransactionsSaved(r.saved)));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings_applications_outlined),
                  title: Text(tr.openAppSettings),
                  subtitle: Text(tr.revokeHint),
                  onTap: () => app.native.openAppSettings(),
                ),
              ]),
            ),
            header(tr.dataSection),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                ListTile(
                  leading: const Icon(Icons.upload_file_outlined),
                  title: Text(tr.exportBackup),
                  subtitle: Text(tr.exportBackupHint),
                  onTap: _export,
                ),
                ListTile(
                  leading: const Icon(Icons.restore),
                  title: Text(tr.restoreBackup),
                  subtitle: Text(tr.restoreBackupHint),
                  onTap: _restore,
                ),
                ListTile(
                  leading: Icon(Icons.delete_forever_outlined, color: p.danger),
                  title: Text(tr.deleteFinanceTitle, style: TextStyle(color: p.danger)),
                  subtitle: Text(tr.deleteFinanceHint),
                  onTap: _deleteFinance,
                ),
                if (app.hasDemoData)
                  ListTile(
                    leading: const Icon(Icons.cleaning_services_outlined),
                    title: Text(tr.removeSampleData),
                    onTap: () async {
                      final ok = await confirmDialog(context,
                          title: tr.removeSampleData, body: tr.removeSampleDataBody, confirmLabel: tr.remove);
                      if (ok) await app.removeDemoData();
                    },
                  )
                else if (!st.demoInserted)
                  ListTile(
                    leading: const Icon(Icons.auto_awesome_outlined),
                    title: Text(tr.addSampleData),
                    subtitle: Text(tr.addSampleDataHint),
                    onTap: () => app.insertDemoData(),
                  ),
              ]),
            ),
            header(tr.privacy),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(tr.privacyText, style: TextStyle(fontSize: 13, color: p.textMuted, height: 1.5)),
            ),
            const SizedBox(height: 16),
            Center(child: Text('ترتيب · Tarteeb 1.0.0', style: TextStyle(fontSize: 12, color: p.textMuted))),
          ],
        ),
      ),
    );
  }
}
