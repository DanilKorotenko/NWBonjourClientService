//
//  main.m
//  NWBonjourService
//
//  Created by Danil Korotenko on 10/24/22.
//

#import <Foundation/Foundation.h>
#import <Network/Network.h>
#import <err.h>
#import "BonjourListenerRef.h"

//@implementation Delegate
//
//- (void)advertisedEndpointChanged:(NSString *)message
//{
//    NSLog(@"%@", message);
//}
//
//- (void)dataReceived:(NSData *)aData
//{
//    NSString *str = [[NSString alloc] initWithData:aData encoding:NSUTF8StringEncoding];
//
//    NSLog(@"a message from client: %@", str);
//}
//
//@end

static BNJListenerRef listenerRef = NULL;

int main(int argc, const char * argv[])
{
    @autoreleasepool
    {
        NSLog(@"Hello, Bonjour service!");

        listenerRef = BNJListenerCreateWith(CFSTR("danilkorotenko.hellobonjour"),
            CFSTR("_exampleService._tcp"), CFSTR("local"));

        if (listenerRef == NULL)
        {
            err(1, NULL);
        }

        BNJListenerSetLogBlock(listenerRef,
            ^(const char *aLogMessage)
            {
                NSLog(@"%s", aLogMessage);
            });

//        [listener start];
    }

    dispatch_main();

    return 0;
}
