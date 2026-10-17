# HarmonyOS build and signing handoff

The OHOS port is based on FlClash v0.9.0. The application bundle name is
`com.follow.clash`; its display name is `FlClash`.

## Windows prerequisites

- Clone branch `port-ohos` with its submodule into a path without spaces:

  ```powershell
  git clone --recurse-submodules --branch port-ohos https://github.com/seabodylibra/FlClash-ohos.git D:\Projects\FlClash-ohos
  Set-Location D:\Projects\FlClash-ohos
  ```

- Use OHOS Flutter `3.47.7-ohos-1.0.0` with its patched Dart SDK. Standard Flutter
  does not provide this port's `TargetPlatform.ohos` API.
- Install the real HarmonyOS SDK/NDK, Node, JDK, OHPM, Hvigor, Git Bash, Go, and
  Rust. Put their command directories on PATH. Rust uses the channel pinned in
  `plugins/rust_api/rust/rust-toolchain.toml` and the OHOS arm64 target.
- The current profile requires compatible/target SDK `6.1.1(24)`. The previous
  Windows build used the SDK compiler `26.0.0.105`. Only the Windows arm64 OHOS
  cross-build has produced a package during this porting session.

## Build

Set the SDK paths to the installation on your machine, then run:

```powershell
$env:HOS_SDK_HOME = 'D:\DevEco-Studio\sdk'
$env:OHOS_NDK_HOME = "$env:HOS_SDK_HOME\default\openharmony"
flutter pub get
pwsh -File tool/patch_ohos_ui_dependencies.ps1
bash tool/build_libclash_ohos.sh
flutter build hap --debug --no-pub
```

The reviewed UI dependency patch adds OHOS handling to `material_ui` and
`cupertino_ui` in the resolved package cache. Reapply it after changing or
reinstalling those dependencies. The Go command produces the shared library and
its C header from source; the Flutter build hook produces the Rust library.

Without a signing configuration, Hvigor can produce
`ohos/entry/build/default/outputs/default/entry-default-unsigned.hap` while the
Flutter wrapper reports failure because it cannot find a signed HAP. Check the
actual Hvigor task results before using this artifact. Configure your own debug
signing in DevEco Studio, or re-sign the unsigned HAP using your own certificate
and provisioning profile. Signing material is local and is not included here.

`EntryAbility` registers `PlatformPlugin` before Dart startup. It implements the
device information, package metadata, and path-provider channels used during
bootstrap with the real OHOS SDK. Shared preferences use the existing atomic
file store inside the app's sandbox. OHOS has no path-provider downloads API;
the app uses its sandbox directory when it needs a download fallback.

The app has not passed device verification. A device test of the earlier package
reached Flutter but failed on the missing device-info channel; the startup
platform implementations above address that failure and the other bootstrap
dependencies. Re-sign and retest startup, permissions, VPN start/stop, profile
editing, and background behavior. Host Flutter tests currently fail to launch
with `Invalid SDK hash` in this OHOS fork; that is not a passing test result.
