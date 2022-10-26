//
//  main.m
//  NWBonjourService
//
//  Created by Danil Korotenko on 10/24/22.
//

#import <Foundation/Foundation.h>
#import <Network/Network.h>
#import <err.h>
#include "listener.h"

int main(int argc, const char * argv[])
{
    @autoreleasepool
    {
        NSLog(@"Hello, Bonjour service!");

        nw_listener_t listener = create_and_start_listener("danilkorotenko.hellobonjour");
        if (listener == NULL)
        {
            err(1, NULL);
        }
    }

    dispatch_main();

    return 0;
}
