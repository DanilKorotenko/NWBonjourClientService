//
//  main.m
//  NWBonjourClient
//
//  Created by Danil Korotenko on 10/25/22.
//

#import <Foundation/Foundation.h>
//#import <Network/Network.h>
#import <err.h>
#import "BonjourConnection.h"

int main(int argc, const char * argv[])
{
    @autoreleasepool
    {
        NSLog(@"Hello, Bonjour client!");

        BonjourConnection *connection = [[BonjourConnection alloc]
            initOutboundToBonjourServiceName:@"danilkorotenko.hellobonjour"];

        if (connection == nil)
        {
            err(1, NULL);
        }
        else
        {
            [connection setLogBlock:^(const char * _Nonnull aLogMessage)
                {
                    NSLog(@"Connection: %s", aLogMessage);
                }];

            [connection setIsCompleteBlock:
                ^{
                    NSLog(@"Connection: complete");
                    exit(0);
                }];

            [connection setDataAvaliableBlock:
                ^(NSData * _Nonnull aData)
                {
                    NSString *content = [[NSString alloc] initWithData:aData
                        encoding:NSUTF8StringEncoding];
                    NSLog(@"Data: %@", content);
                }];

            [connection start];
            [connection sendStdInloop];
        }
    }

    dispatch_main();
    return 0;
}
