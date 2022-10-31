
#import "BonjourListenerAdapter.h"
#import "BonjourListener.h"

BNJListenerControllerRef BNJCreateControllerWith(CFStringRef aName, CFStringRef aType,
    CFStringRef aDomain)
{
    NSString *name = (NSString *)CFBridgingRelease(aName);
    NSString *type = (NSString *)CFBridgingRelease(aType);
    NSString *domain = (NSString *)CFBridgingRelease(aDomain);

    BonjourListener *listener = [[BonjourListener alloc] initWithName:name type:type domain:domain];

    BNJListenerControllerRef listenerRef = (BNJListenerControllerRef)malloc(sizeof(BNJListenerController));
    listenerRef->_bnjListenerController = (__bridge void *)listener;

    return listenerRef;
}

void BNJListenerControllerReleaseAndMakeNull(BNJListenerControllerRef *aListenerRef)
{
    free(*aListenerRef);
    *aListenerRef = NULL;
}
