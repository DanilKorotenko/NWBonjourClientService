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

void readFromStdIn(void)
{
    dispatch_read(STDIN_FILENO, 8192, dispatch_get_main_queue(),
        ^(dispatch_data_t _Nonnull data, int stdinError)
        {
            if (stdinError != 0)
            {
                NSLog(@"StdIn error: %d", stdinError);
            }
            else
            {
                BNJListenerSendDataWithSendCompletion(listenerRef, data,
                    ^(CFErrorRef anError)
                    {
                        if (anError)
                        {
                            NSError *error = (__bridge NSError *)(anError);
                            NSLog(@"Error on send: %@", error);
                        }
                        else
                        {
                            readFromStdIn();
                        }
                    });
            }
        });
}

int main(int argc, const char * argv[])
{
    @autoreleasepool
    {
        NSLog(@"Hello, Bonjour service!");

        listenerRef = BNJListenerCreateWith(CFSTR("gtb-agent"),
            CFSTR("_scan4DLPService._tcp"), CFSTR("local"));

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

        BNJListenerStart(listenerRef);

        readFromStdIn();
    }

    dispatch_main();

    return 0;
}
