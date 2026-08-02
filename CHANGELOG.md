# Changelog

## 0.6.1 — VPN Foundation

- Replaced simulated Flutter connection delays with Android VPN permission and service calls.
- Added explicit connection state machine: preparing, connecting, connected, disconnecting, error.
- Added Hysteria2 profile loading from Flutter assets and transfer to Android.
- Added native status details and in-memory VPN log retrieval through MethodChannel.
- Added `TunnelController` as the isolated libbox integration boundary.
- Added JSON profile validation and explicit failure when libbox binary is absent.
- Fixed duplicate `flutter:` section in `pubspec.yaml`.
- Fixed nullable connection message mismatch.

### Honest runtime status

The Flutter↔Android service lifecycle is implemented. A real network tunnel is not yet created because a pinned libbox AAR/JNI artifact is not present in this repository. The application now reports this as an error instead of falsely displaying a connected state.

## 0.6.2+8 — Native engine bootstrap

- Added reproducible pinned libbox Android build script.
- Added conditional AAR packaging in Gradle.
- Added AAR API inspection script and revision/checksum metadata.
- Added runtime libbox compatibility probe.
- Improved fail-closed diagnostics for missing or incompatible bindings.

## 0.6.4+10 — CI native-engine build

- GitHub Actions now builds the pinned `libbox.aar` before compiling Flutter.
- Added Java 17, Go 1.24 and Flutter toolchain setup in CI.
- Added native API inspection report as a build artifact.
- Added reproducible Android test-release packaging with APK SHA-256.
- Restricted the debug APK to ARM64, matching the target Pixel device.
