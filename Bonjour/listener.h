//
//  listener.h
//  NWBonjourService
//
//  Created by Danil Korotenko on 10/26/22.
//

#ifndef listener_h
#define listener_h

#include <stdio.h>
#import <Network/Network.h>

nw_listener_t create_and_start_listener(char *name);

#endif /* listener_h */
