//
//  main.m
//  NWBonjourClient
//
//  Created by Danil Korotenko on 10/25/22.
//

#import <Foundation/Foundation.h>
#import <Network/Network.h>
#import <err.h>
#include "client.h"

int main(int argc, const char * argv[])
{
    @autoreleasepool
    {
        NSLog(@"Hello, Bonjour client!");

        nw_connection_t connection = create_outbound_connection("danilkorotenko.hellobonjour");
        if (connection == NULL)
        {
            err(1, NULL);
        }

        start_connection(connection);
        start_send_receive_loop(connection);
    }

    dispatch_main();
    return 0;
}
