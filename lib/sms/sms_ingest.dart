import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../core/day.dart';
import '../data/finance_repo.dart';
import '../domain/finance_logic.dart';
import '../domain/finance_models.dart';
import 'normalizer.dart';
import 'sms_parser.dart';

String _sha(String s) => sha256.convert(utf8.encode(s)).toString();

String _normSender(String s) => s.trim().toLowerCase();

/// Stable id for a message. Prefixed 's:' when built from the service-centre
/// send time (identical for the broadcast copy and the inbox copy), 'r:' when
/// only the device receive time was known.
String sourceKeyFor(RawSms s) {
  final sender = _normSender(s.sender);
  if (s.sentAt > 0) return 's:${_sha('$sender|${s.sentAt}|${s.body}')}';
  return 'r:${_sha('$sender|${s.receivedAt}|${s.body}')}';
}

String bodyKeyFor(RawSms s) => _sha('${_normSender(s.sender)}|${s.body}');

enum CandidateState { newTxn, review, duplicate, possibleDuplicate, ignoredByUser, notTransaction }

class IngestCandidate {
  final RawSms raw;
  final ParseOutcome outcome;
  final FinTxn? txn;
  CandidateState state;
  bool selected;

  IngestCandidate(this.raw, this.outcome, this.txn, this.state) : selected = state == CandidateState.newTxn || state == CandidateState.review || state == CandidateState.possibleDuplicate;
}

class IngestReport {
  int scanned = 0;
  int recognized = 0;
  int duplicates = 0;
  int review = 0;
  int ignored = 0;
  int saved = 0;
  final List<FinTxn> savedTxns = [];
}

/// Turns raw SMS into transactions: parse, de-duplicate, apply merchant rules,
/// link refunds, and save atomically. Raw bodies are never persisted.
class SmsIngestService {
  final FinanceRepo repo;
  final SmsParser parser;

  SmsIngestService(this.repo, {SmsParser? parser}) : parser = parser ?? SmsParser();

  int _now() => AppClock.now().millisecondsSinceEpoch;

  FinTxn _toTxn(RawSms raw, ParsedTxn p, List<MerchantRule> rules) {
    final now = _now();
    final reasons = [...p.reviewReasons];
    final category = FinanceRepo.categoryFromRules(p.merchant, rules);
    return FinTxn(
      source: TxnSource.sms,
      status: reasons.isEmpty ? TxnStatus.confirmed : TxnStatus.needsReview,
      type: p.type,
      amountMinor: p.amountMinor,
      currency: p.currency,
      sarAmountMinor: p.sarAmountMinor,
      feeMinor: p.feeMinor,
      merchant: p.merchant,
      categoryId: category,
      txnAt: p.txnAt,
      tsSource: p.tsSource,
      smsAt: raw.receivedAt,
      sender: displaySender(raw.sender),
      accountLast4: p.accountLast4,
      reference: p.reference,
      confidence: p.confidence,
      parserVersion: p.parserVersion,
      sourceKey: sourceKeyFor(raw),
      bodyKey: bodyKeyFor(raw),
      reviewReason: reasons.join(','),
      excerpt: p.excerpt,
      candidates: p.candidates.join(','),
      createdAt: now,
      updatedAt: now,
    )..fingerprint = '';
  }

