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
            ^(CFStringRef aLogMessage)
            {
                NSString *logMessage = (__bridge NSString *)(aLogMessage);
                NSLog(@"%@", logMessage);
            });

        BNJListenerSetStringReceivedBlock(listenerRef,
            ^(CFStringRef aStringReceivedMessage)
            {
                NSString *stringReceived = (__bridge NSString *)(aStringReceivedMessage);
                NSLog(@"%@", stringReceived);
            });

        BNJListenerSetSendFromStdIn(listenerRef, true);

        BNJListenerStart(listenerRef);
    }

    dispatch_main();

    return 0;
}
