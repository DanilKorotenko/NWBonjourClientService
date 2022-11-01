
#pragma once

#import <CoreFoundation/CoreFoundation.h>

#ifdef __cplusplus
  extern "C" {
#endif

typedef struct
{
    void *_bnjListenerController;
} BNJListener;

typedef BNJListener* BNJListenerRef;

BNJListenerRef BNJListenerCreateWith(CFStringRef aName, CFStringRef aType, CFStringRef aDomain);

void BNJListenerSetLogBlock(BNJListenerRef aListenerRef,
    void (^aBlock)(CFStringRef aLogMessage));

void BNJListenerSetStringReceivedBlock(BNJListenerRef aListenerRef,
    void (^aBlock)(CFStringRef aStringReceivedMessage));

void BNJListenerStart(BNJListenerRef aListenerRef);

#ifdef __cplusplus
  }
#endif
