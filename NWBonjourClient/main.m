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

static BonjourConnection *connection = nil;

void setupConnection(void)
{
    connection = [[BonjourConnection alloc] initWithName:
        @"danilkorotenko.hellobonjour" type:@"_exampleService._tcp" domain:@"local"];

    if (connection == nil)
    {
        err(1, NULL);
    }

    [connection setLogBlock:
        ^(const char * _Nonnull aLogMessage)
        {
            NSLog(@"%s", aLogMessage);
        }];
    [connection setStringReceivedBlock:
        ^(const char * _Nonnull aStringReceived)
        {
            NSLog(@"%s", aStringReceived);
        }];
    [connection setConnectionCanceledBlock:
        ^{
            setupConnection();
        }];
    [connection start];
    [connection startSendRecieveLoop];
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
