
#import "BonjourConnection.h"
#import <Network/Network.h>
#import <err.h>

@interface BonjourConnection ()

@property (strong) NSString *name;
@property (strong) NSString *type;
@property (strong) NSString *domain;

@end

@implementation BonjourConnection
{
    nw_connection_t _connection;
}

+ (instancetype)createAndStartWithName:(NSString *)aName type:(NSString *)aType
    domain:(NSString *)aDomain
{
    BonjourConnection *result = [[BonjourConnection alloc] initWithName:aName type:aType
        domain:aDomain];

    if (nil != result)
    {
        [result start];
        [result startSendRecieveLoop];
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

        // If we are using bonjour to connect, treat the name as a bonjour name
        // Otherwise, treat the name as a hostname
        nw_endpoint_t endpoint =
            nw_endpoint_create_bonjour_service(self.name.UTF8String, self.type.UTF8String,
            self.domain.UTF8String);

        nw_parameters_t parameters = nw_parameters_create_secure_tcp(NW_PARAMETERS_DISABLE_PROTOCOL,
            NW_PARAMETERS_DEFAULT_CONFIGURATION);

        _connection = nw_connection_create(endpoint, parameters);

        if (_connection == nil)
        {
            self = nil;
        }
    }
    return self;
}

- (void)start
{
    nw_connection_set_queue(_connection, dispatch_get_main_queue());

    nw_connection_set_state_changed_handler(_connection,
        ^(nw_connection_state_t state, nw_error_t error)
        {
            nw_endpoint_t remote = nw_connection_copy_endpoint(self->_connection);
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

    nw_connection_start(_connection);
}

- (void)startSendRecieveLoop
{
    // Start reading from stdin
    [self sendLoop];

    // Start reading from connection
    [self receiveLoop];
}

- (void)sendLoop
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
                nw_connection_send(self->_connection, NULL, NW_CONNECTION_FINAL_MESSAGE_CONTEXT, true,
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
                nw_connection_send(self->_connection, read_data, NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, true,
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
                            [self sendLoop];
                        }
                    });
            }
        });
}

- (void)receiveLoop
{
    nw_connection_receive(self->_connection, 1, UINT32_MAX,
        ^(dispatch_data_t content, nw_content_context_t context, bool is_complete,
            nw_error_t receive_error)
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
                        [self receiveLoop];
                    }
                };

            if (content != NULL)
            {
                // If there is content, write it to stdout asynchronously
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

@end
