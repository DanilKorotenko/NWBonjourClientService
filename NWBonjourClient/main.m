//
//  main.m
//  NWBonjourClient
//
//  Created by Danil Korotenko on 10/25/22.
//

#import <Foundation/Foundation.h>
#import <Network/Network.h>
#import <err.h>
#import "BonjourConnectionsManager.h"

static BonjourConnectionsManager *connectionsManager = nil;

static BOOL reading = NO;

void readFromStdIn(void)
{
    if (reading)
    {
        return;
    }

    reading = YES;

    dispatch_read(STDIN_FILENO, 8192, dispatch_get_main_queue(),
        ^(dispatch_data_t  _Nonnull data, int stdinError)
        {
            reading = NO;
            if (stdinError != 0)
            {
                NSLog(@"StdIn error: %d", stdinError);
            }
            else
            {
                [connectionsManager sendData:data withSendCompletionBlock:
                    ^(NSError *err)
                    {
                        if (err)
                        {
                            NSLog(@"Error on send: %@", err);
                        }
                        else
                        {
                            readFromStdIn();
                        }
                    }];
            }
        });
}

void setupNewConnection(void)
{
    [connectionsManager startBonjourConnectionWithName:@"gtb-agent"
        type:@"_scan4DLPService._tcp" domain:@"local"
        didConnectBlock:
        ^{
            readFromStdIn();
        }];
}

int main(int argc, const char * argv[])
{
    @autoreleasepool
    {
        NSLog(@"Hello, Bonjour client!");
        connectionsManager = [[BonjourConnectionsManager alloc] init];

        connectionsManager.logBlock =
            ^(NSString * _Nonnull aLogMessage)
            {
                NSLog(@"%@", aLogMessage);
            };
        connectionsManager.connectionCanceledBlock =
            ^{
                setupNewConnection();
            };
        connectionsManager.stringReceivedBlock =
            ^(NSString * _Nonnull aStringReceived)
            {
                NSLog(@"%@", aStringReceived);
            };

        setupNewConnection();
    }

    dispatch_main();

    return 0;
}