  /// Parses and classifies messages without writing anything (import preview).
  Future<List<IngestCandidate>> analyze(List<RawSms> messages) async {
    final rules = await repo.rules();
    final out = <IngestCandidate>[];
    final batch = <FinTxn>[];
    var tempId = -1;
    for (final raw in messages) {
      final outcome = parser.parse(raw);
      if (!outcome.isTransaction) {
        out.add(IngestCandidate(raw, outcome, null, CandidateState.notTransaction));
        continue;
      }
      final txn = _toTxn(raw, outcome.txn!, rules);
      txn.fingerprint = fingerprintOf(txn);
      if (await repo.isIgnored(repo.db, txn)) {
        out.add(IngestCandidate(raw, outcome, txn, CandidateState.ignoredByUser));
        continue;
      }
      final existing = [...await repo.nearby(repo.db, txn), ...batch];
      final dup = checkDuplicate(txn, existing);
      CandidateState state;
      if (dup.kind == DuplicateKind.exact) {
        state = CandidateState.duplicate;
      } else if (dup.kind == DuplicateKind.possible) {
        state = CandidateState.possibleDuplicate;
        txn.status = TxnStatus.needsReview;
        txn.duplicateOfId = (dup.matchId != null && dup.matchId! > 0) ? dup.matchId : null;
        txn.reviewReason = [
          if (txn.reviewReason.isNotEmpty) txn.reviewReason,
          ReviewReason.possibleDuplicate,
        ].join(',');
        if (txn.excerpt.isEmpty) {
          txn.excerpt = redactExcerpt(normalizeSms(raw.body).text, last4: txn.accountLast4);
        }
      } else {
        state = txn.status == TxnStatus.needsReview ? CandidateState.review : CandidateState.newTxn;
      }
      if (state != CandidateState.duplicate) {
        txn.id = tempId--;
        batch.add(txn);
      }
      out.add(IngestCandidate(raw, outcome, txn, state));
    }
    // Temporary ids were only for in-batch duplicate checks.
    for (final t in batch) {
      t.id = null;
    }
    return out;
  }

  /// Saves the selected candidates in one transaction. Duplicates are re-checked
  /// inside the transaction so concurrent paths (receiver + rescan) are safe.
  Future<IngestReport> commit(List<IngestCandidate> candidates, {int scanned = 0}) async {
    final report = IngestReport()..scanned = scanned;
    await repo.db.transaction((tx) async {
      for (final c in candidates) {
        if (c.state == CandidateState.notTransaction) {
          report.ignored++;
          continue;
        }
        report.recognized++;
        if (c.state == CandidateState.duplicate || c.state == CandidateState.ignoredByUser) {
          report.duplicates++;
          continue;
        }
        if (!c.selected) continue;
        final t = c.txn!;
        if (await repo.isIgnored(tx, t)) {
          report.duplicates++;
          continue;
        }
        final existing = await repo.nearby(tx, t);
        final dup = checkDuplicate(t, existing);
        if (dup.kind == DuplicateKind.exact) {
          report.duplicates++;
          continue;
        }
        if (dup.kind == DuplicateKind.possible && t.status != TxnStatus.needsReview) {
          t.status = TxnStatus.needsReview;
          t.duplicateOfId = dup.matchId;
          t.reviewReason = [if (t.reviewReason.isNotEmpty) t.reviewReason, ReviewReason.possibleDuplicate].join(',');
        } else if (dup.kind == DuplicateKind.possible) {
          t.duplicateOfId ??= dup.matchId;
        }
        if (typeIsRefundLike(t.type) && t.status == TxnStatus.confirmed) {
          final link = findRefundOriginal(t, existing);
          t.linkedTxnId = link;
          if (link == null && t.type == TxnType.reversal) {
            t.status = TxnStatus.needsReview;
            t.reviewReason = [if (t.reviewReason.isNotEmpty) t.reviewReason, ReviewReason.unlinkedReversal].join(',');
          }
        }
        t.duplicateOfId = (t.duplicateOfId != null && t.duplicateOfId! > 0) ? t.duplicateOfId : null;
        await repo.insertTxn(tx, t);
        report.saved++;
        report.savedTxns.add(t);
        if (t.status == TxnStatus.needsReview) report.review++;
      }
    });
    return report;
  }

  /// Convenience for incoming messages: analyze + commit everything recognised.
  Future<IngestReport> ingest(List<RawSms> messages) async {
    final cands = await analyze(messages);
    return commit(cands, scanned: messages.length);
  }
}

/// Confirms a review item after the user checked it.
void confirmReviewed(FinTxn t) {
  t.status = TxnStatus.confirmed;
  t.reviewReason = '';
  t.excerpt = '';
  t.candidates = '';
  t.duplicateOfId = null;
  t.userEdited = true;
}
