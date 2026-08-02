# Release status — v0.4.0

Implemented:

- Real Hysteria2 client profile for the current server.
- Userpass represented correctly as `username:password`.
- Importable Hysteria2 URI.
- Server certificate and certificate analysis.
- JSON profile validation utility.
- Existing Flutter UI and Android VpnService bridge from v0.3.0.

Not yet implemented:

- Embedded libbox runtime.
- Starting sing-box from BatminVpnService.
- A signed standalone APK.

The profile files in `assets/config` can already be imported into a compatible client for immediate connectivity testing. The Batmin application source still requires the upstream libbox/SFA integration before it becomes an independent VPN client.
