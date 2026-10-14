import 'package:flutter/material.dart';

import '../../core/day.dart';
import '../../core/format.dart';
import '../../core/strings.dart';
import '../../platform/native_bridge.dart';
import '../../sms/sms_ingest.dart';
import '../../state/app_state.dart';
import '../app_scope.dart';
import '../common.dart';
import '../theme.dart';
import 'txn_widgets.dart';

enum _Step { explain, permission, range, scanning, preview, done }

/// Guided historical import: explain -> permission -> date range -> local
/// scan -> preview -> confirm. Nothing is saved before the user confirms.
class SmsImportScreen extends StatefulWidget {
  const SmsImportScreen({super.key});

  @override
  State<SmsImportScreen> createState() => _SmsImportScreenState();
}

class _SmsImportScreenState extends State<SmsImportScreen> {
  _Step _step = _Step.explain;
  DayRange _range = DayRange(Day.today().addDays(-89), Day.today());
  int _presetDays = 90;
  ImportProgress _progress = const ImportProgress(0, 0, 0);
  List<IngestCandidate> _cands = [];
  int _scanned = 0;
  IngestReport? _report;
  bool _committing = false;

  Future<void> _requestPermission() async {
    final app = AppScope.read(context);
    final perms = await app.requestSmsRead();
    if (!mounted) return;
    if (perms.canRead) setState(() => _step = _Step.range);
  }

  Future<void> _scan() async {
    final app = AppScope.read(context);
    setState(() {
      _step = _Step.scanning;
      _progress = const ImportProgress(0, 0, 0);
    });
    final (cands, scanned) = await app.scanHistory(_range.start, _range.end, (pr) {
      if (mounted) setState(() => _progress = pr);
    });
    if (!mounted) return;
    setState(() {
      _cands = cands;
      _scanned = scanned;
      _step = _Step.preview;
    });
  }

