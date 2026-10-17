# FlClash HarmonyOS port: handoff checklist

## Windows follow-up (2026-10-17)

- Device retesting reached Drift database startup, then rejected the bundled Linux/glibc SQLite library (`fcntl64: symbol not found`). `tool/patch_ohos_sqlite.ps1` now installs an OHOS-only source-build hook for sqlite3 3.7.0, using checksum-pinned SQLite 3.53.4 and the real NDK sysroot. Reapply after `pub get` when preparing OHOS builds; the script invalidates the hosted hook cache. The next package uses build number `2026101703` and still requires device retesting.
- Real SDK packaging succeeded for `2026101703`. Inspection of its packaged SQLite found no `fcntl64` or glibc dependency; all 85 strong imports resolve against NDK libc and all 77 Dart SQLite exports are present. The hook also checks those exports before publishing its native asset. Flutter's unsigned-output wrapper still returns 1; Hvigor packaging succeeds. Host Flutter tests remain blocked by the previously observed `Invalid SDK hash` and were not rerun for this native-only build fix.
- A subsequent device screenshot reported `MissingPluginException` for `dev.fluttercommunity.plus/device_info`. `PlatformPlugin` now implements the three native startup channels (device info, package metadata, sandbox paths); OHOS preferences use `AtomicFilePreferencesStore`, and API-version parsing reads generic device data instead of a dynamic getter. The revised package uses build number `2026101702`.
- Focused system/path/preferences tests compiled but the host Flutter test engine could not load their kernel (`Invalid SDK hash`). The real OHOS SDK compiled the new ETS plugin and produced a fresh unsigned HAP; device startup still needs retesting.
- Publish the app source to `seabodylibra/FlClash-ohos`, branch `port-ohos`.
- The Core DNS patch is published to `seabodylibra/Clash.Meta-ohos`, branch `port-ohos`, commit `aa8ac85043282029a54f1cf3de18bc8d254dd2b6`. The parent gitlink must reference that commit.
- A real SDK is installed at `D:\DevEco-Studio\sdk`. The installed compiler reports `26.0.0.105`; the app build profile uses compatible/target SDK `6.1.1(24)`.
- The Windows OHOS Flutter toolchain reports `3.47.7-ohos-1.0.0`, Dart `3.13.3`. Go and Rust are installed under the local ignored `.dart_tool/toolchains/` directory; add them to the build process PATH.
- Go, Rust, NAPI, and Hvigor previously produced `ohos/entry/build/default/outputs/default/entry-default-unsigned.hap`. No signing configuration was present, so the Flutter wrapper failed while looking for a signed output. This is an unsigned build artifact, not a verified installable package.
- Current HAP builds include the ETS stop-result correction. User device tests now launch Flutter and reach database initialization; the agent has not completed device validation of VPN or Core lifecycle behavior.
- `flutter pub get` passed outside the sandbox, as did `flutter analyze --no-pub --no-fatal-infos` and `git diff --check`.
- `CGO_ENABLED=0 go vet . ./cmd/...` passed. Outside the sandbox, `CGO_ENABLED=0 go test .` failed in `TestHandleValidateProxiesLeavesARunningProxysResolverInPlace`: the Windows safe-path error names `C:\outside`, while the assertion expects the proxy name. This failure remains unresolved.
- The focused `flutter test --no-pub test/common/network_test.dart test/plugins/service_test.dart` run did not reach the tests: native hooks encountered path quoting, sandbox access, and Cargo default-toolchain discovery failures. Rust itself is installed; test execution is not verified.
- Windows build prerequisites, commands, unsigned output location, and signing handoff are in [ohos/README.md](ohos/README.md).

The remaining sections preserve the original Linux archive handoff. Their environment paths, missing-tool reports, and check results describe that earlier host.

## Goal and source

- Continue validating and completing the FlClash HarmonyOS port on the `port-ohos` branch.
- Port baseline: upstream FlClash v0.9.0; HarmonyOS adaptation was carried forward from `v0.8.94+2026091802`.
- Starting project commit: `f8a368b0e25082030f21a96c103929e16525ef4e` (`feat(ohos): port HarmonyOS adaptation to v0.9.0`).
- Original archive was `flclash-ohos-port-v090.zip`; accompanying notes were `flclash-ohos-port-README.md` in the user's Google Drive.
- Current workspace: `/workspace/scratch/607bf84f9ef1/ohos-port`.

## Current repository state

- Branch remains `port-ohos`; HEAD remains `f8a368b`.
- The archive contained 11 staged paths: nine code/script file paths, this handoff document, and the submodule gitlink. The original "nine changes" count excluded the document and gitlink; it was not the complete staged path count. No commit or push had been made at that handoff:
  - Added the missing `core/Clash.Meta` gitlink at `8380d0e7462f061a964323e9bf3129a236fcc5d5`.
  - Regenerated four Freezed/Riverpod output files.
  - Fixed a missing `globalState` import in `lib/manager/core_manager.dart`.
  - Removed invalid `final` modifiers from two callback parameters.
  - Updated the network test fake to use `InternetAddress`, which is available under this package's Dart language version.
