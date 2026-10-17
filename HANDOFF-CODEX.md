# FlClash HarmonyOS port: handoff checklist

## Goal and source

- Continue validating and completing the FlClash HarmonyOS port on the `port-ohos` branch.
- Port baseline: upstream FlClash v0.9.0; HarmonyOS adaptation was carried forward from `v0.8.94+2026091802`.
- Starting project commit: `f8a368b0e25082030f21a96c103929e16525ef4e` (`feat(ohos): port HarmonyOS adaptation to v0.9.0`).
- Original archive was `flclash-ohos-port-v090.zip`; accompanying notes were `flclash-ohos-port-README.md` in the user's Google Drive.
- Current workspace: `/workspace/scratch/607bf84f9ef1/ohos-port`.

## Current repository state

- Branch remains `port-ohos`; HEAD remains `f8a368b`.
- Nine changes are staged for review; no commit or push has been made:
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
