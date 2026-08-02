#!/usr/bin/env bash
set -euo pipefail
flutter doctor
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
echo "APK: build/app/outputs/flutter-apk/app-debug.apk"
