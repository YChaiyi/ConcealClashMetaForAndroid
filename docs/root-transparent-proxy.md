# Conceal CMFA Root Proxy

This fork adds a root-only launch path for Conceal CMFA, the short app name for Conceal Clash Meta For Android, and a SukiSU Ultra/Magisk-compatible companion module.

## What Changed

- `RootProxyService` starts Clash without `VpnService.prepare()` and writes `files/clash/root-transparent-proxy.enabled`.
- The native config patch detects that marker and injects:
  - `redir-port: 7892`
  - `tproxy-port: 7893`
  - `dns.listen: [::]:1053`
- The module starts `RootProxyService`, waits for either the TPROXY or REDIR listener, then applies owner-safe iptables/ip6tables rules.
- The module uses TPROXY when possible and falls back to REDIR TCP/DNS mode when only `redir-port` is available.
- The module skips the Conceal CMFA app UID to avoid proxy loops.

## Build

Build the app normally, then package the root module:

```bash
./gradlew :app:assembleMetaRelease
./tools/package-root-module.sh
```

The module zip is written to:

```text
build/root-module/conceal-cmfa-root-proxy.zip
```

## Install

1. Install the matching modified APK on the device.
2. Select/import a working profile in the app.
3. Install `conceal-cmfa-root-proxy.zip` in SukiSU Ultra or Magisk.
4. Reboot, or use the module action button to start/stop the rules.

## Runtime Defaults

The module defaults are in `sukisu-module/config.env`.

Important values:

```text
CMFA_PACKAGE=com.github.ychaiyi.conceal.clash.meta.for.android
CMFA_REDIR_PORT=7892
CMFA_TPROXY_PORT=7893
CMFA_DNS_PORT=1053
CMFA_PROXY_MODE=auto
CMFA_ENABLE_IPV6=1
```

Set `CMFA_PROXY_MODE=redir` to force TCP REDIR mode. Set `CMFA_ENABLE_IPV6=0` if the ROM/kernel rejects IPv6 TProxy rules.

## Manual Device Checks

```bash
adb shell su -c 'ls -l /data/adb/modules/cmfa-root-transparent-proxy'
adb shell su -c 'iptables -t mangle -S CMFA_PRE'
adb shell su -c 'ip rule show | grep 20230'
adb shell su -c 'cat /data/adb/modules/cmfa-root-transparent-proxy/cmfa-root.log'
```

Stopping the module action removes the iptables/ip6tables chains and deletes the root marker.

## Xiaomi 17 Pro Validation

The first device validation was performed on a Xiaomi 17 Pro with SukiSU Ultra. The app started as `com.github.ychaiyi.conceal.clash.meta.for.android`, exposed `7892` and `1053`, and the module selected REDIR TCP/DNS fallback because `7893` did not listen on that ROM/kernel combination.
