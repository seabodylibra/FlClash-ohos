import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import { CallbackStub, ResultStub } from '../entryability/EntryAbility'
import { State, VpnOptions } from '../models/State'
import { publishEvent } from '../utils/Event'
import { globalState, RunState } from '../GlobalState';
import { util } from '@kit.ArkTS'
import EntryAbility from '../entryability/EntryAbility';

interface PendingCoreRequest {
  callback: CallbackStub
  fail: (code: string, message: string) => void
}

interface CoreRequest {
  method: string
}

export default class ServicePlugin implements FlutterPlugin, MethodCallHandler {
  private parent: EntryAbility
  private channel: MethodChannel | undefined
  private commandRevision: number = 0
  private transition: Promise<void> = Promise.resolve()
  private nextRequestId: number = 0
  private pending: Map<number, PendingCoreRequest> = new Map()
  private eventCallback: CallbackStub | undefined

  constructor(entryAbility: EntryAbility) {
    this.parent = entryAbility
  }

  getUniqueClassName(): string {
    return "ServicePlugin"
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), "com.follow.clash/service")
    this.channel.setMethodCallHandler(this)
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.failPending('OHOS_CORE_DETACHED', 'Flutter engine detached from Core.')
    this.eventCallback = undefined
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null)
    }
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method === "init") {
      this.handleInit(result)
    } else if (call.method === "shutdown") {
      this.handleShutdown(result)
    } else if (call.method === "syncState") {
      this.handleSyncState(call, result)
    } else if (call.method === "invokeMethod") {
      this.handleInvokeMethod(call, result)
    } else if (call.method === "start") {
      this.handleStart(call, result)
    } else if (call.method === "stop") {
      this.handleStop(call, result)
    } else if (call.method === "getRunTime") {
      this.handleGetRunTime(result)
    } else {
      result.notImplemented()
    }
  }

  private handleInit(result: MethodResult): void {
    const callbackStub = new CallbackStub("setEventListener", (data: string) => { this.channel?.invokeMethod("event", data) })
    this.eventCallback = callbackStub
    this.parent.handleInit(callbackStub).then(() => {
      result.success("")
    }).catch((err: Error) => {
      result.success(err.message ?? `${err}`)
    })
    this.parent.setOnDisconnected((message: string) => {
      this.failPending('OHOS_CORE_DISCONNECTED', message)
      globalState.runTime = 0
      globalState.runState = RunState.stop
      this.channel?.invokeMethod("crash", message)
      publishEvent('SERVICE_STOP', '')
    })
  }

  private handleShutdown(result: MethodResult): void {
    this.parent.handleShutdown().finally(() => {
      globalState.runTime = 0
      globalState.runState = RunState.stop
      result.success(true)
    })
  }

  private handleSyncState(call: MethodCall, result: MethodResult): void {
    globalState.state = JSON.parse(call.args) as State
    globalState.runState = globalState.runTime === 0 ? RunState.stop : RunState.start
    result.success("")
  }

  private handleInvokeMethod(call: MethodCall, result: MethodResult): void {
    const request = JSON.parse(call.args as string) as CoreRequest
    const id = ++this.nextRequestId
    let phase = 'sending IPC request'
    let timer: number = -1
    const fail = (code: string, message: string): void => {
      if (!this.pending.has(id)) return
      this.pending.delete(id)
      clearTimeout(timer)
      result.error(code, `${request.method}: ${message}`, null)
    }
    const callbackStub = new CallbackStub("invokeMethod", (data: string) => {
      if (!this.pending.has(id)) return
      this.pending.delete(id)
      clearTimeout(timer)
      const bytes = new util.TextEncoder().encodeInto(data)
      result.success(bytes)
    })
    this.pending.set(id, { callback: callbackStub, fail })
    timer = setTimeout(() => {
      fail('OHOS_CORE_TIMEOUT', `Timed out while ${phase}.`)
    }, request.method === 'validateConfig' ? 30000 : 180000)
    this.parent.handleInvokeMethod(call.args, callbackStub).then(() => {
      phase = 'waiting for Core response'
    }).catch((error: Error) => {
      fail('OHOS_CORE_IPC_ERROR', error.message)
    })
  }

  private failPending(code: string, message: string): void {
    for (const request of this.pending.values()) request.fail(code, message)
  }

  private handleStart(call: MethodCall, result: MethodResult): void {
    const revision = call.args as number
    this.commandRevision = revision
    this.enqueueTransition(revision, () => this.startService(revision))
    result.success(true)
  }

  private handleStop(call: MethodCall, result: MethodResult): void {
    const revision = call.args as number
    this.commandRevision = revision
    this.enqueueTransition(revision, () => this.stopService(revision))
    result.success(true)
  }

  private enqueueTransition(revision: number, action: () => Promise<void>): void {
    this.transition = this.transition.then(async () => {
      if (revision === this.commandRevision) await action()
    }).catch((err: Error) => {
      console.log(`Service transition failed <= ${err.message ?? err}`)
    })
  }

  private async startService(revision: number): Promise<void> {
    if (globalState.runState === RunState.start) return
    globalState.runState = RunState.pending
    const result = new Promise<number>((resolve) => {
      const resultStub = new ResultStub("handleStart", (runTime: number) => {
        globalState.runTime = runTime
        globalState.runState = runTime !== 0 ? RunState.start : RunState.stop
        resolve(runTime)
      })
      const options = globalState.state?.vpnOptions ?? new VpnOptions()
      this.parent.handleStartService(options, globalState.runTime, resultStub).catch((err: Error) => {
        globalState.runTime = 0
        globalState.runState = RunState.stop
        console.log(`Service start failed <= ${err.message ?? err}`)
        resolve(0)
      })
    })
    const runTime = await result
    if (runTime === 0 && revision === this.commandRevision) {
      this.channel?.invokeMethod("stopped", revision)
    }
  }

  private async stopService(revision: number): Promise<void> {
    if (globalState.runState === RunState.stop) return
    globalState.runState = RunState.pending
    const result = new Promise<boolean>((resolve) => {
      const resultStub = new ResultStub("handleStop", (runTime: number) => {
        globalState.runTime = runTime
        globalState.runState = RunState.stop
        resolve(true)
      })
      this.parent.handleStopService(resultStub).catch((err: Error) => {
        globalState.runState = RunState.start
        console.log(`Service stop failed <= ${err.message ?? err}`)
        resolve(false)
      })
    })
    const stopped = await result
    if (stopped && revision === this.commandRevision) {
      this.channel?.invokeMethod("stopped", revision)
    }
  }

  private handleGetRunTime(result: MethodResult): void {
    this.parent.handleGetRunTime().then((runTime: number) => {
      globalState.runTime = runTime
    }).finally(() => {
      result.success(globalState.runTime)
    })
  }
}
