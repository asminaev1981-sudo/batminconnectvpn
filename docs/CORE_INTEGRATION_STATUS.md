# Core integration status

Batmin Connect UI, Android VpnService bridge and the Batmin Hysteria2 profile are present.
The independent VPN runtime is not yet bundled. The blocking dependency is an Android-compatible libbox AAR/JNI package built from the sing-box core.

## Definition of done for the next release

1. `vendor/libbox.aar` is present and verified.
2. Gradle links the AAR.
3. `BatminVpnService` starts libbox with the packaged JSON configuration.
4. The TUN file descriptor is handed to the core.
5. Start, stop, state and structured logs work through MethodChannel.
6. A signed arm64 APK is produced and tested on a physical Android device.
