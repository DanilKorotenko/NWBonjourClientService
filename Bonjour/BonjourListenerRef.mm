
#import "BonjourListenerRef.h"
#import "BonjourListener.h"

BNJListenerRef BNJListenerCreateWith(CFStringRef aName, CFStringRef aType,
    CFStringRef aDomain)
{
    NSString *name = (NSString *)CFBridgingRelease(aName);
    NSString *type = (NSString *)CFBridgingRelease(aType);
    NSString *domain = (NSString *)CFBridgingRelease(aDomain);

    BonjourListener *listener = [[BonjourListener alloc] initWithName:name type:type domain:domain];

    BNJListenerRef listenerRef = (BNJListenerRef)malloc(sizeof(BNJListener));
    listenerRef->_bnjListenerController = (__bridge void *)listener;

    return listenerRef;
}

void BNJListenerSetLogBlock(BNJListenerRef aListenerRef,
    void (^aBlock)(const char *aLogMessage))
{
    BonjourListener *listener = (__bridge BonjourListener *)aListenerRef->_bnjListenerController;
    [listener setLogBlock:aBlock];
}

void BNJListenerControllerReleaseAndMakeNull(BNJListenerRef *aListenerRef)
{
    free(*aListenerRef);
    *aListenerRef = NULL;
}
