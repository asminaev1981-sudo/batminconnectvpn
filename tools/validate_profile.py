#!/usr/bin/env python3
import json, pathlib, sys
p = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "assets/config/batmin_hysteria2.json")
data = json.loads(p.read_text(encoding="utf-8"))
outbounds = data.get("outbounds", [])
hy2 = next((x for x in outbounds if x.get("type") == "hysteria2"), None)
if not hy2:
    raise SystemExit("ERROR: hysteria2 outbound not found")
required = ["server", "server_port", "password", "tls"]
missing = [k for k in required if k not in hy2]
if missing:
    raise SystemExit("ERROR: missing fields: " + ", ".join(missing))
print("OK: profile is valid JSON")
print(f"Server: {hy2['server']}:{hy2['server_port']}")
print("TLS insecure:", hy2["tls"].get("insecure", False))
