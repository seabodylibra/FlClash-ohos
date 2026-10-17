import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:flutter_rust_bridge_hooks/flutter_rust_bridge_hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (input.userDefines['build_assets'] == false) {
      stdout.writeln('Skipping the Rust build: user-define build_assets=false');
      return;
    }
    final ohosNdkHome = _ohosNdkHome(input);
    if (ohosNdkHome != null &&
        input.config.code.targetOS == OS.linux &&
        input.config.code.targetArchitecture == Architecture.arm64) {
      await _buildOhosArm64(input, output, ohosNdkHome);
      return;
    }
    await FlutterRustBridgeNativeAssetsBuilder(
      cratePath: 'rust',
      extraCargoEnvironmentVariables: _bindgenEnvironment(input),
    ).run(input: input, output: output);
  });
}

String? _ohosNdkHome(BuildInput input) {
  final configured = Platform.environment['OHOS_NDK_HOME'];
  if (configured != null && configured.isNotEmpty) {
    return configured;
  }
  for (final key in const ['HOS_SDK_HOME', 'DEVECO_SDK_HOME']) {
    final sdkHome = Platform.environment[key];
    if (sdkHome != null && sdkHome.isNotEmpty) {
      return '$sdkHome${Platform.pathSeparator}default'
          '${Platform.pathSeparator}openharmony';
    }
  }
  final compiler = input.config.code.cCompiler?.compiler;
  if (compiler == null) {
    return null;
  }
  final llvmBin = File.fromUri(compiler).parent;
  final ndkHome = llvmBin.parent.parent.parent;
  if (File('${llvmBin.path}${Platform.pathSeparator}clang.exe').existsSync() &&
      File(
        '${llvmBin.path}${Platform.pathSeparator}'
        'aarch64-unknown-linux-ohos-clang',
      ).existsSync() &&
      Directory(
        '${ndkHome.path}${Platform.pathSeparator}native'
        '${Platform.pathSeparator}sysroot',
      ).existsSync()) {
    return ndkHome.path;
  }
  return null;
}

