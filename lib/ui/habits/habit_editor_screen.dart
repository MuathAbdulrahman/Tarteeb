import 'package:flutter/material.dart';

import '../../core/day.dart';
import '../../core/format.dart';
import '../../core/strings.dart';
import '../../domain/habit_logic.dart';
import '../../domain/habit_models.dart';
import '../app_scope.dart';
import '../common.dart';
import '../icons.dart';
import '../theme.dart';

class HabitEditorScreen extends StatefulWidget {
  final HabitWithData? habit;
  const HabitEditorScreen({super.key, this.habit});

  @override
  State<HabitEditorScreen> createState() => _HabitEditorScreenState();
}

class _HabitEditorScreenState extends State<HabitEditorScreen> {
  late final TextEditingController _name;
  late String _icon;
  late int _color;
  late Day _start;
  late int _mask;
  int? _reminder;
  bool _saving = false;

  bool get _isNew => widget.habit == null;

  @override
  void initState() {
    super.initState();
    final h = widget.habit;
    _name = TextEditingController(text: h?.habit.name ?? '');
    _icon = h?.habit.icon ?? 'check';
    _color = h?.habit.color ?? kPickerColors.first;
    _start = h?.habit.startDate ?? Day.today();
    _mask = h == null ? kAllWeekdaysMask : currentMask(h);
    _reminder = h?.habit.reminderMinutes;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showInfoSnack(context, tr.nameRequired);
      return;
    }
    if (_mask == 0) {
      showInfoSnack(context, tr.pickAtLeastOneDay);
      return;
    }
    final h = widget.habit;
    if (h != null && h.completions.isNotEmpty) {
      final earliest = h.completions.reduce((a, b) => a.isBefore(b) ? a : b);
      if (_start.isAfter(earliest)) {
        showInfoSnack(context, tr.startAfterCompletions);
        return;
      }
    }
    setState(() => _saving = true);
    final app = AppScope.read(context);
    if (h == null) {
      await app.addHabit(
        Habit(
          name: name,
          icon: _icon,
          color: _color,
          startDate: _start,
          reminderMinutes: _reminder,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
        _mask,
      );
    } else {
      final edited = Habit.fromMap(h.habit.toMap())
        ..name = name
        ..icon = _icon
        ..color = _color
        ..startDate = _start
        ..reminderMinutes = _reminder;
      await app.saveHabit(edited, _mask);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final weekStart = AppScope.of(context).settings.weekStart;
    final isDaily = _mask == kAllWeekdaysMask;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? tr.newHabit : tr.editHabit),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: FilledButton(onPressed: _saving ? null : _save, child: Text(tr.save)),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.viewInsetsOf(context).bottom),
          children: [
            TextField(
              controller: _name,
              autofocus: _isNew,
              decoration: InputDecoration(labelText: tr.habitName, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 18),
            Text(tr.icon, style: TextStyle(color: p.textMuted, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in kHabitIcons.entries)
                  Semantics(
                    button: true,
                    selected: _icon == e.key,
                    label: e.key,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _icon = e.key),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: _icon == e.key ? Color(_color).withValues(alpha: 0.18) : p.chip,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _icon == e.key ? Color(_color) : Colors.transparent, width: 2),
                        ),
                        child: Icon(e.value, color: _icon == e.key ? Color(_color) : p.textMuted),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text(tr.color, style: TextStyle(color: p.textMuted, fontSize: 13)),
            const SizedBox(height: 8),
            ColorPickerRow(selected: _color, onChanged: (c) => setState(() => _color = c)),
            const SizedBox(height: 18),
            Text(tr.schedule, style: TextStyle(color: p.textMuted, fontSize: 13)),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, label: Text(tr.daily)),
                ButtonSegment(value: false, label: Text(tr.specificDays)),
              ],
              selected: {isDaily},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() {
                if (s.first) {
                  _mask = kAllWeekdaysMask;
                } else if (_mask == kAllWeekdaysMask) {
                  // Start from weekdays Sunday-Thursday.
                  _mask = 0x1F;
                }
              }),
            ),
            if (!isDaily) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < 7; i++)
                    Builder(builder: (_) {
                      final wd = (weekStart + i) % 7;
                      final on = (_mask >> wd) & 1 == 1;
                      return FilterChip(
                        label: Text(weekdayName(wd, short: true)),
                        selected: on,
                        onSelected: (v) => setState(() => _mask = v ? (_mask | (1 << wd)) : (_mask & ~(1 << wd))),
                      );
                    }),
                ],
              ),
            ],
            if (!_isNew)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(tr.scheduleChangeNote, style: TextStyle(fontSize: 12, color: p.textMuted)),
              ),
            const SizedBox(height: 8),
            FormRow(
              icon: Icons.flag_outlined,
              label: tr.startDate,
              value: formatDayLong(_start),
              onTap: () async {
                final d = await pickDay(context, initial: _start);
                if (d != null) setState(() => _start = d);
              },
            ),
            FormRow(
              icon: Icons.notifications_none,
              label: tr.reminder,
              value: _reminder == null ? null : formatMinutes(_reminder!),
              onTap: () async {
                final m = await pickMinutes(context, initial: _reminder ?? 20 * 60);
                if (m != null) setState(() => _reminder = m);
              },
              onClear: () => setState(() => _reminder = null),
            ),
          ],
        ),
      ),
    );
  }
}
