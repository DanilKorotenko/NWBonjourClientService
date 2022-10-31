//
//  main.m
//  NWBonjourService
//
//  Created by Danil Korotenko on 10/24/22.
//

#import <Foundation/Foundation.h>
#import <Network/Network.h>
#import <err.h>
#import "BonjourListenerAdapter.h"


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

static BNJListenerControllerRef listenerRef = NULL;

int main(int argc, const char * argv[])
{
    @autoreleasepool
    {
        NSLog(@"Hello, Bonjour service!");

        listenerRef = BNJCreateControllerWith(CFSTR("danilkorotenko.hellobonjour"),
            CFSTR("_exampleService._tcp"), CFSTR("local"));

//        listener.delegate = listenerDelegate;

        if (listenerRef == NULL)
        {
            err(1, NULL);
        }

//        [listener start];
    }

    dispatch_main();

    return 0;
}
