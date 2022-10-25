//
//  BonjourConnection.m
//  NWBonjourService
//
//  Created by Danil Korotenko on 10/25/22.
//

#import "BonjourConnection.h"

@implementation BonjourConnection
{
    dispatch_queue_t _queue;
    nw_connection_t _connection;
    void (^_isCompleteBlock)(void);
    void (^_dataAvaliableBlock)(NSData *aData);
}

- (instancetype)initWithConnection:(nw_connection_t)aConnection
{
    self = [super init];
    if (self)
    {
        _queue = dispatch_queue_create("connection.queue", NULL);
        _connection = aConnection;
    }
    return self;
}

- (instancetype)initOutboundToBonjourServiceName:(NSString *)aServiceName
{
    // If we are using bonjour to connect, treat the name as a bonjour name
    // Otherwise, treat the name as a hostname
    nw_endpoint_t endpoint =
        nw_endpoint_create_bonjour_service(aServiceName.UTF8String, self.class.defaultType.UTF8String,
        self.class.localDomain.UTF8String);

    nw_parameters_t parameters = nw_parameters_create_secure_tcp(NW_PARAMETERS_DISABLE_PROTOCOL,
        NW_PARAMETERS_DEFAULT_CONFIGURATION);

    nw_connection_t connection = nw_connection_create(endpoint, parameters);

    self = [self initWithConnection:connection];
    if (self)
    {

    }
    return self;
}

- (void)setIsCompleteBlock:(void (^)(void))anIsCompleteBlock
{
    _isCompleteBlock = anIsCompleteBlock;
}

- (void)setDataAvaliableBlock:(void (^)(NSData *aData))aDataAvaliableBlock
{
    _dataAvaliableBlock = aDataAvaliableBlock;
}

- (void)cancel
{
    nw_connection_cancel(_connection);
}

- (void)start
{
    nw_connection_set_queue(_connection, _queue);

    nw_connection_set_state_changed_handler(_connection,
        ^(nw_connection_state_t state, nw_error_t error)
        {
        nw_endpoint_t remote = nw_connection_copy_endpoint(self->_connection);
            errno = error ? nw_error_get_error_code(error) : 0;
            if (state == nw_connection_state_waiting)
            {
                NSString *message = [NSString stringWithFormat:
                    @"connect to %s port %u (tcp) failed, is waiting",
                    nw_endpoint_get_hostname(remote),
                    nw_endpoint_get_port(remote)];
                [self logOutside:message];
            }
            else if (state == nw_connection_state_failed)
            {
                NSString *message = [NSString stringWithFormat:@"connect to %s port %u (tcp) failed",
                    nw_endpoint_get_hostname(remote),
                    nw_endpoint_get_port(remote)];
                [self logOutside:message];
            }
            else if (state == nw_connection_state_ready)
            {
                NSString *message = [NSString stringWithFormat:
                    @"Connection to %s port %u (tcp) succeeded!", nw_endpoint_get_hostname(remote),
                    nw_endpoint_get_port(remote)];
                [self logOutside:message];
            }
            else if (state == nw_connection_state_cancelled)
            {
                NSString *message = [NSString stringWithFormat:
                    @"Connection to %s port %u (tcp) canceled!", nw_endpoint_get_hostname(remote),
                    nw_endpoint_get_port(remote)];
                [self logOutside:message];

                // Release the primary reference on the connection
                // that was taken at creation time
                self->_connection = nil;
                // TODO: inform outside that connection is closed
                if (self->_isCompleteBlock)
                {
                    self->_isCompleteBlock();
                }
            }
        });

    nw_connection_start(_connection);

    // Start reading from connection
    [self receiveLoop];
}

- (void)sendStdInloop
{
    dispatch_read(STDIN_FILENO, 8192, _queue,
        ^(dispatch_data_t _Nonnull read_data, int stdin_error)
        {
            if (stdin_error != 0)
            {
                NSString *message = [NSString stringWithFormat:@"stdin read error: %d", stdin_error];
                [self logOutside:message];
            }
            else if (read_data == NULL)
            {
                // NULL data represents EOF
                // Send a "write close" on the connection, by sending NULL data with the final message context marked as complete.
                // Note that it is valid to send with NULL data but a non-NULL context.
                nw_connection_send(self->_connection, NULL, NW_CONNECTION_FINAL_MESSAGE_CONTEXT, true,
                    ^(nw_error_t _Nullable error)
                    {
                        if (error != NULL)
                        {
                            NSString *message = [NSString stringWithFormat:@"write close error: %d",
                                nw_error_get_error_code(error)];
                            [self logOutside:message];
                        }
                        // Stop reading from stdin, so don't schedule another send_loop
                    });
            }
            else
            {
                // Every send is marked as complete. This has no effect with the default message context for TCP,
                // but is required for UDP to indicate the end of a packet.
                nw_connection_send(self->_connection, read_data, NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, true,
                    ^(nw_error_t _Nullable error)
                    {
                        if (error != NULL)
                        {
                            NSString *message = [NSString stringWithFormat:@"send error: %d",
                                nw_error_get_error_code(error)];
                            [self logOutside:message];
                        }
                        else
                        {
                            // Continue reading from stdin
                            [self sendStdInloop];
                        }
                    });
            }
        });
}

- (void)receiveLoop
{
    nw_connection_receive(_connection, 1, UINT32_MAX,
        ^(dispatch_data_t content, nw_content_context_t context, bool is_complete, nw_error_t receive_error)
        {
            dispatch_block_t schedule_next_receive =
                ^{
                    // If the context is marked as complete, and is the final context,
                    // we're read-closed.
                    if (is_complete &&
                        (context == NULL || nw_content_context_get_is_final(context)))
                    {
                        if (self->_isCompleteBlock)
                        {
                            self->_isCompleteBlock();
                        }
                    }

                    // If there was no error in receiving, request more data
                    if (receive_error == NULL)
                    {
                        [self receiveLoop];
                    }
                };

            if (content != NULL)
            {
                if(self->_dataAvaliableBlock)
                {
                    NSData *contentData = (NSData *)content;
                    self->_dataAvaliableBlock(contentData);
                    schedule_next_receive();
                }
            }
            else
            {
                // Content was NULL, so directly schedule the next receive
                schedule_next_receive();
            }
        });
}

@end
