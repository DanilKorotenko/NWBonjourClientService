//
//  client.h
//  NWBonjourClientService
//
//  Created by Danil Korotenko on 10/26/22.
//

#ifndef client_h
#define client_h

#include <stdio.h>
#import <Network/Network.h>

nw_connection_t create_outbound_connection(const char *name);
void start_connection(nw_connection_t connection);
void start_send_receive_loop(nw_connection_t connection);

#endif /* client_h */
