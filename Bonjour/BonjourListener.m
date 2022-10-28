//
//  BonjourListener.m
//  NWBonjourService
//
//  Created by Danil Korotenko on 10/28/22.
//

#import "BonjourListener.h"
#import <Network/Network.h>
#import <err.h>

@interface BonjourListener ()

@property (strong) NSString *name;
@property (strong) NSString *type;
@property (strong) NSString *domain;

@end

@implementation BonjourListener
{
    nw_listener_t       _listener;
    nw_connection_t     _inbound_connection;
    dispatch_queue_t    _queue;
}

+ (instancetype)createAndStartWithName:(NSString *)aName type:(NSString *)aType
    domain:(NSString *)aDomain
{
    BonjourListener *result = [[BonjourListener alloc] initWithName:aName type:aType
        domain:aDomain];

    if (![result start])
    {
        result = nil;
    }

    return result;
}

- (instancetype)initWithName:(NSString *)aName type:(NSString *)aType domain:(NSString *)aDomain
{
    self = [super init];
    if (self)
    {
        self.name = aName;
        self.type = aType;
        self.domain = aDomain;
        _inbound_connection = NULL;
        _queue = dispatch_queue_create("BonjourService.queue", NULL);
    }
    return self;
}

- (BOOL)start
{
    nw_parameters_t parameters = nw_parameters_create_secure_tcp(NW_PARAMETERS_DISABLE_PROTOCOL,
        NW_PARAMETERS_DEFAULT_CONFIGURATION);

    _listener = nw_listener_create(parameters);

    // Advertise name over Bonjour
    nw_advertise_descriptor_t advertise = nw_advertise_descriptor_create_bonjour_service(
        self.name.UTF8String,
        self.type.UTF8String,
        self.domain.UTF8String);

    nw_listener_set_advertise_descriptor(_listener, advertise);

    nw_listener_set_advertised_endpoint_changed_handler(_listener,
        ^(nw_endpoint_t _Nonnull advertised_endpoint, bool added)
        {
            NSString *message = [NSString stringWithFormat:
                @"Listener %s on %s (%s.%s.%s)", added ? "added" : "removed",
                nw_endpoint_get_bonjour_service_name(advertised_endpoint),
                nw_endpoint_get_bonjour_service_name(advertised_endpoint),
                self.type.UTF8String,
                self.domain.UTF8String];
            [self.delegate advertisedEndpointChanged:message];
        });

    nw_listener_set_queue(_listener, _queue);

    nw_listener_set_state_changed_handler(_listener,
        ^(nw_listener_state_t state, nw_error_t error)
        {
            errno = error ? nw_error_get_error_code(error) : 0;
            if (state == nw_listener_state_waiting)
            {
                fprintf(stderr, "Listener on port %u (tcp) waiting\n",
                    nw_listener_get_port(self->_listener));
            }
            else if (state == nw_listener_state_failed)
            {
                warn("listener (%s) failed", "tcp");
            }
            else if (state == nw_listener_state_ready)
            {
                fprintf(stderr, "Listener on port %u (%s) ready!\n",
                    nw_listener_get_port(self->_listener), "tcp");
            }
            else if (state == nw_listener_state_cancelled)
            {
                // Release the primary reference on the listener
                // that was taken at creation time
                // TODO: Notify delegate. Recreate Listener.
            }
        });

    nw_listener_set_new_connection_handler(_listener,
        ^(nw_connection_t connection)
        {
            if (self->_inbound_connection != NULL)
            {
                // We only support one connection at a time, so if we already
                // have one, reject the incoming connection.
                nw_connection_cancel(connection);
            }
            else
            {
                // Accept the incoming connection and start sending
                // and receiving on it.
                self->_inbound_connection = connection;

                [self startConnection:self->_inbound_connection];
                [self startSendReceiveLoop:self->_inbound_connection];
            }
        });

    nw_listener_start(_listener);

    return _listener != nil;
}

- (void)startConnection:(nw_connection_t)aConnection
{
    nw_connection_set_queue(aConnection, _queue);

    nw_connection_set_state_changed_handler(aConnection,
        ^(nw_connection_state_t state, nw_error_t error)
        {
            nw_endpoint_t remote = nw_connection_copy_endpoint(aConnection);
            errno = error ? nw_error_get_error_code(error) : 0;
            if (state == nw_connection_state_waiting)
            {
                warn("connect to %s port %u (%s) failed, is waiting",
                    nw_endpoint_get_hostname(remote),
                    nw_endpoint_get_port(remote), "tcp");
            }
            else if (state == nw_connection_state_failed)
            {
                warn("connect to %s port %u (%s) failed",
                    nw_endpoint_get_hostname(remote),
                    nw_endpoint_get_port(remote), "tcp");
            }
            else if (state == nw_connection_state_ready)
            {
                fprintf(stderr, "Connection to %s port %u (%s) succeeded!\n",
                    nw_endpoint_get_hostname(remote),
                    nw_endpoint_get_port(remote), "tcp");
            }
            else if (state == nw_connection_state_cancelled)
            {
                // Release the primary reference on the connection
                // that was taken at creation time
            }
        });

    nw_connection_start(aConnection);
}

- (void)startSendReceiveLoop:(nw_connection_t)aConnection
{
    // Start reading from stdin
    [self sendLoop:aConnection];

    // Start reading from connection
    [self receiveLoop:aConnection];
}

- (void)sendLoop:(nw_connection_t)connection
{
    dispatch_read(STDIN_FILENO, 8192, _queue,
        ^(dispatch_data_t _Nonnull read_data, int stdin_error)
        {
            if (stdin_error != 0)
            {
                errno = stdin_error;
                warn("stdin read error");
            }
            else if (read_data == NULL)
            {
                // NULL data represents EOF
                // Send a "write close" on the connection, by sending NULL data with the final message context marked as complete.
                // Note that it is valid to send with NULL data but a non-NULL context.
                nw_connection_send(connection, NULL, NW_CONNECTION_FINAL_MESSAGE_CONTEXT, true,
                    ^(nw_error_t  _Nullable error)
                    {
                        if (error != NULL)
                        {
                            errno = nw_error_get_error_code(error);
                            warn("write close error");
                        }
                        // Stop reading from stdin, so don't schedule another send_loop
                    });
            }
            else
            {
                // Every send is marked as complete. This has no effect with the default message context for TCP,
                // but is required for UDP to indicate the end of a packet.
                nw_connection_send(connection, read_data, NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, true,
                    ^(nw_error_t  _Nullable error)
                    {
                        if (error != NULL)
                        {
                            errno = nw_error_get_error_code(error);
                            warn("send error");
                        }
                        else
                        {
                            // Continue reading from stdin
                            [self sendLoop:connection];
                        }
                    });
            }
        });
}

- (void)receiveLoop:(nw_connection_t)aConnection
{
    nw_connection_receive(aConnection, 1, UINT32_MAX,
        ^(dispatch_data_t content, nw_content_context_t context, bool is_complete,
            nw_error_t receive_error)
        {
            if (content != NULL)
            {
                // If there is content, write it to stdout asynchronously
                NSData *data = (NSData *)content;
                [self.delegate dataReceived:data];
            }

            // If the context is marked as complete, and is the final context,
            // we're read-closed.
            if (is_complete &&
                (context == NULL || nw_content_context_get_is_final(context)))
            {
                exit(0);
            }

            // If there was no error in receiving, request more data
            if (receive_error == NULL)
            {
                [self receiveLoop:aConnection];
            }
        });
}

@end
