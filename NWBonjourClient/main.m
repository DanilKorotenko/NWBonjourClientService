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

int main(int argc, const char * argv[])
{
    @autoreleasepool
    {
        NSLog(@"Hello, Bonjour client!");
        BonjourConnection *connection = [BonjourConnection createAndStartWithName:
            @"danilkorotenko.hellobonjour" type:@"_exampleService._tcp" domain:@"local"];
//        nw_connection_t connection = create_outbound_connection("danilkorotenko.hellobonjour");
        if (connection == nil)
        {
            err(1, NULL);
        }
    }

    dispatch_main();
    return 0;
}
