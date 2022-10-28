//
//  main.m
//  NWBonjourService
//
//  Created by Danil Korotenko on 10/24/22.
//

#import <Foundation/Foundation.h>
#import <Network/Network.h>
#import <err.h>
#import "BonjourListener.h"

int main(int argc, const char * argv[])
{
    @autoreleasepool
    {
        NSLog(@"Hello, Bonjour service!");

        BonjourListener *listener = [BonjourListener createAndStartWithName:@"danilkorotenko.hellobonjour" type:@"_exampleService._tcp" domain:@"local"];

        if (listener == nil)
        {
            err(1, NULL);
        }
    }

    dispatch_main();

    return 0;
}
