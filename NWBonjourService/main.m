//
//  main.m
//  NWBonjourService
//
//  Created by Danil Korotenko on 10/24/22.
//

#import <Foundation/Foundation.h>
#import <Network/Network.h>
#import <err.h>
#import "BonjourListener.h"

@interface Delegate : NSObject<BonjourListenerDelegate>

@end

@implementation Delegate

- (void)advertisedEndpointChanged:(NSString *)message
{
    NSLog(@"%@", message);
}

- (void)dataReceived:(NSData *)aData
{
    NSString *str = [[NSString alloc] initWithData:aData encoding:NSUTF8StringEncoding];

    NSLog(@"a message from client: %@", str);
}

@end

static Delegate *listenerDelegate = nil;
static BonjourListener *listener = nil;

int main(int argc, const char * argv[])
{
    @autoreleasepool
    {
        NSLog(@"Hello, Bonjour service!");

        listenerDelegate = [[Delegate alloc] init];

        listener = [[BonjourListener alloc]
            initWithName:@"danilkorotenko.hellobonjour" type:@"_exampleService._tcp"
            domain:@"local"];

        listener.delegate = listenerDelegate;

        if (listener == nil)
        {
            err(1, NULL);
        }

        [listener start];
    }

    dispatch_main();

    return 0;
}
