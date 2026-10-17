import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:sqlite3/src/hook/compile/description.dart';
import 'package:sqlite3/src/hook/compile/used_symbols.dart';

Future<bool> buildSqliteForOhos(
  BuildInput input,
  BuildOutputBuilder output,
) async {
  final code = input.config.code;
  final compiler = code.cCompiler?.compiler;
  if (code.targetOS != OS.linux ||
      code.targetArchitecture != Architecture.arm64 ||
      compiler == null) {
    return false;
  }
  final llvmBin = File.fromUri(compiler).parent;
  if (!File.fromUri(
    llvmBin.uri.resolve('aarch64-unknown-linux-ohos-clang'),
  ).existsSync()) {
    return false;
  }

  // This Flutter fork exposes OHOS as Linux; its glibc prebuilt cannot be used.
  final nativeRoot = llvmBin.parent.parent;
  final sysroot = Directory.fromUri(nativeRoot.uri.resolve('sysroot/'));
  final source = File.fromUri(input.packageRoot.resolve('hook/ohos/sqlite3.c'));
  final library = File.fromUri(input.outputDirectory.resolve('libsqlite3.so'));
  final libc = File.fromUri(
    sysroot.uri.resolve('usr/lib/aarch64-linux-ohos/libc.so'),
  );
  for (final file in [source, libc]) {
    if (!file.existsSync()) {
      throw StateError(
        'Required OHOS SQLite build input missing: ${file.path}',
      );
    }
  }
  await library.parent.create(recursive: true);
  final defines = CompilerDefines.defaults(false)
    ..remove('SQLITE_OMIT_DECLTYPE')
    ..['SQLITE_ENABLE_COLUMN_METADATA'] = null;
  final arguments = [
    '--target=aarch64-linux-ohos',
    '--sysroot=${sysroot.path}',
    '-D__MUSL__',
    '-O2',
    '-fPIC',
    '-shared',
    '-Wl,-soname,libsqlite3.so',
    '-Wl,-Bsymbolic',
    '-Wl,--no-undefined',
    for (final entry in defines.entries)
      '-D${entry.key}${entry.value == null ? '' : '=${entry.value}'}',
    source.path,
    '-o',
    library.path,
    '-lm',
    '-ldl',
    '-pthread',
  ];
  final result = await Process.run(compiler.toFilePath(), arguments);
  if (result.exitCode != 0) {
    throw ProcessException(
      compiler.toFilePath(),
      arguments,
      '${result.stdout}\n${result.stderr}',
      result.exitCode,
    );
  }
  final nm = llvmBin.uri.resolve(
    Platform.isWindows ? 'llvm-nm.exe' : 'llvm-nm',
  );
  final symbols = await Process.run(nm.toFilePath(), [
    '--dynamic',
    '--defined-only',
    '--format=posix',
    library.path,
  ]);
  if (symbols.exitCode != 0) {
    throw StateError('Cannot inspect OHOS SQLite exports: ${symbols.stderr}');
  }
  final exports = (symbols.stdout as String)
      .split('\n')
      .map((line) => line.split(' ').first)
      .toSet();
  final missing = usedSqliteSymbols.difference(exports);
  if (missing.isNotEmpty) {
    throw StateError('OHOS SQLite is missing required exports: $missing');
  }
  output.dependencies.addAll([source.uri, compiler, libc.uri]);
  output.assets.code.add(
    CodeAsset(
      package: input.packageName,
      name: 'src/ffi/libsqlite3.g.dart',
      linkMode: DynamicLoadingBundled(),
      file: library.uri,
    ),
  );
  return true;
}
