#include "napi/native_api.h"
#include "bride.h"
#include "libclash.h"
#include <cstring>
#include <cstdlib>
#include <future>

enum class InterfaceType {
    Invoke,
    Tun,
};

struct TunInterface {
    InterfaceType type = InterfaceType::Tun;
    napi_threadsafe_function protect;
    napi_threadsafe_function resolveUid;
    napi_threadsafe_function resolvePackage;
};

struct InvokeInterface {
    InterfaceType type = InterfaceType::Invoke;
    napi_threadsafe_function onResult;
};

struct ResolveUidCall {
    int protocol;
    const char *source;
    const char *target;
    std::promise<int> promise;
};

struct ResolvePackageCall {
    int uid;
    std::promise<char*> promise;
};

struct ProtectCall {
    int fd;
    std::promise<void> promise;
};

static char *GetValueStringUtf8(napi_env env, napi_value value) {
    size_t length = 0;
    napi_get_value_string_utf8(env, value, nullptr, 0, &length);
    char *result = static_cast<char*>(malloc(length + 1));
    napi_get_value_string_utf8(env, value, result, length + 1, &length);
    return result;
}

static int GetValueInt32(napi_env env, napi_value value) {
    int result = 0;
    napi_get_value_int32(env, value, &result);
    return result;
}

static bool GetValueBool(napi_env env, napi_value value) {
    bool result = false;
    napi_get_value_bool(env, value, &result);
    return result;
}

static napi_value CreateValueStringUtf8(napi_env env, const char *data) {
    napi_value result = nullptr;
    napi_create_string_utf8(env, data, NAPI_AUTO_LENGTH, &result);
    return result;
}

static napi_value CreateValueInt32(napi_env env, int data) {
    napi_value result = nullptr;
    napi_create_int32(env, data, &result);
    return result;
}

static napi_value CreateValueUint8Array(napi_env env, const char *data, size_t length) {
    napi_value result = nullptr;
    void *arrayBufferData = nullptr;
    napi_value arrayBuffer = nullptr;
    napi_create_arraybuffer(env, length, &arrayBufferData, &arrayBuffer);
    if (length > 0 && data != nullptr) {
        std::memcpy(arrayBufferData, data, length);
    }
    napi_create_typedarray(env, napi_uint8_array, length, arrayBuffer, 0, &result);
    return result;
}

void InvokeMethodCallJsCallback(napi_env env, napi_value callback, void* context, void* data) {
    napi_value global = nullptr;
    napi_get_global(env, &global);
    char *strData = reinterpret_cast<char*>(data);
    size_t length = strData != nullptr ? std::strlen(strData) : 0;
    napi_value argv = CreateValueUint8Array(env, strData, length);
    napi_value result = nullptr;
    napi_call_function(env, global, callback, 1, &argv, &result);
    free(data);
}

static napi_value ProtectCallbackFinal(napi_env env, napi_callback_info info) {
    void *data = nullptr;
    napi_get_cb_info(env, info, nullptr, nullptr, nullptr, &data);
    ProtectCall *call = reinterpret_cast<ProtectCall*>(data);
    call->promise.set_value();
    return nullptr;
}

void ProtectCallJsCallback(napi_env env, napi_value callback, void *context, void *data) {
    ProtectCall *call = reinterpret_cast<ProtectCall*>(data);
    napi_value global = nullptr;
    napi_get_global(env, &global);
    napi_value argv = CreateValueInt32(env, call->fd);
    napi_value result = nullptr;
    napi_call_function(env, global, callback, 1, &argv, &result);
    napi_value then = nullptr;
    napi_get_named_property(env, result, "then", &then);
    napi_value final = nullptr;
    napi_create_function(env, "onProtectFinal", NAPI_AUTO_LENGTH, ProtectCallbackFinal, call, &final);
    napi_value thenArgs[2] = {final, final};
    napi_value thenResult = nullptr;
    napi_call_function(env, result, then, 2, thenArgs, &thenResult);
}

