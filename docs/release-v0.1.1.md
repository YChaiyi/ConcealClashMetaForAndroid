# Conceal CMFA v0.1.1

Bug fix release for App-side start/stop behavior.

## Fixed

- App-side start now launches `RootProxyService` directly and no longer calls Android `VpnService.prepare()`.
- The main screen toggle, external-control intents, shortcuts, QS tile, and boot receiver now stay on the root transparent proxy path.
- The SukiSU module now runs a monitor process that syncs the app root marker to iptables state, so stopping from the app removes transparent proxy rules and starting from the app reapplies them.

## Assets

- APK: `conceal-clash-meta-for-android-2.11.30-meta-arm64-v8a-debug.apk`
- Module: `conceal-cmfa-root-proxy.zip`

SHA-256:

```text
6b1dfd7dee682914ecc0e1f5f2e7cb068789bdfce3fe7093b91963fe7c89aba5  conceal-clash-meta-for-android-2.11.30-meta-arm64-v8a-debug.apk
fca05cf914860d64fd31733daf9380e032b2ce5408d6cce046a46e53de7a84af  conceal-cmfa-root-proxy.zip
```

The APK asset is the tested arm64 debug build from this development run. A formally signed release build should be produced later with project signing credentials.

## Validation

- `:app:assembleMetaDebug` succeeded.
- Module shell syntax and zip integrity checks passed.
- Static scan confirms app-side start calls `RootProxyService` and no longer calls `VpnService.prepare()`.
- Device retest is pending because the Xiaomi 17 Pro is not currently visible in `adb devices`.
