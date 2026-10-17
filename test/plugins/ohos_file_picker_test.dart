import 'dart:io';

import 'package:fl_clash/plugins/ohos_file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.follow.clash/file_picker');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('cancelling the native picker returns no file', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    expect(await OhosFilePicker.pickFile(), isNull);
  });

  test('native failures reach the caller', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'OHOS_FILE_PICKER_ERROR');
    });
    await expectLater(
      OhosFilePicker.pickFile(),
      throwsA(isA<PlatformException>()),
    );
  });

  test(
    'reads the sandbox copy while retaining the selected filename',
    () async {
      final directory = await Directory.systemTemp.createTemp('ohos-picker-');
      final file = File('${directory.path}/picked-cache');
      addTearDown(() async {
        await file.delete();
        await directory.delete();
      });
      final bytes = [0, 127, 128, 255];
      await file.writeAsBytes(bytes);
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'pickFile');
        return {'name': '配置.yaml', 'path': file.path, 'size': bytes.length};
      });

      final selected = (await OhosFilePicker.pickFile())!;
      expect(selected.name, '配置.yaml');
      expect(selected.extension, 'yaml');
      expect(selected.path, file.path);
      expect(selected.lengthSync(), bytes.length);
      expect(await selected.length(), bytes.length);
      expect(await selected.readAsBytes(), bytes);
      expect(
        await selected.readAsByteStream().expand((chunk) => chunk).toList(),
        bytes,
      );
    },
  );
}
