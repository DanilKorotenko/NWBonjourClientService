//
//  BonjourListener.m
//  NWBonjourService
//
//  Created by Danil Korotenko on 10/28/22.
//

#import "BonjourListener.h"
//#include "listener.h"
#import <Network/Network.h>
#import <err.h>

nw_connection_t g_inbound_connection = NULL;

/*
 * receive_loop()
 * Perform a single read on the supplied connection, and write data to
 * stdout as it is received.
 * If no error is encountered, schedule another read on the same connection.
 */
void receive_loop(nw_connection_t connection)
{
    nw_connection_receive(connection, 1, UINT32_MAX,
        ^(dispatch_data_t content, nw_content_context_t context, bool is_complete, nw_error_t receive_error)
        {
            dispatch_block_t schedule_next_receive =
                ^{
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
                        receive_loop(connection);
                    }
                };

            if (content != NULL)
            {
                // If there is content, write it to stdout asynchronously
                schedule_next_receive = schedule_next_receive;
                dispatch_write(STDOUT_FILENO, content, dispatch_get_main_queue(),
                    ^(__unused dispatch_data_t _Nullable data, int stdout_error)
                    {
                        if (stdout_error != 0)
                        {
                            errno = stdout_error;
                            warn("stdout write error");
                        }
                        else
                        {
                            schedule_next_receive();
                        }
                    });
            }
            else
            {
                // Content was NULL, so directly schedule the next receive
                schedule_next_receive();
            }
        });
}


/*
 * send_loop()
 * Start reading from stdin on a dispatch source, and send any bytes on the given connection.
 */
void send_loop(nw_connection_t connection)
{
    dispatch_read(STDIN_FILENO, 8192, dispatch_get_main_queue(),
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
                            send_loop(connection);
                        }
                    });
            }
        });
}


/*
 * start_send_receive_loop()
 * Start reading from stdin (when not detached) and from the given connection.
 * Every read on stdin becomes a send on the connection, and every receive on the
 * connection becomes a write on stdout.
 */
void start_send_receive_loop(nw_connection_t connection)
{
    // Start reading from stdin
    send_loop(connection);

    // Start reading from connection
    receive_loop(connection);
}

/*
 * start_connection()
 * Schedule a connection on the main queue, process events, and
 * start the connection.
 */
void start_connection(nw_connection_t connection)
{
    nw_connection_set_queue(connection, dispatch_get_main_queue());

    nw_connection_set_state_changed_handler(connection,
        ^(nw_connection_state_t state, nw_error_t error)
        {
            nw_endpoint_t remote = nw_connection_copy_endpoint(connection);
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

    nw_connection_start(connection);
}

@interface BonjourListener ()

@property (strong) NSString *name;
@property (strong) NSString *type;
@property (strong) NSString *domain;

@end

@implementation BonjourListener
{
    nw_listener_t _listener;
}

+ (instancetype)createAndStartWithName:(NSString *)aName type:(NSString *)aType domain:(NSString *)aDomain
{
    BonjourListener *result = [[BonjourListener alloc] initWithName:aName type:aType domain:aDomain];

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
            fprintf(stderr, "Listener %s on %s (%s.%s.%s)\n",
                added ? "added" : "removed",
                nw_endpoint_get_bonjour_service_name(advertised_endpoint),
                nw_endpoint_get_bonjour_service_name(advertised_endpoint),
                self.type.UTF8String,
                self.domain.UTF8String);
        });

    nw_listener_set_queue(_listener, dispatch_get_main_queue());

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
            if (g_inbound_connection != NULL)
            {
                // We only support one connection at a time, so if we already
                // have one, reject the incoming connection.
                nw_connection_cancel(connection);
            }
            else
            {
                // Accept the incoming connection and start sending
                // and receiving on it.
                g_inbound_connection = connection;

                start_connection(g_inbound_connection);
                start_send_receive_loop(g_inbound_connection);
            }
        });

    nw_listener_start(_listener);

    return _listener != nil;
}

@end
