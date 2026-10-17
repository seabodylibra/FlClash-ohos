import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import { common } from '@kit.AbilityKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';

export default class FilePickerPlugin implements FlutterPlugin, MethodCallHandler {
  private context: common.UIAbilityContext
  private channel: MethodChannel | undefined
  private picking: boolean = false

  constructor(context: common.UIAbilityContext) {
    this.context = context
  }

  getUniqueClassName(): string {
    return 'FilePickerPlugin'
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'com.follow.clash/file_picker')
    this.channel.setMethodCallHandler(this)
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null)
    this.channel = undefined
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method !== 'pickFile') {
      result.notImplemented()
      return
    }
    if (this.picking) {
      result.error('PICKER_BUSY', 'A document picker is already open.', null)
      return
    }
    this.picking = true
    this.pickFile().then((file: Map<string, Object> | null) => {
      result.success(file)
    }).catch((error: Error) => {
      result.error('OHOS_FILE_PICKER_ERROR', error.message, null)
    }).finally(() => {
      this.picking = false
    })
  }

  private async pickFile(): Promise<Map<string, Object> | null> {
    const documentPicker = new picker.DocumentViewPicker(this.context)
    const options = new picker.DocumentSelectOptions()
    options.maxSelectNumber = 1
    const uris = await documentPicker.select(options)
    if (uris.length === 0) return null

    const source = await fs.open(uris[0], fs.OpenMode.READ_ONLY)
    const path = `${this.context.cacheDir}/picked-${util.generateRandomUUID()}`
    try {
      // Picker URI access is temporary; Dart reads a private cache copy.
      await fs.copyFile(source.fd, path)
      const stat = await fs.stat(path)
      const file = new Map<string, Object>()
      file.set('name', source.name)
      file.set('path', path)
      file.set('size', stat.size)
      return file
    } catch (error) {
      try { await fs.unlink(path) } catch (_) {}
      throw error as Error
    } finally {
      await fs.close(source)
    }
  }
}
