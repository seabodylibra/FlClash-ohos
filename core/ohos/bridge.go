//go:build openharmony

package main

/*
#include <stdlib.h>

typedef void (*ReplyFunc)(void* callback, const char* data);
typedef void (*EventFunc)(void* listener, const char* data);
typedef int (*ProtectFunc)(void* tunCallbacks, int fd);
typedef int (*ResolveUidFunc)(void* tunCallbacks, int protocol, const char* source, const char* target);
typedef char* (*ResolvePackageFunc)(void* tunCallbacks, int uid);
typedef void (*FreeStringFunc)(char* data);

static void callReply(ReplyFunc f, void* callback, const char* data) {
    f(callback, data);
}
static void callEvent(EventFunc f, void* listener, const char* data) {
    f(listener, data);
}
static int callProtect(ProtectFunc f, void* tunCallbacks, int fd) {
    return f(tunCallbacks, fd);
}
static int callResolveUid(ResolveUidFunc f, void* tunCallbacks, int protocol, const char* source, const char* target) {
    return f(tunCallbacks, protocol, source, target);
}
static char* callResolvePackage(ResolvePackageFunc f, void* tunCallbacks, int uid) {
    return f(tunCallbacks, uid);
}
static void callFreeString(FreeStringFunc f, char* data) {
    f(data);
}
*/
import "C"

import (
	"core"
	"unsafe"
)

var (
	replyFunc         C.ReplyFunc
	eventFunc         C.EventFunc
	protectFunc       C.ProtectFunc
	resolveUidFunc    C.ResolveUidFunc
	resolvePackageFunc C.ResolvePackageFunc
	freeStringFunc    C.FreeStringFunc
)

//export setBridgeFuncs
func setBridgeFuncs(
	reply C.ReplyFunc,
	event C.EventFunc,
	protect C.ProtectFunc,
	resolveUid C.ResolveUidFunc,
	resolvePackage C.ResolvePackageFunc,
	freeString C.FreeStringFunc,
) {
	replyFunc = reply
	eventFunc = event
	protectFunc = protect
	resolveUidFunc = resolveUid
	resolvePackageFunc = resolvePackage
	freeStringFunc = freeString
}

func main() {}

//export invokeMethod
func invokeMethod(callback unsafe.Pointer, params *C.char) {
	data := C.GoString(params)
	core.InvokeMethod(data, func(reply []byte) {
		cstr := C.CString(string(reply))
		C.callReply(replyFunc, callback, cstr)
		C.free(unsafe.Pointer(cstr))
	})
}

//export startTUN
func startTUN(
	tunCallbacks unsafe.Pointer,
	fd C.int,
	stack, address, dns, options *C.char,
) C.int {
	callbacks := &tunCallbacksImpl{ptr: tunCallbacks}
	started := core.StartTun(
		callbacks,
		int(fd),
		C.GoString(stack),
		C.GoString(address),
		C.GoString(dns),
		C.GoString(options),
	)
	if started {
		return 1
	}
	return 0
}

//export quickSetup
func quickSetup(callback unsafe.Pointer, initParams, setupParams *C.char) {
	initStr := C.GoString(initParams)
	setupStr := C.GoString(setupParams)
	core.QuickSetup(initStr, setupStr, func(answer string) {
		cstr := C.CString(answer)
		C.callReply(replyFunc, callback, cstr)
		C.free(unsafe.Pointer(cstr))
	})
}

//export setEventListener
func setEventListener(listener unsafe.Pointer) {
	if listener == nil {
		core.SetEventListener(nil)
		return
	}
	core.SetEventListener(func(data []byte) {
		cstr := C.CString(string(data))
		C.callEvent(eventFunc, listener, cstr)
		C.free(unsafe.Pointer(cstr))
	})
}

//export getTraffic
func getTraffic(onlyStatisticsProxy C.int) *C.char {
	return C.CString(core.GetTraffic(onlyStatisticsProxy != 0))
}

//export getTotalTraffic
func getTotalTraffic(onlyStatisticsProxy C.int) *C.char {
	return C.CString(core.GetTotalTraffic(onlyStatisticsProxy != 0))
}

//export stopTun
func stopTun() {
	core.StopTun()
}

//export forceGC
func forceGC() {
	core.ForceGC()
}

//export updateDns
func updateDns(value *C.char) {
	core.UpdateDns(C.GoString(value))
}

//export resetNetwork
func resetNetwork() {
	core.ResetNetwork()
}

//export freeString
func freeString(s *C.char) {
	C.free(unsafe.Pointer(s))
}

type tunCallbacksImpl struct {
	ptr unsafe.Pointer
}

func (t *tunCallbacksImpl) Protect(fd int) bool {
	return C.callProtect(protectFunc, t.ptr, C.int(fd)) != 0
}

func (t *tunCallbacksImpl) ResolveUid(protocol int, source, target string) int {
	csource := C.CString(source)
	defer C.free(unsafe.Pointer(csource))
	ctarget := C.CString(target)
	defer C.free(unsafe.Pointer(ctarget))
	return int(C.callResolveUid(resolveUidFunc, t.ptr, C.int(protocol), csource, ctarget))
}

func (t *tunCallbacksImpl) ResolvePackage(uid int) string {
	cstr := C.callResolvePackage(resolvePackageFunc, t.ptr, C.int(uid))
	defer C.callFreeString(freeStringFunc, cstr)
	return C.GoString(cstr)
}
