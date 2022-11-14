
#import "BonjourConnection.h"
#import <Network/Network.h>
#import <err.h>

@interface BonjourConnection ()

@property (readwrite) BOOL isConnected;

@end

@implementation BonjourConnection
{
    nw_connection_t _connection;
    dispatch_queue_t    _queue;
    void (^_connectionCanceledBlock)(void);
    void (^_didConnectBlock)(void);
}

+ (nw_connection_t)newConnectionWithName:(NSString *)aName type:(NSString *)aType
    domain:(NSString *)aDomain
{
    nw_connection_t result = nil;

    // If we are using bonjour to connect, treat the name as a bonjour name
    // Otherwise, treat the name as a hostname
    nw_endpoint_t endpoint =
        nw_endpoint_create_bonjour_service(aName.UTF8String, aType.UTF8String,
        aDomain.UTF8String);

    nw_parameters_t parameters = nw_parameters_create_secure_tcp(NW_PARAMETERS_DISABLE_PROTOCOL,
        NW_PARAMETERS_DEFAULT_CONFIGURATION);

    result = nw_connection_create(endpoint, parameters);

    nw_release(parameters);
    nw_release(endpoint);

    return result;
}

+ (instancetype)createAndStartWithName:(NSString *)aName type:(NSString *)aType
    domain:(NSString *)aDomain
{
    BonjourConnection *result = [[BonjourConnection alloc] initWithName:aName type:aType
        domain:aDomain];

    if (nil != result)
    {
        [result startWithDidConnectBlock:
            ^{

            }];
        [result startSendFromStdIn];
    }

    return result;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _queue = dispatch_queue_create("BonjourConnection.queue", NULL);
    }
    return self;
}

- (instancetype)initWithConnection:(nw_connection_t)aConnection
{
    self = [self init];
    if (self)
    {
        _connection = nw_retain(aConnection);
    }
    return self;
}

- (instancetype)initWithName:(NSString *)aName type:(NSString *)aType domain:(NSString *)aDomain
{
    nw_connection_t connection = [[self class] newConnectionWithName:aName type:aType domain:aDomain];

    if (connection == nil)
    {
        return nil;
    }

    self = [self initWithConnection:connection];
    if (self)
    {
    }
    return self;
}

- (void)dealloc
{
    nw_release(_connection);

    dispatch_release(_queue);

    if (_connectionCanceledBlock != nil)
    {
        Block_release(_connectionCanceledBlock);
    }

    if (_didConnectBlock != nil)
    {
        Block_release(_didConnectBlock);
    }

    [super dealloc];
}

#pragma mark -

- (void)setConnectionCanceledBlock:(void (^)(void))aConnectionCanceledBlock
{
    _connectionCanceledBlock = Block_copy(aConnectionCanceledBlock);
}

- (void)connectionCanceled
{
    if (_connectionCanceledBlock)
    {
        _connectionCanceledBlock();
    }
}

- (void)setDidConnectBlock:(void (^)(void))aDidConnectBlock
{
    _didConnectBlock = Block_copy(aDidConnectBlock);
}

- (void)didConnect
{
    if (_didConnectBlock)
    {
        _didConnectBlock();
    }
}

#pragma mark -

- (void)startWithDidConnectBlock:(void (^)(void))aDidConnectBlock;
{
    nw_connection_set_queue(_connection, _queue);

    nw_connection_set_state_changed_handler(_connection,
        ^(nw_connection_state_t state, nw_error_t error)
        {
            [self connectionStateHandlerState:state error:error];
        });

    nw_connection_start(_connection);

    // Start reading from connection
    [self receiveLoop];
}

- (void)startSendFromStdIn
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
            @autoreleasepool
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
                            @autoreleasepool
                            {
                                if (error != NULL)
                                {
                                    [self logOutside:[NSString stringWithFormat:
                                        @"write close error: %d", nw_error_get_error_code(error)]];
                                }
                                // Stop reading from stdin, so don't schedule another send_loop
                            }
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
                            @autoreleasepool
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
                            }
                        });
                }
            }
        });
}

- (void)send:(NSString *)aStringToSend
{
    dispatch_data_t data = [self newDispatchDataFromNSString:aStringToSend];

    nw_connection_send(self->_connection, data,
        NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, true,
            ^(nw_error_t _Nullable error)
            {
                @autoreleasepool
                {
                    if (error != NULL)
                    {
                        [self logOutside:[NSString stringWithFormat:
                            @"send error: %d", nw_error_get_error_code(error)]];
                    }
                }
            });
}

- (void)receiveLoop
{
    nw_connection_receive(self->_connection, 1, UINT32_MAX,
        ^(dispatch_data_t content, nw_content_context_t context, bool is_complete,
            nw_error_t receive_error)
        {
            @autoreleasepool
            {
                if (content != NULL)
                {
                    // If there is content, write it to stdout asynchronously
                    NSData *data = [NSData dataWithData:(NSData *)content];
                    NSString *stringRecieved = [[NSString alloc] initWithData:data
                        encoding:NSUTF8StringEncoding];
                    [self stringReceived:stringRecieved];
                    [stringRecieved release];
                }

                // If the context is marked as complete, and is the final context,
                // we're read-closed.
                if (is_complete &&
                    (context == NULL || nw_content_context_get_is_final(context)))
                {
                    [self logOutside:@"server disconnected. reset connection;"];
                    [self connectionCanceled];
                    nw_release(_connection);
                    _connection = nil;
                }
                else if (receive_error == NULL)
                {
                    // If there was no error in receiving, request more data
                    [self receiveLoop];
                }
            }
        });
}

- (void)connectionStateHandlerState:(nw_connection_state_t)aState error:(nw_error_t)anError
{
    @autoreleasepool
    {
        nw_endpoint_t remote = nw_connection_copy_endpoint(self->_connection);
        int errorCode = anError ? nw_error_get_error_code(anError) : 0;

        switch (aState)
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
//                        [self connectionCanceled];
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

                [self didConnect];

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
                nw_release(_connection);
                _connection = nil;
                break;
            }
            case nw_connection_state_cancelled:
            {
                self.isConnected = NO;
                [self connectionCanceled];
                nw_release(_connection);
                _connection = nil;
                break;
            }
        }
        nw_release(remote);
    }
}

#pragma mark -

- (dispatch_data_t)newDispatchDataFromNSData:(NSData *)aData
{
    return dispatch_data_create(aData.bytes, aData.length, _queue, DISPATCH_DATA_DESTRUCTOR_DEFAULT);
}

- (dispatch_data_t)newDispatchDataFromNSString:(NSString *)aString
{
    NSData *data = [aString dataUsingEncoding:NSUTF8StringEncoding];
    return [self newDispatchDataFromNSData:data];
}

@end
