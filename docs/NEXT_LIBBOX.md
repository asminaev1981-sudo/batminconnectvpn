# Next integration step: libbox

The app now reaches one deliberate boundary: `TunnelController.start(profileJson)`.

To produce a real Hysteria2 tunnel, the repository needs a reproducible libbox artifact and its exact generated Android API:

1. Pin a sing-box/libbox source revision.
2. Build or obtain the Android AAR for required ABIs.
3. Place it under `android/app/libs/` and declare it in Gradle.
4. Replace the isolated reflective boundary in `TunnelController` with the pinned API.
5. Run an Android device test against `94.141.98.124:443`.

Until these files exist, Batmin Connect intentionally returns a visible error and never claims that traffic is protected.
