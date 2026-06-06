# Conceal CMFA v0.1.0

Initial public release of Conceal Clash Meta For Android.

## Highlights

- Renamed the fork to Conceal CMFA / Conceal Clash Meta For Android.
- Changed the package name to `com.github.ychaiyi.conceal.clash.meta.for.android`.
- Added `RootProxyService` for root-controlled startup without Android `VpnService` consent dialogs.
- Added the `Conceal CMFA Root Proxy` SukiSU Ultra/Magisk module.
- Added transparent proxy config injection for `redir-port: 7892`, `tproxy-port: 7893`, and DNS listener `1053`.
- Added automatic module fallback from TPROXY to REDIR TCP/DNS mode.

## Assets

- APK: `conceal-clash-meta-for-android-2.11.30-meta-arm64-v8a-debug.apk`
- Module: `conceal-cmfa-root-proxy.zip`

SHA-256:

```text
1737bcd96d9b111740e985d5500015d4d801006f07436b16cafa172db945b1d1  conceal-clash-meta-for-android-2.11.30-meta-arm64-v8a-debug.apk
f679839947657a7e3f1cbab9bb4408c6d1407a37503b11c8131c7b0672d76a6f  conceal-cmfa-root-proxy.zip
```

The APK asset is the tested arm64 debug build from this development run. A formally signed release build should be produced later with project signing credentials.

## Install

1. Install the APK.
2. Open Conceal CMFA and select/import a valid profile.
3. Install the module zip from SukiSU Ultra.
4. Reboot, or press the module action button to toggle root proxy rules.

## Validation

- Device: Xiaomi 17 Pro
- Root manager: SukiSU Ultra
- Package: `com.github.ychaiyi.conceal.clash.meta.for.android`
- Module UI: SukiSU Ultra shows `Conceal CMFA Root Proxy` by `YChaiyi`.
- Result: RootProxyService started under the new package, `7892` and `1053` listened as app UID `10307`, the module selected REDIR TCP/DNS fallback, iptables counters hit, and HTTP connectivity returned `204 No Content`.

## Known Limits

- Full UDP TPROXY depends on the app opening `tproxy-port` and the ROM/kernel supporting the required iptables/ip rule path.
- On the tested Xiaomi 17 Pro build, `7893` did not listen, so v0.1.0 used REDIR TCP/DNS fallback.
