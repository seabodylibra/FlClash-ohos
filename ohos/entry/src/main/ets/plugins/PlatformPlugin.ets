import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import { bundleManager, common } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';

export default class PlatformPlugin implements FlutterPlugin, MethodCallHandler {
  private context: common.UIAbilityContext
  private channels: MethodChannel[] = []

  constructor(context: common.UIAbilityContext) {
    this.context = context
  }

  getUniqueClassName(): string {
    return 'PlatformPlugin'
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    for (const name of [
      'dev.fluttercommunity.plus/device_info',
      'dev.fluttercommunity.plus/package_info',
      'plugins.flutter.io/path_provider',
    ]) {
      const channel = new MethodChannel(binding.getBinaryMessenger(), name)
      channel.setMethodCallHandler(this)
      this.channels.push(channel)
    }
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    for (const channel of this.channels) channel.setMethodCallHandler(null)
    this.channels = []
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    try {
      switch (call.method) {
        case 'getDeviceInfo': {
          const info = new Map<string, Object>()
          info.set('sdkApiVersion', deviceInfo.sdkApiVersion)
          info.set('deviceType', deviceInfo.deviceType)
          result.success(info)
          break
        }
        case 'getAll':
          this.getPackageInfo(result)
          break
        case 'getTemporaryDirectory':
          result.success(this.context.tempDir)
          break
        case 'getApplicationSupportDirectory':
        case 'getApplicationDocumentsDirectory':
          result.success(this.context.filesDir)
          break
        case 'getApplicationCacheDirectory':
          result.success(this.context.cacheDir)
          break
        default:
          result.notImplemented()
      }
    } catch (error) {
      result.error('OHOS_PLATFORM_ERROR', (error as Error).message, null)
    }
  }

  private getPackageInfo(result: MethodResult): void {
    bundleManager.getBundleInfoForSelf(
      bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION,
    ).then((bundle: bundleManager.BundleInfo) => {
      const info = new Map<string, Object>()
      info.set('appName', this.context.resourceManager.getStringSync(bundle.appInfo.labelId))
      info.set('packageName', bundle.name)
      info.set('version', bundle.versionName)
      info.set('buildNumber', bundle.versionCode.toString())
      result.success(info)
    }).catch((error: Error) => {
      result.error('OHOS_PACKAGE_INFO_ERROR', error.message, null)
    })
  }
}
