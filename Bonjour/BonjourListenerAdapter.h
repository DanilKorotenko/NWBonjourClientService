
#pragma once

#import <CoreFoundation/CoreFoundation.h>

#ifdef __cplusplus
  extern "C" {
#endif

typedef struct
{
    void *_bnjListenerController;
} BNJListenerController;

typedef BNJListenerController* BNJListenerControllerRef;

BNJListenerControllerRef BNJCreateControllerWith(CFStringRef aName, CFStringRef aType,
    CFStringRef aDomain);

#ifdef __cplusplus
  }
#endif
