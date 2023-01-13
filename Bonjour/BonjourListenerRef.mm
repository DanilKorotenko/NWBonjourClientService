
#import "BonjourListenerRef.h"
#import "BonjourListener.h"

BNJListenerRef BNJListenerCreateWith(CFStringRef aName, CFStringRef aType,
    CFStringRef aDomain)
{
    NSString *name = (__bridge NSString *)aName;
    NSString *type = (__bridge NSString *)aType;
    NSString *domain = (__bridge NSString *)aDomain;

    BonjourListener *listener = [[BonjourListener alloc] initWithName:name type:type domain:domain];

    BNJListenerRef listenerRef = (BNJListenerRef)malloc(sizeof(BNJListener));
    listenerRef->_bnjListenerController = (__bridge_retained void *)listener;

    return listenerRef;
}

void BNJSetLogBlock(void (^aBlock)(CFStringRef aLogMessage))
{
    [BonjourObject setLogBlock:
        ^(NSString * _Nonnull aLogMessage)
        {
            CFStringRef logMessageRef = (CFStringRef)CFBridgingRetain(aLogMessage);
            if (NULL != logMessageRef)
            {
                aBlock(logMessageRef);
                CFRelease(logMessageRef);
            }
        }];
}

void BNJListenerSetStringReceivedBlock(BNJListenerRef aListenerRef,
    void (^aBlock)(CFStringRef aStringReceivedMessage))
{
    BonjourListener *listener = (__bridge BonjourListener *)aListenerRef->_bnjListenerController;
    [listener setStringReceivedBlock:^(NSString * _Nonnull aStringReceived)
        {
            CFStringRef stringReceivedRef = (CFStringRef)CFBridgingRetain(aStringReceived);
            if (NULL != stringReceivedRef)
            {
                aBlock(stringReceivedRef);
                CFRelease(stringReceivedRef);
            }
        }];
}

void BNJListenerStart(BNJListenerRef aListenerRef)
{
    BonjourListener *listener = (__bridge BonjourListener *)aListenerRef->_bnjListenerController;
    [listener start];
}

void BNJListenerStop(BNJListenerRef aListenerRef)
{
    BonjourListener *listener = (__bridge BonjourListener *)aListenerRef->_bnjListenerController;
    [listener stop];
}

void BNJListenerStartSendFromStdIn(BNJListenerRef aListenerRef)
{
    BonjourListener *listener = (__bridge BonjourListener *)aListenerRef->_bnjListenerController;
    [listener startSendFromStdIn];
}

void BNJListenerReleaseAndMakeNull(BNJListenerRef *aListenerRef)
{
    free(*aListenerRef);
    *aListenerRef = NULL;
}
