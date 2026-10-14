# SMS expense tracking — support, limits and policy

## How it works
| Path | Mechanism | Permission |
|---|---|---|
| Historical import | Reads `Telephony.Sms.Inbox` for a user-chosen date range, in weekly windows, on a background thread | `READ_SMS` |
| New messages | Manifest `BroadcastReceiver` for `SMS_RECEIVED` (still allowed for manifest receivers on current Android). Parts of a multipart message are joined per sender. | `RECEIVE_SMS` |
| Recovery | On every app start/resume, re-reads the inbox from the last scan time minus 6 h. Duplicates are skipped. | `READ_SMS` |

The receiver does **not** parse; it only runs a cheap financial pre-filter
(`FinancialFilter.kt`: digits + currency or amount word, and not an OTP) and stores
matching messages in a private queue (`SharedPreferences`, excluded from backups).
Dart parses the queue immediately if the app process is alive, otherwise on next launch.
Queue entries are deleted as soon as the parsed transaction is saved.

SMS access is **off by default**. Nothing is requested until the user opts in from the
Expenses page or Settings. The app never asks to become the default SMS app and never
changes messaging behaviour.

## Background behaviour (what to expect — needs confirmation on a real device)
| Situation | Expected behaviour |
|---|---|
| App open | Message queued by the receiver, parsed and saved within a second; totals update; optional notification. |
| App in background (process alive) | Same as above. |
| App swiped away / process killed | Receiver still runs (manifest receiver) and queues the message; it is saved next time the app opens. No transaction notification until then. |
| After reboot | Receiver works without opening the app (queue as above). Reminders are re-armed by `BootReceiver`. |
| After **Force stop** | Android delivers **no** broadcasts to a force-stopped app until the user opens it again. On next open, the inbox catch-up recovers missed messages. |
| Battery optimisation / OEM task killers | Some manufacturers delay or block receivers for "optimised" apps. Catch-up on open recovers missed messages. |

Not claimed: unrestricted background operation, real-time notifications while the
process is dead, or behaviour on every OEM skin.

## Google Play
Google Play restricts `READ_SMS` / `RECEIVE_SMS` to default SMS handlers or apps granted
an exception through the Permissions Declaration Form. An "SMS-based money management"
exception exists, but approval is at Google's discretion and the Spyware policy also
applies. **A working sideloaded APK does not imply Play eligibility.** This build is
intended for personal sideloading.

## Parser support
The parser is a generic Arabic/English engine (`lib/sms/sms_parser.dart`, version
`generic-1.0`) tested only against **synthetic** fixtures written to resemble common
Saudi bank formats (`test/sms_parser_test.dart`). **No specific bank is claimed as
supported.** Formats seen in fixtures:

- Purchase / POS / mada / Apple Pay wording, Arabic and English
- Online purchase in foreign currency with a SAR equivalent ("(SAR 97.46)", "بما يعادل")
- Refund, reversal, outgoing/incoming transfer, ATM withdrawal, credit-card repayment,
  standalone fee, salary/deposit, SADAD bill payment
- Arabic-Indic and Persian digits, Arabic decimal/thousands separators
- Messages with several amounts (balance, available limit, fee) — the transaction amount
  is chosen by its label, not by position; unresolved ambiguity goes to review

Ignored: OTP / verification codes, declined transactions, promotions, bill reminders,
balance-only messages, personal messages.

Known gaps / likely to need a bank adapter:
- Bank formats that put the amount on its own line with no keyword or currency
- Card statements and multi-transaction summaries
- Merchant names containing words used as stop markers (e.g. "at", "من")
- Dates written in Hijri calendar (ignored; SMS time used as marked fallback)
- English month-name dates without a year near New Year

### Adding a bank adapter
Implement `SmsParserAdapter` (match on sender id in `canHandle`), add synthetic fixtures
for every format you handle, and pass it to `SmsParser(bankAdapters: [...])`. Only claim
support for formats covered by fixtures.

## Privacy
- Parsing is on-device; no network permission is used by the app code.
- Raw SMS bodies are never stored in the database. Items needing review keep a short
  **redacted** excerpt (long digit runs and card digits masked), cleared on confirmation.
- Only the last 4 card/account digits are stored; the UI shows `•••• 1234`.
- Personal phone-number senders are masked.
- Nothing is logged.
- `finance.db` and the SMS queue are excluded from Android auto-backup and device transfer.
- Settings → Delete financial data removes all transactions, rules and ignore markers without
  touching tasks or habits.
