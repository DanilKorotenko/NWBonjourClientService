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

    [connection setStringReceivedBlock:
        ^(NSString * _Nonnull aStringReceived)
        {
            NSLog(@"%@", aStringReceived);
        }];
    [connection setConnectionCanceledBlock:
        ^(BonjourConnection * _Nonnull aConnection)
        {
            setupConnection();
        }];
    [connection start];
    [connection startSendFromStdIn];
}

int main(int argc, const char * argv[])
{
    @autoreleasepool
    {
        NSLog(@"Hello, Bonjour client!");
        [BonjourObject setLogBlock:
            ^(NSString * _Nonnull aLogMessage)
            {
                NSLog(@"%@", aLogMessage);
            }];

        setupConnection();
    }

    dispatch_main();
    return 0;
}
