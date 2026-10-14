# Implementation plan (as executed)

1. **Foundation** — Flutter project, SQLite schema (two DB files), `Day` date type,
   integer money, Arabic/English string table, theme (light blue-gray background,
   white rounded cards, calm blue accent, Tajawal font), RTL.
2. **Tasks** — categories (editable, reorderable, recolorable), sections
   (Overdue/Today/Upcoming/No date/Completed), priority, status, due date+time,
   reminder, separate follow-up date, waiting-on, subtasks, search/filter/sort,
   undo for completion and deletion, append-only follow-up updates, activity history.
3. **Calendar** — month grid with week-start preference, today vs selected,
   due/follow-up/habit markers, day agenda with Due/Follow-up labels, category filter,
   add task for the selected day.
4. **Habits** — icon, color, start date, daily or weekday schedule (versioned so
   changes are prospective), reminder, dated completion records, streak rules,
   monthly completion calendar.
5. **Expenses / SMS** — opt-in permissions, guided historical import with preview,
   receiver for new messages + persistent queue + inbox catch-up, generic Arabic/English
   parser with labelled amount selection, classification, duplicate detection,
   refund linking, review queue, merchant rules, manual entry, totals per currency.
6. **Settings & backups** — theme, language, week start, notification switches,
   SMS controls, versioned JSON backup (finance optional and encrypted), validated
   restore with preview, separate financial-data deletion, removable demo data.
7. **Verification** — unit tests (parser fixtures, domain rules), SQLite integration
   tests, widget test, CI build of a signed APK.

Decisions taken without asking (reasonable defaults):
- Minimum supported Android version follows the Flutter default; portrait only.
- SMS parsing runs in Dart; the native receiver only pre-filters and queues.
- Embedded fees inside a purchase/transfer message are recorded on that transaction for
  information but not added to spending (avoids double counting with separate fee alerts).
- Bill payments (e.g. SADAD) count as spending; credit-card repayments do not.
- Habits can be completed only on scheduled days; unscheduled days are neutral.
- Demo data is offered once at first launch and can be removed in Settings.