  Future<void> _commit() async {
    setState(() => _committing = true);
    final report = await AppScope.read(context).commitImport(_cands, _scanned);
    if (!mounted) return;
    setState(() {
      _report = report;
      _committing = false;
      _step = _Step.done;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr.importSmsHistory)),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: KeyedSubtree(key: ValueKey(_step), child: _body(context, p)),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, Palette p) {
    final app = AppScope.of(context);
    switch (_step) {
      case _Step.explain:
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Icon(Icons.privacy_tip_outlined, size: 40, color: p.accent),
            const SizedBox(height: 12),
            Text(tr.smsExplainTitle, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: p.text)),
            const SizedBox(height: 12),
            for (final line in tr.smsExplainPoints)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check, size: 18, color: p.success),
                    const SizedBox(width: 8),
                    Expanded(child: Text(line, style: TextStyle(fontSize: 14, color: p.text, height: 1.45))),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => setState(() => _step = app.smsPerms.canRead ? _Step.range : _Step.permission),
              child: Text(tr.continueLabel),
            ),
          ],
        );
      case _Step.permission:
        final perm = app.smsPerms.read;
        final blocked = perm == PermState.permanentlyDenied;
        final unavailable = perm == PermState.unavailable;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Icon(Icons.sms_outlined, size: 40, color: p.accent),
            const SizedBox(height: 12),
            Text(tr.smsPermissionTitle, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: p.text)),
            const SizedBox(height: 10),
            Text(
              unavailable ? tr.smsUnavailable : (blocked ? tr.smsDeniedBody : tr.smsPermissionBody),
              style: TextStyle(fontSize: 14, color: p.textMuted, height: 1.45),
            ),
            const SizedBox(height: 20),
            if (!unavailable && !blocked) FilledButton(onPressed: _requestPermission, child: Text(tr.grantPermission)),
            if (blocked)
              FilledButton.icon(
                onPressed: () async {
                  await app.native.openAppSettings();
                },
                icon: const Icon(Icons.settings_outlined),
                label: Text(tr.openAppSettings),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                final perms = await app.refreshSmsPermissions();
                if (perms.canRead && mounted) setState(() => _step = _Step.range);
              },
              child: Text(tr.checkAgain),
            ),
            if (perm == PermState.denied || blocked)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(tr.manualStillWorks, style: TextStyle(fontSize: 13, color: p.textMuted)),
              ),
          ],
        );
      case _Step.range:
        final today = Day.today();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(tr.chooseRange, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.text)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final d in const [30, 90, 180, 365])
                ChoiceChip(
                  label: Text(tr.lastNDays(d)),
                  selected: _presetDays == d,
                  onSelected: (_) => setState(() {
                    _presetDays = d;
                    _range = DayRange(today.addDays(-(d - 1)), today);
                  }),
                ),
              ChoiceChip(
                label: Text(tr.periodCustom),
                selected: _presetDays == 0,
                onSelected: (_) async {
                  final r = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2010),
                    lastDate: today.startLocal,
                    initialDateRange: DateTimeRange(start: _range.start.startLocal, end: _range.end.startLocal),
                  );
                  if (r == null) return;
                  setState(() {
                    _presetDays = 0;
                    _range = DayRange(Day.fromDateTime(r.start), Day.fromDateTime(r.end));
                  });
                },
              ),
            ]),
            const SizedBox(height: 12),
            Text('${formatDayLong(_range.start)} – ${formatDayLong(_range.end)}',
                style: TextStyle(fontSize: 14, color: p.textMuted)),
            const SizedBox(height: 20),
            FilledButton.icon(onPressed: _scan, icon: const Icon(Icons.search), label: Text(tr.scanMessages)),
            const SizedBox(height: 8),
            Text(tr.scanLocalNote, style: TextStyle(fontSize: 12, color: p.textMuted)),
          ],
        );
      case _Step.scanning:
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LinearProgressIndicator(value: _progress.windowsTotal == 0 ? null : _progress.fraction),
              const SizedBox(height: 16),
              Text(tr.scanningProgress(_progress.scanned), style: TextStyle(color: p.text)),
            ],
          ),
        );
      case _Step.preview:
        final newOnes = _cands.where((c) => c.state == CandidateState.newTxn).toList();
        final review = _cands
            .where((c) => c.state == CandidateState.review || c.state == CandidateState.possibleDuplicate)
            .toList();
        final dups = _cands
            .where((c) => c.state == CandidateState.duplicate || c.state == CandidateState.ignoredByUser)
            .length;
        final notTxn = _cands.where((c) => c.state == CandidateState.notTransaction).length;
        final selected = _cands.where((c) => c.selected && (c.state == CandidateState.newTxn || c.state == CandidateState.review || c.state == CandidateState.possibleDuplicate)).length;
        Widget tile(IngestCandidate c) {
          final t = c.txn!;
          return CheckboxListTile(
            value: c.selected,
            onChanged: (v) => setState(() => c.selected = v ?? false),
            title: Text(
              t.amountMinor == null ? tr.amountUnclear : money(t.amountMinor!, t.currency),
              style: TextStyle(fontWeight: FontWeight.w600, color: p.text),
            ),
            subtitle: Text(
              [
                tr.txnTypeLabel(t.type),
                if (t.merchant.isNotEmpty) isolate(t.merchant),
                formatDateTimeMs(t.txnAt),
              ].join(' · '),
              style: TextStyle(fontSize: 12, color: p.textMuted),
            ),
          );
        }

        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  AppCard(
                    child: Column(
                      children: [
                        _count(p, tr.messagesScanned, _scanned),
                        _count(p, tr.transactionsRecognized, newOnes.length + review.length + dups),
                        _count(p, tr.duplicatesSkipped, dups),
                        _count(p, tr.itemsNeedingReview, review.length),
                        _count(p, tr.notTransactions, notTxn),
                      ],
                    ),
                  ),
                  if (newOnes.isEmpty && review.isEmpty)
                    EmptyState(icon: Icons.inbox_outlined, title: tr.nothingToImport, body: tr.nothingToImportBody),
                  if (newOnes.isNotEmpty) SectionLabel(tr.readyToImport(newOnes.length)),
                  for (final c in newOnes) tile(c),
                  if (review.isNotEmpty) SectionLabel(tr.importAsReview(review.length)),
                  for (final c in review) tile(c),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (selected == 0 || _committing) ? null : _commit,
                  child: Text(tr.importN(selected)),
                ),
              ),
            ),
          ],
        );
      case _Step.done:
        final r = _report!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Icon(Icons.check_circle_outline, size: 44, color: p.success),
            const SizedBox(height: 12),
            Text(tr.importDone, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: p.text)),
            const SizedBox(height: 12),
            AppCard(
              margin: EdgeInsets.zero,
              child: Column(children: [
                _count(p, tr.messagesScanned, r.scanned),
                _count(p, tr.saved, r.saved),
                _count(p, tr.duplicatesSkipped, r.duplicates),
                _count(p, tr.itemsNeedingReview, r.review),
              ]),
            ),
            const SizedBox(height: 16),
            if (!app.settings.smsNewMessages)
              OutlinedButton.icon(
                onPressed: () async {
                  final ok = await app.setNewMessageProcessing(true);
                  if (!ok && context.mounted) showInfoSnack(context, tr.permissionDenied);
                },
                icon: const Icon(Icons.bolt_outlined),
                label: Text(tr.alsoProcessNew),
              ),
            const SizedBox(height: 8),
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(tr.done)),
          ],
        );
    }
  }

  Widget _count(Palette p, String label, int n) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label, style: TextStyle(color: p.textMuted))),
            Text('$n', style: TextStyle(color: p.text, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}
