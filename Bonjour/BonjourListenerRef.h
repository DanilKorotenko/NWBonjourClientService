
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

void BNJListenerSetLogBlock(BNJListenerRef aListenerRef, void (^aBlock)(CFStringRef aLogMessage));

void BNJListenerSetStringReceivedBlock(BNJListenerRef aListenerRef,
    void (^aBlock)(CFStringRef aStringReceivedMessage));

void BNJListenerSendDataWithSendCompletion(BNJListenerRef aListenerRef, dispatch_data_t aData,
    void (^aSendCompletion)(CFErrorRef anError));
void BNJListenerSendStringWithSendCompletion(BNJListenerRef aListenerRef, CFStringRef aString,
    void (^aSendCompletion)(CFErrorRef anError));

void BNJListenerStart(BNJListenerRef aListenerRef);
void BNJListenerStop(BNJListenerRef aListenerRef);

void BNJListenerReleaseAndMakeNull(BNJListenerRef *aListenerRef);

#ifdef __cplusplus
  }
#endif
