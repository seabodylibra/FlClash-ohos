#pragma once

#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*ReplyFunc)(void *callback, const char *data);
typedef void (*EventFunc)(void *listener, const char *data);
typedef int (*ProtectFunc)(void *tunCallbacks, int fd);
typedef int (*ResolveUidFunc)(void *tunCallbacks, int protocol, const char *source, const char *target);
typedef char *(*ResolvePackageFunc)(void *tunCallbacks, int uid);
typedef void (*FreeStringFunc)(char *data);

void setBridgeFuncs(
    ReplyFunc reply,
    EventFunc event,
    ProtectFunc protect,
    ResolveUidFunc resolveUid,
    ResolvePackageFunc resolvePackage,
    FreeStringFunc freeString);

void invokeMethod(void *callback, const char *params);
int startTUN(void *tunCallbacks, int fd, const char *stack, const char *address, const char *dns, const char *options);
void quickSetup(void *callback, const char *initParams, const char *setupParams);
void setEventListener(void *listener);
char *getTraffic(int onlyStatisticsProxy);
char *getTotalTraffic(int onlyStatisticsProxy);
void stopTun();
void forceGC();
void updateDns(const char *value);
void resetNetwork();
void freeString(char *s);

#ifdef __cplusplus
}
#endif
