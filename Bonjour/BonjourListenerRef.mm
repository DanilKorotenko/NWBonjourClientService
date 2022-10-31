
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
    void (^aBlock)(const char *aLogMessage))
{
    BonjourListener *listener = (__bridge BonjourListener *)aListenerRef->_bnjListenerController;
    [listener setLogBlock:aBlock];
}

void BNJListenerSetStringReceivedBlock(BNJListenerRef aListenerRef,
    void (^aBlock)(const char *aStringReceivedMessage))
{
    BonjourListener *listener = (__bridge BonjourListener *)aListenerRef->_bnjListenerController;
    [listener setStringReceivedBlock:aBlock];
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
