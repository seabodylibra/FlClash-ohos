import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

class OhosFilePicker {
  static const _channel = MethodChannel('com.follow.clash/file_picker');

  static Future<PlatformFile?> pickFile() async {
    final result = await _channel.invokeMapMethod<String, dynamic>('pickFile');
    if (result == null) return null;
    return _OhosPickedFile(
      name: result['name'] as String,
      xFile: XFile(result['path'] as String),
      size: result['size'] as int,
    );
  }
}

final class _OhosPickedFile extends PlatformFile {
  _OhosPickedFile({
    required this.name,
    required this.xFile,
    required this.size,
  });

  @override
  final String name;

  @override
  final XFile xFile;

  final int size;

  @override
  Uri get uri => Uri.file(xFile.path);

  @override
  int lengthSync() => size;

  @override
  Future<int> length() => xFile.length();

  @override
  Future<Uint8List> readAsBytes() => xFile.readAsBytes();

  @override
  Stream<Uint8List> readAsByteStream() =>
      xFile.openRead().map(Uint8List.fromList);
}
