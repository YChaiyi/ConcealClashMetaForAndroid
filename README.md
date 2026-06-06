# Conceal Clash Meta For Android

Conceal CMFA is a root-first, silent transparent proxy fork of [Clash Meta for Android](https://github.com/MetaCubeX/ClashMetaForAndroid).
It keeps the upstream Android UI and mihomo/Clash.Meta core, then adds a `RootProxyService` and a SukiSU Ultra/Magisk companion module so the app can be started without Android `VpnService` consent dialogs.

- Short app name: `Conceal CMFA`
- Long app name: `Conceal Clash Meta For Android`
- Package name: `com.github.ychaiyi.conceal.clash.meta.for.android`
- Module name: `Conceal CMFA Root Proxy`
- Author: `YChaiyi`

## Root Transparent Proxy

The companion module starts the app's `RootProxyService`, writes the root-mode marker in the app data directory, then applies owner-safe transparent proxy rules.

Runtime behavior:

- Injects `redir-port: 7892`, `tproxy-port: 7893`, and `dns.listen: [::]:1053` when root mode is enabled.
- Uses TPROXY automatically when the app opens the TPROXY listener.
- Falls back to REDIR TCP plus DNS transparent proxy when only `redir-port` is available.
- Skips the Conceal CMFA app UID to avoid proxy loops.

Tested on Xiaomi 17 Pro with SukiSU Ultra. On that device the app exposed `7892` and `1053`, while `7893` did not listen, so the module used REDIR TCP/DNS fallback successfully.

## Install

1. Install the matching Conceal CMFA APK.
2. Open the app once, import/select a working profile, and let it finish profile initialization.
3. Install `conceal-cmfa-root-proxy.zip` in SukiSU Ultra.
4. Reboot, or use the SukiSU module action button to toggle the proxy rules.

Current release artifacts:

- APK: `app/build/outputs/apk/meta/debug/conceal-clash-meta-for-android-2.11.30-meta-arm64-v8a-debug.apk`
- SukiSU module: `build/root-module/conceal-cmfa-root-proxy.zip`

## Build

```bash
git submodule update --init --recursive
./gradlew :app:assembleMetaRelease
./tools/package-root-module.sh
```

Create `local.properties` in the project root for local SDK paths and optional overrides:

```properties
sdk.dir=/path/to/android-sdk

# Optional local build overrides.
compile.sdk=36
target.sdk=35
ndk.version=26.1.10909125
build.tools.version=36.1.0
abi.filters=arm64-v8a
```

The `meta` flavor builds with the final package name `com.github.ychaiyi.conceal.clash.meta.for.android`.

## Automation

External control activity:

```text
com.github.kr328.clash.ExternalControlActivity
```

Intent actions:

```text
com.github.ychaiyi.conceal.clash.meta.for.android.action.TOGGLE_CLASH
com.github.ychaiyi.conceal.clash.meta.for.android.action.START_CLASH
com.github.ychaiyi.conceal.clash.meta.for.android.action.STOP_CLASH
```

Profile import schemes remain compatible:

```text
clash://install-config?url=<encoded URI>
clashmeta://install-config?url=<encoded URI>
```

## Upstream Credits

This project is based on [MetaCubeX/ClashMetaForAndroid](https://github.com/MetaCubeX/ClashMetaForAndroid) and the [MetaCubeX/Clash.Meta](https://github.com/MetaCubeX/Clash.Meta) core.
