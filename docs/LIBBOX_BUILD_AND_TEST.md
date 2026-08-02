# libbox: сборка и контрольная проверка

## 1. Требования

- Linux/macOS or WSL2
- Git
- Go toolchain supported by the pinned sing-box release
- Android SDK/NDK
- Flutter SDK
- JDK 17 or newer

## 2. Build the native engine

```bash
./scripts/build_libbox_android.sh
```

The script pins sing-box to `v1.13.12`, builds the Android AAR with the
upstream `cmd/internal/build_libbox` command, copies it to
`android/app/libs/libbox.aar`, and writes revision/checksum metadata.

## 3. Inspect generated API

```bash
./scripts/inspect_libbox_aar.sh
```

## 4. Build the app

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

## 5. Device smoke test

1. Install `build/app/outputs/flutter-apk/app-debug.apk`.
2. Open Batmin Connect and press Connect.
3. Grant Android VPN permission.
4. Open Diagnostics/Logs.
5. Confirm that `libbox обнаружен` is present.

The current package deliberately stops before claiming VPN protection until
Android `PlatformInterface` is bound to the generated libbox API.
