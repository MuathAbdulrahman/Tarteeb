import 'package:flutter/material.dart';

import '../core/day.dart';
import '../core/strings.dart';
import 'icons.dart';
import 'theme.dart';

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  String? body,
  String? confirmLabel,
  bool destructive = false,
}) async {
  final p = Palette.of(context);
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: body == null ? null : Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr.cancel)),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: p.danger) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel ?? tr.confirm),
        ),
      ],
    ),
  );
  return r ?? false;
}

Future<String?> promptText(BuildContext context, {required String title, String initial = '', String? hint}) async {
  final c = TextEditingController(text: initial);
  final r = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr.cancel)),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: Text(tr.save)),
      ],
    ),
  );
  c.dispose();
  if (r == null || r.isEmpty) return null;
  return r;
}

Future<Day?> pickDay(BuildContext context, {Day? initial, Day? first, Day? last}) async {
  final init = initial ?? Day.today();
  final f = first ?? Day(2000, 1, 1);
  final l = last ?? Day(2100, 12, 31);
  final r = await showDatePicker(
    context: context,
    initialDate: init.startLocal,
    firstDate: f.startLocal,
    lastDate: l.startLocal,
  );
  return r == null ? null : Day.fromDateTime(r);
}

Future<int?> pickMinutes(BuildContext context, {int? initial}) async {
  final i = initial ?? 9 * 60;
  final r = await showTimePicker(context: context, initialTime: TimeOfDay(hour: i ~/ 60, minute: i % 60));
  return r == null ? null : r.hour * 60 + r.minute;
}

void showUndoSnack(BuildContext context, String message, VoidCallback onUndo) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(message),
    duration: const Duration(seconds: 5),
    action: SnackBarAction(label: tr.undo, onPressed: onUndo),
  ));
}

void showInfoSnack(BuildContext context, String message) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(content: Text(message)));
}

class ColorPickerRow extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  const ColorPickerRow({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final c in kPickerColors)
          Semantics(
            button: true,
            selected: c == selected,
            label: tr.color,
            child: GestureDetector(
              onTap: () => onChanged(c),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: c == selected ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: c == selected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
              ),
            ),
          ),
      ],
    );
  }
}

/// Dialog for creating / renaming a category with a color.
Future<(String, int)?> categoryDialog(BuildContext context, {String name = '', int? color, required String title}) {
  final c = TextEditingController(text: name);
  var col = color ?? kPickerColors.first;
  return showDialog<(String, int)>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: c, autofocus: true, decoration: InputDecoration(labelText: tr.name)),
              const SizedBox(height: 16),
              ColorPickerRow(selected: col, onChanged: (v) => setSt(() => col = v)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr.cancel)),
          FilledButton(
            onPressed: () {
              final n = c.text.trim();
              if (n.isEmpty) return;
              Navigator.pop(ctx, (n, col));
            },
            child: Text(tr.save),
          ),
        ],
      ),
    ),
  );
}

/// Tappable row used in forms (date, time, reminder...).
class FormRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  const FormRow({super.key, required this.icon, required this.label, this.value, required this.onTap, this.onClear});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return ListTile(
      contentPadding: const EdgeInsetsDirectional.only(start: 4, end: 0),
      leading: Icon(icon, color: p.textMuted),
      title: Text(label, style: TextStyle(color: p.textMuted, fontSize: 13)),
      subtitle: Text(value ?? tr.notSet,
          style: TextStyle(color: value == null ? p.textMuted : p.text, fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: (value != null && onClear != null)
          ? IconButton(tooltip: tr.clear, icon: const Icon(Icons.close), onPressed: onClear)
          : null,
      onTap: onTap,
    );
  }
}
