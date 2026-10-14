# Device test checklist

Use synthetic messages only: from a second phone, send yourself SMS texts copied from
`test/sms_parser_test.dart` (change the amount each time). Record pass/fail and the
Android version / phone model.

## Install
- [ ] APK installs; app opens in Arabic, RTL layout, Tajawal font.
- [ ] First-launch dialog offers sample data; choosing "Start empty" shows empty states.
- [ ] Install a newer CI build over the old one: data is preserved.

## Permissions
- [ ] Expenses page shows the onboarding card; no permission prompt before you tap.
- [ ] Import → explanation screen → system prompt appears only after "Grant permission".
- [ ] Deny once → guidance shown; manual "Add transaction" still works.
- [ ] Deny twice ("Don't ask again") → "App settings" button opens the app's settings page.
- [ ] Grant in system settings, return to app → "Check again" proceeds.
- [ ] Revoke SMS permission in system settings while processing is on → Expenses shows
      "permission was turned off"; no new transactions are recorded.
- [ ] Android 13+: notification permission prompt from Settings → Notifications.
- [ ] Android 12+: "On-time reminders" opens the Alarms & reminders page.

## Historical import
- [ ] Choose 30 days → progress, counts (scanned / recognized / duplicates / review / not transactions).
- [ ] Preview lists items; unticking one excludes it.
- [ ] Import again → 0 saved, all counted as duplicates.
- [ ] OTP and personal messages never appear in the preview.

## New messages (enable "Process new messages")
- [ ] App open: send a purchase SMS → transaction appears within seconds; totals update.
- [ ] App in background: send another → notification "Transaction recorded" (if enabled).
- [ ] App swiped from recents: send one → open app → it appears.
- [ ] Long multipart message (> 160 chars) → recorded once with the full text parsed.
- [ ] Reboot phone, do not open app, send one → open app → it appears once.
- [ ] Force stop in system settings, send one → open app → it appears once (recovered by catch-up).
- [ ] Same message delivered twice / inbox rescan (Settings → Rescan recent) → no duplicate.
- [ ] Two real purchases with the same amount at the same shop minutes apart → both kept
      (second may be in "Needs review" if the bank SMS has no time).
- [ ] Turn processing off → new messages are ignored.

## Parsing & accounting
- [ ] Message with balance + amount → amount is the transaction, not the balance.
- [ ] Refund → shown under refunds, net spending reduced once.
- [ ] Transfer / ATM / card repayment → shown under "Not counted as spending".
- [ ] Foreign currency without SAR equivalent → shown under "Other currencies", not added to SAR.
- [ ] Edit a transaction (amount, merchant, category, type) → Rescan → edit preserved.
- [ ] Ignore a transaction → Rescan → it does not come back.
- [ ] Review item: pick the correct amount chip → Confirm → counted in totals.
- [ ] Merchant rule: set category with "remember for this merchant" → next import uses it.

## Tasks, calendar, habits
- [ ] Circle tap completes only; card tap opens details; undo works.
- [ ] Completing a task with open subtasks asks first.
- [ ] Task with due date ≠ follow-up date appears on both calendar days; same day → one card, two labels.
- [ ] Reminder fires at the set time; editing the time reschedules; completing cancels.
- [ ] Reminder still fires after reboot.
- [ ] Habit: cannot complete tomorrow; unscheduled days don't break the streak; changing the
      schedule keeps past history.
- [ ] Habit reminder does not fire after the habit is already done today.

## Settings & backup
- [ ] Export (tasks & habits only) → JSON saved via the system file picker; contains no transactions.
- [ ] Export with finance → asks for a password; file contains only an encrypted blob for finance.
- [ ] Restore → preview counts → confirm → data replaced.
- [ ] Restore with wrong password → error, nothing changed.
- [ ] Restore a random/invalid file → error, nothing changed.
- [ ] Delete financial data → transactions gone, tasks and habits intact.
- [ ] Dark mode, English language, large system font: screens remain usable.
