#!/usr/bin/env bash
# Generates the standard Android/Gradle scaffolding for the installed Flutter
# version (existing files are kept), then builds a release APK.
set -euo pipefail
cd "$(dirname "$0")/.."
flutter create --platforms=android --org com.tarteeb --project-name tarteeb .
flutter pub get
flutter test || echo "WARNING: some tests failed"
mkdir -p ~/.android
[ -f ~/.android/debug.keystore ] || cp android/ci/debug.keystore ~/.android/debug.keystore
flutter build apk --release
echo "APK: build/app/outputs/flutter-apk/app-release.apk"
