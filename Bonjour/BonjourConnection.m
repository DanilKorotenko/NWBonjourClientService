
#import "BonjourConnection.h"
#import <Network/Network.h>
#import <err.h>

@interface BonjourConnection ()

@property (strong) NSString *name;
@property (strong) NSString *type;
@property (strong) NSString *domain;

@property (readwrite) BOOL isConnected;

@end

@implementation BonjourConnection
{
    nw_connection_t _connection;
    dispatch_queue_t    _queue;
    void (^_connectionCanceledBlock)(void);
}

+ (instancetype)createAndStartWithName:(NSString *)aName type:(NSString *)aType
    domain:(NSString *)aDomain
{
    BonjourConnection *result = [[BonjourConnection alloc] initWithName:aName type:aType
        domain:aDomain];

    if (nil != result)
    {
        [result start];
        [result startSend];
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

        _queue = dispatch_queue_create("BonjourConnection.queue", NULL);

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

- (instancetype)initWithConnection:(nw_connection_t)aConnection
{
    self = [super init];
    if (self)
    {
        _queue = dispatch_queue_create("BonjourConnection.queue", NULL);
        _connection = aConnection;
    }
    return self;
}

#pragma mark -

- (void)setConnectionCanceledBlock:(void (^)(void))aConnectionCanceledBlock
{
    _connectionCanceledBlock = aConnectionCanceledBlock;
}

- (void)connectionCanceled
{
    if (_connectionCanceledBlock)
    {
        _connectionCanceledBlock();
    }
}

#pragma mark -

- (void)start
{
    nw_connection_set_queue(_connection, _queue);

    nw_connection_set_state_changed_handler(_connection,
        ^(nw_connection_state_t state, nw_error_t error)
        {
            nw_endpoint_t remote = nw_connection_copy_endpoint(self->_connection);
            int errorCode = error ? nw_error_get_error_code(error) : 0;

            switch (state)
            {
                case nw_connection_state_invalid:
                {
                    self.isConnected = NO;
                    break;
                }
                case nw_connection_state_waiting:
                {
                    self.isConnected = NO;
                    [self logOutside:[NSString stringWithFormat:
                        @"connect to %s port %u failed, is waiting. Error: %d",
                        nw_endpoint_get_hostname(remote),
                        nw_endpoint_get_port(remote), errorCode]];

                    break;
                }
                case nw_connection_state_preparing:
                {
                    self.isConnected = NO;
                    break;
                }
                case nw_connection_state_ready:
                {
                    self.isConnected = YES;
                    [self logOutside:[NSString stringWithFormat:
                        @"Connection to %s port %u succeeded!",
                        nw_endpoint_get_hostname(remote),
                        nw_endpoint_get_port(remote)]];
                    break;
                }
                case nw_connection_state_failed:
                {
                    self.isConnected = NO;
                    [self logOutside:[NSString stringWithFormat:
                        @"connect to %s port %u failed. Error: %d",
                        nw_endpoint_get_hostname(remote),
                        nw_endpoint_get_port(remote), errorCode]];
                    [self connectionCanceled];
                    break;
                }
                case nw_connection_state_cancelled:
                {
                    self.isConnected = NO;
                    [self connectionCanceled];
                    break;
                }
            }
        });

    nw_connection_start(_connection);

    // Start reading from connection
    [self receiveLoop];
}

- (void)startSend
{
    // Start reading from stdin
    [self sendLoop];
}

- (void)cancel
{
    nw_connection_cancel(_connection);
}

- (void)sendLoop
{
    dispatch_read(STDIN_FILENO, 8192, _queue,
        ^(dispatch_data_t _Nonnull read_data, int stdin_error)
        {
            if (stdin_error != 0)
            {
                [self logOutside:[NSString stringWithFormat:
                    @"stdin read error: %d", stdin_error]];
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
                            [self logOutside:[NSString stringWithFormat:
                                @"write close error: %d", nw_error_get_error_code(error)]];
                        }
                        // Stop reading from stdin, so don't schedule another send_loop
                    });
            }
            else
            {
                // Every send is marked as complete. This has no effect with the default message context for TCP,
                // but is required for UDP to indicate the end of a packet.
                nw_connection_send(self->_connection, read_data,
                    NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, true,
                    ^(nw_error_t  _Nullable error)
                    {
                        if (error != NULL)
                        {
                            [self logOutside:[NSString stringWithFormat:
                                @"send error: %d", nw_error_get_error_code(error)]];
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

- (void)send:(NSString *)aStringToSend
{
    dispatch_data_t data = [self dispatchDataFromNSString:aStringToSend];

    nw_connection_send(self->_connection, data,
        NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, true,
            ^(nw_error_t _Nullable error)
            {
                if (error != NULL)
                {
                    [self logOutside:[NSString stringWithFormat:
                        @"send error: %d", nw_error_get_error_code(error)]];
                }
            });
}

- (void)receiveLoop
{
    nw_connection_receive(self->_connection, 1, UINT32_MAX,
        ^(dispatch_data_t content, nw_content_context_t context, bool is_complete,
            nw_error_t receive_error)
        {
            if (content != NULL)
            {
                // If there is content, write it to stdout asynchronously
                NSData *data = (NSData *)content;
                NSString *stringRecieved = [[NSString alloc] initWithData:data
                    encoding:NSUTF8StringEncoding];
                [self stringReceived:stringRecieved];
            }

            // If the context is marked as complete, and is the final context,
            // we're read-closed.
            if (is_complete &&
                (context == NULL || nw_content_context_get_is_final(context)))
            {
                [self logOutside:@"server disconnected. reset connection;"];
                [self connectionCanceled];
            }
            else if (receive_error == NULL)
            {
                // If there was no error in receiving, request more data
                [self receiveLoop];
            }
        });
}

#pragma mark -

- (dispatch_data_t)dispatchDataFromNSData:(NSData *)aData
{
    // just incase we are mutable;
    CFDataRef immutableSelf = CFBridgingRetain([aData copy]);
    return dispatch_data_create(aData.bytes, aData.length, _queue,
        ^{
            CFRelease(immutableSelf);
        });
}

- (dispatch_data_t)dispatchDataFromNSString:(NSString *)aString
{
    NSData *data = [aString dataUsingEncoding:NSUTF8StringEncoding];
    return [self dispatchDataFromNSData:data];
}


@end
