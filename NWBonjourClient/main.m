//
//  main.m
//  NWBonjourClient
//
//  Created by Danil Korotenko on 10/25/22.
//

#import <Foundation/Foundation.h>
#import <Network/Network.h>
#import <err.h>
#import "BonjourConnection.h"

BonjourConnection *connection = nil;

void setupConnection(void)
{
    if (connection != nil)
    {
        [connection cancel];
        connection = nil;
    }

    connection = [[BonjourConnection alloc] initWithName:
        @"gtb-agent" type:@"_scan4DLPService._tcp" domain:@"local"];

    if (connection == nil)
    {
        err(1, NULL);
    }

    [connection setLogBlock:
        ^(NSString * _Nonnull aLogMessage)
        {
            NSLog(@"%@", aLogMessage);
        }];
    [connection setStringReceivedBlock:
        ^(NSString * _Nonnull aStringReceived)
        {
            NSLog(@"%@", aStringReceived);
        }];
    [connection setConnectionCanceledBlock:
        ^{
//            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC),
//                dispatch_get_main_queue(),
//                    ^{
                        setupConnection();
//                    });
        }];
    [connection start];
    [connection startSendFromStdIn];
}

int main(int argc, const char * argv[])
{
    @autoreleasepool
    {
        NSLog(@"Hello, Bonjour client!");
        setupConnection();
    }

    dispatch_main();
    return 0;
}