void ResolveUidCallJsCallback(napi_env env, napi_value callback, void *context, void *data) {
    ResolveUidCall *call = reinterpret_cast<ResolveUidCall*>(data);
    napi_value global = nullptr;
    napi_get_global(env, &global);
    napi_value argv[3] = {
        CreateValueInt32(env, call->protocol),
        CreateValueStringUtf8(env, call->source),
        CreateValueStringUtf8(env, call->target)
    };
    napi_value result = nullptr;
    napi_call_function(env, global, callback, 3, argv, &result);
    int uid = -1;
    napi_get_value_int32(env, result, &uid);
    call->promise.set_value(uid);
}

void ResolvePackageCallJsCallback(napi_env env, napi_value callback, void *context, void *data) {
    ResolvePackageCall *call = reinterpret_cast<ResolvePackageCall*>(data);
    napi_value global = nullptr;
    napi_get_global(env, &global);
    napi_value argv = CreateValueInt32(env, call->uid);
    napi_value result = nullptr;
    napi_call_function(env, global, callback, 1, &argv, &result);
    char *resultStr = GetValueStringUtf8(env, result);
    call->promise.set_value(resultStr);
}

static napi_value InvokeMethod(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value argv[2] = {nullptr};
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    InvokeInterface *invokeInterface = new InvokeInterface();
    napi_create_threadsafe_function(env, argv[0], nullptr, CreateValueStringUtf8(env, "onResult"), 0, 1, nullptr, nullptr, nullptr, InvokeMethodCallJsCallback, &invokeInterface->onResult);
    invokeMethod(invokeInterface, GetValueStringUtf8(env, argv[1]));
    return nullptr;
}

static napi_value StartTUN(napi_env env, napi_callback_info info) {
    size_t argc = 7;
    napi_value argv[7] = {nullptr};
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    TunInterface *tunInterface = new TunInterface();
    napi_create_threadsafe_function(env, argv[0], nullptr, CreateValueStringUtf8(env, "protect"), 0, 1, nullptr, nullptr, nullptr, ProtectCallJsCallback, &tunInterface->protect);
    napi_create_threadsafe_function(env, argv[1], nullptr, CreateValueStringUtf8(env, "resolveUid"), 0, 1, nullptr, nullptr, nullptr, ResolveUidCallJsCallback, &tunInterface->resolveUid);
    napi_create_threadsafe_function(env, argv[2], nullptr, CreateValueStringUtf8(env, "resolvePackage"), 0, 1, nullptr, nullptr, nullptr, ResolvePackageCallJsCallback, &tunInterface->resolvePackage);
    int result = startTUN(tunInterface, GetValueInt32(env, argv[3]), GetValueStringUtf8(env, argv[4]), GetValueStringUtf8(env, argv[5]), GetValueStringUtf8(env, argv[6]), argc > 7 ? GetValueStringUtf8(env, argv[7]) : nullptr);
    napi_value jsResult = nullptr;
    napi_get_boolean(env, result != 0, &jsResult);
    return jsResult;
}

static napi_value QuickSetup(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value argv[3] = {nullptr};
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    InvokeInterface *invokeInterface = new InvokeInterface();
    napi_create_threadsafe_function(env, argv[0], nullptr, CreateValueStringUtf8(env, "onResult"), 0, 1, nullptr, nullptr, nullptr, InvokeMethodCallJsCallback, &invokeInterface->onResult);
    quickSetup(invokeInterface, GetValueStringUtf8(env, argv[1]), GetValueStringUtf8(env, argv[2]));
    return nullptr;
}

