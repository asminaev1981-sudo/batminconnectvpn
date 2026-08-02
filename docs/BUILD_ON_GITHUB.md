# Build Batmin Connect in GitHub Actions

1. Push this project to the `main` branch.
2. Open **Actions → Batmin Connect Android → Run workflow**.
3. Wait for the `build` job to finish.
4. Download the artifact named `batmin-connect-debug-arm64`.
5. Extract `Batmin_Connect_0.6.4-10_debug.zip` and install `Batmin-Connect-debug.apk`.

The workflow builds the pinned sing-box native engine first, inspects its generated Java API, runs Flutter analysis/tests, and then builds an ARM64 debug APK.

A successful APK build proves packaging and native-library inclusion. It does not by itself prove that the current Android platform adapter can establish a tunnel; device logs remain required for that validation.