- Fixed `tool/build_libclash_ohos.sh` path resolution: it previously searched outside the repository for `core/` and output directories.
- The archive's main Git tree did not contain the `core/Clash.Meta` gitlink even though `.gitmodules` declares it. The staged gitlink repairs that checkout gap. Its source tree is present locally and `git submodule status` reports the expected commit.
- Root `pubspec.yaml` has its original SDK constraint and both native build hooks restored to `build_assets: true`.
- Check `git status --short` before editing; preserve the staged work unless intentionally changing it.

## Validation already completed

- `flutter pub get` resolved dependencies successfully after setting `HOS_SDK_HOME` to a temporary SDK-shaped stub. This only bypassed Flutter's SDK-presence check; it is not a real HarmonyOS SDK and does not validate HAP building.
- `dart run build_runner build --delete-conflicting-outputs` completed and wrote 1,447 generated outputs. The installed `build_runner` reports that this CLI option has been removed and ignored, but generation completed successfully.
- `flutter analyze --no-fatal-infos`: passed with “No issues found”.
- In `core/`, `CGO_ENABLED=0 go test .`: passed.
- In `core/`, `CGO_ENABLED=0 go vet . ./cmd/...`: passed.
- `bash -n tool/build_libclash_ohos.sh`: passed; invoking it without the NDK now exits with the expected `OHOS_NDK_HOME not set` message.
- `git diff --cached --check`: passed.

## Blockers found

1. Full `flutter test` does not compile with the current host toolchain. Flutter 3.47.7 OHOS falls back to the upstream Linux Dart SDK because its OHOS override file does not provide a Linux x64 Dart SDK artifact. The compiler then crashes on the OHOS `Abi` mapping (`Type IntPtr has no mapping for ABI ... ohos/arm`).
2. Test compilation also reports many non-exhaustive `TargetPlatform` switches in hosted `material_ui 1.5.0` and `cupertino_ui 1.1.1`; those dependency sources do not handle the OHOS enum member. The normal Flutter analyzer did not expose these because it analyzes the app package, while the test compiler loads those dependencies.
3. There is no real HarmonyOS SDK, OHOS NDK, `ohpm`, or `hvigor` installed in this workspace. The temporary `hmos-sdk-stub` must never be used for an actual build.
4. Rust tooling (`cargo`, `rustc`) and `flutter_rust_bridge_codegen` are not installed, so Rust bridge generation/build was not run.
5. No HAP build, `libclash.so` OHOS build, device install, or runtime test has succeeded yet.

## Continue in this order

- [ ] Install a real HarmonyOS SDK that meets this repository's build profiles (the project targets SDK 6.1 / API 23), plus matching `ohpm`, `hvigor`, Node, and JDK tools. Set `HOS_SDK_HOME` or `DEVECO_SDK_HOME` to the actual SDK.
- [ ] Obtain a Linux x64 OHOS-patched Dart SDK compatible with the chosen Flutter OHOS fork, or use a supported host that has a published patched Dart SDK. Confirm `dart:ffi` exposes the OHOS ABIs before rerunning tests.
- [ ] Resolve the `material_ui` / `cupertino_ui` OHOS switch errors in a maintainable dependency source (a compatible fork or reviewed project patch), then rerun `flutter test`.
- [ ] Install Rust and `flutter_rust_bridge_codegen`; regenerate the bridge from `plugins/rust_api/flutter_rust_bridge.yaml` if the supplied generated files are placeholders or stale. Verify generated output is source-derived, not hand-edited.
- [ ] Build the OHOS Go shared library with `OHOS_NDK_HOME` set, from the repository root:

  ```sh
  ./tool/build_libclash_ohos.sh
  ```

- [ ] Build a debug HAP using the repository's normal workflow and the actual HarmonyOS SDK. Fix any remaining Dart, plugin, ETS/NAPI, Go, Rust, or Hvigor errors.
- [ ] Install the HAP on an actual HarmonyOS device; exercise first launch, permission/VPN flow, core start/stop, profile import/editing, background keep-alive, crash reporting, and unsupported-setting visibility.
- [ ] Rerun `flutter pub get`, code generation, `flutter analyze --no-fatal-infos`, the full Flutter test suite, Go tests/vet, `tool/build_libclash_ohos.sh`, HAP build, and device checks. Review `git diff --check` and the final diff before committing.

## Reproducible command environment used for host-side checks

The paths below are specific to the current workspace and can disappear when it is reset:

```sh
export PATH=/workspace/scratch/607bf84f9ef1/flutter-ohos/bin:/workspace/scratch/607bf84f9ef1/flutter-ohos/bin/cache/dart-sdk/bin:/workspace/scratch/607bf84f9ef1/go/bin:$PATH
export CI=true BOT=true FLUTTER_SUPPRESS_ANALYTICS=true TAR_OPTIONS=--no-same-owner
```

Flutter version used: `3.47.7-ohos-1.0.0`, Dart `3.13.5`. Go version used: `go1.27.1 linux/amd64`.