Future<void> _buildOhosArm64(
  BuildInput input,
  BuildOutputBuilder output,
  String ndkHome,
) async {
  const target = 'aarch64-unknown-linux-ohos';
  const libraryName = 'rust_api';
  const assetName = 'src/rust/frb_generated.io.dart';
  final linkMode = DynamicLoadingBundled();
  final llvmBin =
      '$ndkHome${Platform.pathSeparator}native'
      '${Platform.pathSeparator}llvm${Platform.pathSeparator}bin';
  final sysroot =
      '$ndkHome${Platform.pathSeparator}native'
      '${Platform.pathSeparator}sysroot';
  final clang = '$llvmBin${Platform.pathSeparator}clang.exe';
  final clangxx = '$llvmBin${Platform.pathSeparator}clang++.exe';
  final llvmRoot = Directory(llvmBin).parent.path;
  final clangResourceRoot = Directory(
    '$llvmRoot${Platform.pathSeparator}lib'
    '${Platform.pathSeparator}clang',
  );
  final clangResource = clangResourceRoot
      .listSync()
      .whereType<Directory>()
      .firstOrNull;
  if (clangResource == null) {
    throw StateError(
      'No Clang resource directory under ${clangResourceRoot.path}.',
    );
  }
  final rustup = Platform.isWindows ? 'rustup.exe' : 'rustup';
  final crateRoot = Directory.fromUri(input.packageRoot).uri.resolve('rust/');
  final manifest = File.fromUri(crateRoot.resolve('Cargo.toml'));
  final toolchainFile = File.fromUri(crateRoot.resolve('rust-toolchain.toml'));
  final toolchain = RegExp(
    r'^channel\s*=\s*"([^"]+)"',
    multiLine: true,
  ).firstMatch(await toolchainFile.readAsString())?.group(1);
  if (toolchain == null) {
    throw StateError(
      'Could not read the Rust channel from ${toolchainFile.path}.',
    );
  }
  for (final path in [clang, clangxx, manifest.path]) {
    if (!File(path).existsSync()) {
      throw StateError('Required OHOS build input does not exist: $path');
    }
  }

  final outputDirectory = Directory.fromUri(input.outputDirectory);
  final targetDirectory = Directory(
    '${outputDirectory.path}${Platform.pathSeparator}target',
  );
  await targetDirectory.create(recursive: true);
  final targetEnv = target.replaceAll('-', '_');
  final compilerFlags =
      '--target=aarch64-linux-ohos --sysroot=$sysroot -D__MUSL__'.replaceAll(
        r'\',
        '/',
      );
  final environment = <String, String>{
    'CC_$targetEnv': clang,
    'CXX_$targetEnv': clangxx,
    'CFLAGS_$targetEnv': compilerFlags,
    'CXXFLAGS_$targetEnv': compilerFlags,
    'CARGO_TARGET_${targetEnv.toUpperCase()}_LINKER': clang,
    'LIBCLANG_PATH': llvmBin,
    'BINDGEN_EXTRA_CLANG_ARGS':
        '$compilerFlags -resource-dir=${clangResource.path}'.replaceAll(
          r'\',
          '/',
        ),
    'RUSTFLAGS':
        '-C link-arg=--target=aarch64-linux-ohos '
        '-C link-arg=--sysroot=${sysroot.replaceAll(r'\', '/')} '
        '-C link-arg=-D__MUSL__',
    'AR_$targetEnv': '$llvmBin${Platform.pathSeparator}llvm-ar.exe',
    'RANLIB_$targetEnv': '$llvmBin${Platform.pathSeparator}llvm-ranlib.exe',
  };
  final result = await Process.run(
    rustup,
    [
      'run',
      toolchain,
      'cargo',
      'build',
      '--release',
      '--manifest-path',
      manifest.path,
      '--package',
      libraryName,
      '--target',
      target,
      '--target-dir',
      targetDirectory.path,
    ],
    workingDirectory: crateRoot.toFilePath(),
    environment: environment,
    includeParentEnvironment: true,
    runInShell: Platform.isWindows,
  );
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    throw ProcessException(
      rustup,
      [],
      'OHOS Rust build failed',
      result.exitCode,
    );
  }

  final library = File(
    '${targetDirectory.path}${Platform.pathSeparator}$target'
    '${Platform.pathSeparator}release${Platform.pathSeparator}lib$libraryName.so',
  );
  if (!library.existsSync()) {
    throw StateError('OHOS Rust library was not produced: ${library.path}');
  }
  output.assets.code.add(
    CodeAsset(
      package: input.packageName,
      name: assetName,
      linkMode: linkMode,
      file: library.uri,
    ),
  );
}

// rquickjs runs bindgen on Android, which must load the NDK's libclang; Linux
// NDKs before r26 keep it under lib64, later ones and every macOS NDK under lib.
Map<String, String> _bindgenEnvironment(BuildInput input) {
  if (!input.config.buildCodeAssets ||
      input.config.code.targetOS != OS.android) {
    return const {};
  }
  final compiler = input.config.code.cCompiler?.compiler;
  if (compiler == null) {
    return const {};
  }
  final llvmRoot = File.fromUri(compiler).parent.parent;
  for (final name in const ['lib', 'lib64']) {
    final directory = Directory(
      '${llvmRoot.path}${Platform.pathSeparator}$name',
    );
    if (directory.existsSync() && directory.listSync().any(_isLibclang)) {
      return {'LIBCLANG_PATH': directory.path};
    }
  }
  throw StateError(
    'No libclang under ${llvmRoot.path} (lib or lib64); the NDK Flutter '
    'passed cannot run bindgen for rquickjs',
  );
}

bool _isLibclang(FileSystemEntity entity) {
  return entity.path.split(Platform.pathSeparator).last.startsWith('libclang.');
}
