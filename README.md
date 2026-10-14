# Tarteeb — ترتيب

Offline Android app for personal **tasks**, **habits** and **SMS-based expense tracking**.
Arabic (RTL) by default, English available. No account, backend, ads, analytics or cloud AI.

| | |
|---|---|
| Framework | Flutter (Dart) + native Kotlin for SMS, reminders, files and encryption |
| Storage | SQLite (`tarteeb.db` for tasks/habits/settings, `finance.db` for money — kept separate) |
| Package id | `com.tarteeb.tarteeb` |

## Get the APK

### Option A — GitHub Actions (no tools needed)
1. Push this folder to a GitHub repository (private recommended).
2. The workflow `.github/workflows/build-apk.yml` runs on every push to `main`/`master`
   (or manually from the **Actions** tab → *Build APK* → *Run workflow*).
3. When it finishes, open the repo's **Releases** page on your phone, download
   `tarteeb-<n>.apk`, and allow installing from that source.

The workflow regenerates the standard Gradle scaffolding with `flutter create`, runs
`flutter analyze` and `flutter test`, then builds a release APK. Every build is signed
with the same key (`android/ci/debug.keystore`) so updates install over the previous
version without losing data. That key is for **personal sideloading only** — never use it
for a store release.

### Option B — build on your computer
Requirements: Flutter (stable), Android SDK, JDK 17.

```bash
cd tarteeb
flutter create --platforms=android --org com.tarteeb --project-name tarteeb .   # adds Gradle files, keeps existing ones
flutter pub get
flutter test
flutter build apk --release
# APK: build/app/outputs/flutter-apk/app-release.apk
```
To keep the same signature as CI builds: `cp android/ci/debug.keystore ~/.android/debug.keystore` before building.

Install on a connected phone: `flutter install` or `adb install -r build/app/outputs/flutter-apk/app-release.apk`.

## Project layout

```
lib/
  core/        Day (date-only type), money (integer minor units), strings (ar/en), formatting
  domain/      Models + pure logic: task grouping/calendar, habit streaks, finance totals, duplicates
  data/        SQLite schema, repositories, backups, demo data
  sms/         Normalizer, keyword packs, parser + adapter interface, ingest (dedupe/linking)
  notifications/ Reminder planning (what should be scheduled)
  platform/    MethodChannel bridge to Kotlin
  state/       AppState controller
  ui/          Screens: tasks, calendar, habits, expenses, settings
android/app/src/main/kotlin/com/tarteeb/tarteeb/
  MainActivity.kt      channel handlers: permissions, inbox read, files, crypto
  SmsReceiver.kt       SMS_RECEIVED receiver (multipart join, pre-filter, queue)
  SmsQueue.kt          persistent queue drained by Dart
  FinancialFilter.kt   on-device pre-filter (drops non-financial and OTP messages)
  Reminders.kt         AlarmManager reminders + boot/time-change receivers
  Notifications.kt     channels and notifications
  CryptoUtil.kt        AES-256-GCM + PBKDF2-HMAC-SHA256 for finance backups
test/          parser fixtures (synthetic), domain rules, SQLite integration, widgets
docs/          plan, SMS support & limitations, device test checklist
```

More: [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md) ·
[docs/SMS_SUPPORT.md](docs/SMS_SUPPORT.md) ·
[docs/DEVICE_TEST_CHECKLIST.md](docs/DEVICE_TEST_CHECKLIST.md)

## Fonts and assets
Tajawal (SIL Open Font License, `assets/fonts/OFL.txt`) is bundled. The app icon is original.
