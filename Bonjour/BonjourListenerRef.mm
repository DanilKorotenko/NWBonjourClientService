
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

void BNJListenerSetLogBlock(BNJListenerRef aListenerRef,
    void (^aBlock)(CFStringRef aLogMessage))
{
    BonjourListener *listener = (__bridge BonjourListener *)aListenerRef->_bnjListenerController;
    [listener setLogBlock:
        ^(NSString * _Nonnull aLogMessage)
        {
            CFStringRef logMessageRef = (CFStringRef)CFBridgingRetain(aLogMessage);
            aBlock(logMessageRef);
            CFRelease(logMessageRef);
        }];
}

void BNJListenerSetStringReceivedBlock(BNJListenerRef aListenerRef,
    void (^aBlock)(CFStringRef aStringReceivedMessage))
{
    BonjourListener *listener = (__bridge BonjourListener *)aListenerRef->_bnjListenerController;
    [listener setStringReceivedBlock:^(NSString * _Nonnull aStringReceived)
        {
            CFStringRef stringReceivedRef = (CFStringRef)CFBridgingRetain(aStringReceived);
            aBlock(stringReceivedRef);
            CFRelease(stringReceivedRef);
        }];
}

void BNJListenerStart(BNJListenerRef aListenerRef)
{
    BonjourListener *listener = (__bridge BonjourListener *)aListenerRef->_bnjListenerController;
    [listener start];
}

void BNJListenerControllerReleaseAndMakeNull(BNJListenerRef *aListenerRef)
{
    free(*aListenerRef);
    *aListenerRef = NULL;
}