static napi_value SetEventListener(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value argv[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    napi_valuetype type = napi_undefined;
    if (argc > 0) {
        napi_typeof(env, argv[0], &type);
    }
    if (argc == 0 || type == napi_undefined || type == napi_null) {
        setEventListener(nullptr);
        return nullptr;
    }
    InvokeInterface *invokeInterface = new InvokeInterface();
    napi_create_threadsafe_function(env, argv[0], nullptr, CreateValueStringUtf8(env, "onResult"), 0, 1, nullptr, nullptr, nullptr, InvokeMethodCallJsCallback, &invokeInterface->onResult);
    setEventListener(invokeInterface);
    return nullptr;
}

static napi_value GetTotalTraffic(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value argv[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    char *data = getTotalTraffic(GetValueBool(env, argv[0]) ? 1 : 0);
    napi_value result = CreateValueStringUtf8(env, data);
    freeString(data);
    return result;
}

static napi_value GetTraffic(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value argv[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    char *data = getTraffic(GetValueBool(env, argv[0]) ? 1 : 0);
    napi_value result = CreateValueStringUtf8(env, data);
    freeString(data);
    return result;
}

static napi_value StopTun(napi_env env, napi_callback_info info) {
    stopTun();
    return nullptr;
}

static napi_value ForceGC(napi_env env, napi_callback_info info) {
    forceGC();
    return nullptr;
}

static napi_value UpdateDns(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value argv[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    updateDns(GetValueStringUtf8(env, argv[0]));
    return nullptr;
}

static napi_value ResetNetwork(napi_env env, napi_callback_info info) {
    resetNetwork();
    return nullptr;
}

static void call_reply_impl(void *callback, const char *data) {
    InvokeInterface *invokeInterface = reinterpret_cast<InvokeInterface*>(callback);
    char *dataCopy = nullptr;
    if (data != nullptr) {
        size_t length = std::strlen(data);
        dataCopy = static_cast<char*>(malloc(length + 1));
        std::memcpy(dataCopy, data, length + 1);
    }
    napi_call_threadsafe_function(invokeInterface->onResult, dataCopy, napi_tsfn_nonblocking);
}

static void call_event_impl(void *listener, const char *data) {
    call_reply_impl(listener, data);
}

static int call_protect_impl(void *tun_callbacks, int fd) {
    TunInterface *tunInterface = reinterpret_cast<TunInterface*>(tun_callbacks);
    ProtectCall call{fd, {}};
    std::future<void> future = call.promise.get_future();
    napi_call_threadsafe_function(tunInterface->protect, &call, napi_tsfn_nonblocking);
    future.wait();
    return 1;
}

static int call_resolve_uid_impl(void *tun_callbacks, int protocol, const char *source, const char *target) {
    TunInterface *tunInterface = reinterpret_cast<TunInterface*>(tun_callbacks);
    ResolveUidCall data{protocol, source, target, {}};
    std::future<int> future = data.promise.get_future();
    napi_call_threadsafe_function(tunInterface->resolveUid, &data, napi_tsfn_nonblocking);
    return future.get();
}

static char *call_resolve_package_impl(void *tun_callbacks, int uid) {
    TunInterface *tunInterface = reinterpret_cast<TunInterface*>(tun_callbacks);
    ResolvePackageCall data{uid, {}};
    std::future<char*> future = data.promise.get_future();
    napi_call_threadsafe_function(tunInterface->resolvePackage, &data, napi_tsfn_nonblocking);
    return future.get();
}

static void call_free_string_impl(char *data) {
    free(data);
}

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports)
{
    setBridgeFuncs(call_reply_impl, call_event_impl, call_protect_impl, call_resolve_uid_impl, call_resolve_package_impl, call_free_string_impl);

    napi_property_descriptor desc[] = {
        { "invokeMethod", nullptr, InvokeMethod, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "startTUN", nullptr, StartTUN, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "quickSetup", nullptr, QuickSetup, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "setEventListener", nullptr, SetEventListener, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "getTotalTraffic", nullptr, GetTotalTraffic, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "getTraffic", nullptr, GetTraffic, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "stopTun", nullptr, StopTun, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "forceGC", nullptr, ForceGC, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "updateDns", nullptr, UpdateDns, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "resetNetwork", nullptr, ResetNetwork, nullptr, nullptr, nullptr, napi_default, nullptr }
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    napi_value result = nullptr;
    napi_get_undefined(env, &result);
    return result;
}
EXTERN_C_END
