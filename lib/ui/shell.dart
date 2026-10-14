import 'package:flutter/material.dart';

import '../core/strings.dart';
import 'app_scope.dart';
import 'calendar/calendar_screen.dart';
import 'expenses/expenses_screen.dart';
import 'habits/habits_screen.dart';
import 'settings/settings_screen.dart';
import 'tasks/tasks_screen.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOnboard());
  }

  Future<void> _maybeOnboard() async {
    final app = AppScope.read(context);
    if (app.settings.onboardingDone) return;
    final withDemo = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(tr.welcomeTitle),
        content: Text(tr.welcomeBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr.startEmpty)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr.startWithSamples)),
        ],
      ),
    );
    await app.updateSettings((s) => s.onboardingDone = true);
    if (withDemo == true) await app.insertDemoData();
  }

  @override
  Widget build(BuildContext context) {
    AppScope.of(context);
    final review = AppScope.of(context).reviewQueue.length;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          TasksScreen(),
          CalendarScreen(),
          HabitsScreen(),
          ExpensesScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.check_circle_outline), selectedIcon: const Icon(Icons.check_circle), label: tr.tabTasks),
          NavigationDestination(
              icon: const Icon(Icons.calendar_month_outlined),
              selectedIcon: const Icon(Icons.calendar_month),
              label: tr.tabCalendar),
          NavigationDestination(
              icon: const Icon(Icons.repeat), selectedIcon: const Icon(Icons.repeat_on), label: tr.tabHabits),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: review > 0,
              label: Text('$review'),
              child: const Icon(Icons.account_balance_wallet_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: review > 0,
              label: Text('$review'),
              child: const Icon(Icons.account_balance_wallet),
            ),
            label: tr.tabExpenses,
          ),
          NavigationDestination(
              icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings), label: tr.tabSettings),
        ],
      ),
    );
  }
}
