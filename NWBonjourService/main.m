//
//  main.m
//  NWBonjourService
//
//  Created by Danil Korotenko on 10/24/22.
//

#import <Foundation/Foundation.h>
#import <Network/Network.h>
#import <err.h>
#import "BonjourService.h"

BonjourConnection *_inboundConnection = nil;

int main(int argc, const char * argv[])
{
    @autoreleasepool
    {
        NSLog(@"Hello, Bonjour service!");

        BonjourService *service = [[BonjourService alloc] initWithName:@"danilkorotenko.hellobonjour"];

        [service setLogBlock:
            ^(const char * _Nonnull aLogMessage)
            {
                NSLog(@"Service: %s", aLogMessage);
            }];

        [service setNewConnectionBlock:
            ^(BonjourConnection * _Nonnull aNewConnection)
            {
                if (_inboundConnection != nil)
                {
                    // We only support one connection at a time, so if we already
                    // have one, reject the incoming connection.
                    [_inboundConnection cancel];
                }
                else
                {
                    // Accept the incoming connection and start sending
                    // and receiving on it.
                    _inboundConnection = aNewConnection;

                    [_inboundConnection setLogBlock:^(const char * _Nonnull aLogMessage)
                    {
                        NSLog(@"Connection: %s", aLogMessage);
                    }];

                    [_inboundConnection setIsCompleteBlock:
                    ^{
                        NSLog(@"Connection: complete");
                        exit(0);
                    }];

                    [_inboundConnection setDataAvaliableBlock:
                        ^(NSData * _Nonnull aData)
                        {
                            NSString *content = [[NSString alloc] initWithData:aData
                                encoding:NSUTF8StringEncoding];
                            NSLog(@"Data: %@", content);
                        }];

                    [_inboundConnection start];
                    [_inboundConnection sendStdInloop];
                }
            }];

        if (![service start])
        {
            err(1, NULL);
        }
    }

    dispatch_main();

    return 0;
}
