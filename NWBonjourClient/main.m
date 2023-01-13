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

void readFromStdIn(void)
{
    dispatch_read(STDIN_FILENO, 8192, dispatch_get_main_queue(),
        ^(dispatch_data_t  _Nonnull data, int stdinError)
        {
            if (stdinError != 0)
            {
                NSLog(@"StdIn error: %d", stdinError);
            }
            else
            {
                [[BonjourConnectionsManager sharedManager] sendData:data withSendCompletionBlock:
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
    [[BonjourConnectionsManager sharedManager] startBonjourConnectionWithName:@"gtb-agent"
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
        [BonjourConnectionsManager sharedManager].logBlock =
            ^(NSString * _Nonnull aLogMessage)
            {
                NSLog(@"%@", aLogMessage);
            };
        [BonjourConnectionsManager sharedManager].connectionCanceledBlock =
            ^{
                setupNewConnection();
            };
        [BonjourConnectionsManager sharedManager].stringReceivedBlock =
            ^(NSString * _Nonnull aStringReceived)
            {
                NSLog(@"%@", aStringReceived);
            };

        setupNewConnection();
    }

    dispatch_main();

    return 0;
}
