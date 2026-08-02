$ErrorActionPreference = "Stop"
flutter doctor
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
Write-Host "APK: build/app/outputs/flutter-apk/app-debug.apk"
