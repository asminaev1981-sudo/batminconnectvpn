# Native VPN engine

Place the pinned `libbox.aar` in this directory.

Expected path:

```text
android/app/libs/libbox.aar
```

Use `scripts/build_libbox_android.sh` to build it from the pinned sing-box source.
The AAR is intentionally not committed because it is a large generated binary and its
license/source revision must be tracked separately.
