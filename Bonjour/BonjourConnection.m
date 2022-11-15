
#import "BonjourConnection.h"
#import <Network/Network.h>
#import <err.h>

@interface BonjourConnection ()

@property (readwrite, atomic) BOOL isConnected;
@property (readwrite, atomic) nw_connection_t connection;

@end

@implementation BonjourConnection
{
    dispatch_queue_t                        _queue;
    nw_connection_receive_completion_t      _receiveCompletion;
    nw_connection_send_completion_t         _sendCompletion;
    nw_connection_send_completion_t         _sendCompletionWithSendLoop;
    nw_connection_state_changed_handler_t   _stateChangeHandler;
    void (^_stdInReadHandler)(dispatch_data_t data, int error);
    void (^_connectionCanceledBlock)(void);
    void (^_didConnectBlock)(void);
}

@synthesize connection;

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

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _queue = dispatch_queue_create("BonjourConnection.queue", NULL);
        [self setReceiveCompletionBlock];
        [self setSendCompletionBlock];
    }
    return self;
}

- (instancetype)initWithConnection:(nw_connection_t)aConnection
{
    self = [self init];
    if (self)
    {
        self.connection = aConnection;
    }
    return self;
}

- (instancetype)initWithName:(NSString *)aName type:(NSString *)aType domain:(NSString *)aDomain
{
    nw_connection_t con = [[self class] newConnectionWithName:aName type:aType domain:aDomain];

    if (con == nil)
    {
        return nil;
    }

    self = [self initWithConnection:con];

    nw_release(con);

    if (self)
    {
    }
    return self;
}

- (instancetype)autorelease
{
    return [super autorelease];
}

- (void)dealloc
{
    self.connection = nil;

    dispatch_release(_queue);

    if (_connectionCanceledBlock != nil)
    {
        Block_release(_connectionCanceledBlock);
    }

    if (_didConnectBlock != nil)
    {
        Block_release(_didConnectBlock);
    }

    if (_receiveCompletion != nil)
    {
        Block_release(_receiveCompletion);
    }

    if (_sendCompletion != nil)
    {
        Block_release(_sendCompletion);
    }

    if (_sendCompletionWithSendLoop)
    {
        Block_release(_sendCompletionWithSendLoop);
    }

    if (_stdInReadHandler)
    {
        Block_release(_stdInReadHandler);
    }

    if (_stateChangeHandler)
    {
        Block_release(_stateChangeHandler);
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

- (nw_connection_t)connection
{
    return connection;
}

- (void)setConnection:(nw_connection_t)aConnection
{
    if (connection != aConnection)
    {
        nw_release(connection);
        connection = nw_retain(aConnection);
    }
}

#pragma mark -

- (void)start
{
    nw_connection_set_queue(self.connection, _queue);

    nw_connection_set_state_changed_handler(self.connection, _stateChangeHandler);

    nw_connection_start(self.connection);

    // Start reading from connection
    [self receiveLoop:self.connection];
}

- (void)startSendFromStdIn
{
    [self setStdInReadHandler];

    // Start reading from stdin
    [self sendLoop];
}

- (void)cancel
{
    nw_connection_cancel(self.connection);
}

- (void)sendLoop
{
    dispatch_read(STDIN_FILENO, 8192, _queue, _stdInReadHandler);
}

- (void)send:(NSString *)aStringToSend
{
    dispatch_data_t data = [self newDispatchDataFromNSString:aStringToSend];

    nw_connection_send(self.connection, data,
        NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, true, _sendCompletion);
}

- (void)receiveLoop:(nw_connection_t)aConnection
{
    nw_connection_receive(aConnection, 1, UINT32_MAX, _receiveCompletion);
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

#pragma mark -

- (void)setReceiveCompletionBlock
{
    __weak typeof(self) weakSelf = self;
    _receiveCompletion = Block_copy(
        ^(dispatch_data_t content, nw_content_context_t context, bool is_complete,
            nw_error_t receive_error)
        {
            __typeof__(self) strongSelf = weakSelf;

            if (content != NULL)
            {
                // If there is content, write it to stdout asynchronously
                NSData *data = [NSData dataWithData:(NSData *)content];
                NSString *stringRecieved = [[NSString alloc] initWithData:data
                    encoding:NSUTF8StringEncoding];
                [strongSelf stringReceived:stringRecieved];
                [stringRecieved release];
            }

            // If the context is marked as complete, and is the final context,
            // we're read-closed.
            if (is_complete &&
                (context == NULL || nw_content_context_get_is_final(context)))
            {
                [strongSelf logOutside:@"server disconnected. reset connection;"];
                [strongSelf connectionCanceled];
            }
            else if (receive_error == NULL)
            {
                // If there was no error in receiving, request more data
                [strongSelf receiveLoop:strongSelf.connection];
            }
        });
}

- (void)setSendCompletionBlock
{
    __weak typeof(self) weakSelf = self;

    _sendCompletion = Block_copy(
        ^(nw_error_t  _Nullable error)
        {
            if (error != NULL)
            {
                [weakSelf logOutside:[NSString stringWithFormat:
                    @"write close error: %d", nw_error_get_error_code(error)]];
            }
        });

    _sendCompletionWithSendLoop = Block_copy(
        ^(nw_error_t  _Nullable error)
        {
            __typeof__(self) strongSelf = weakSelf;

            if (error != NULL)
            {
                [strongSelf logOutside:[NSString stringWithFormat:
                    @"send error: %d", nw_error_get_error_code(error)]];
            }
            else
            {
                // Continue reading from stdin
                [strongSelf sendLoop];
            }
        });
}

- (void)setStdInReadHandler
{
    __weak typeof(self) weakSelf = self;

    _stdInReadHandler = Block_copy(
        ^(dispatch_data_t _Nonnull read_data, int stdin_error)
        {
            __typeof__(self) strongSelf = weakSelf;
            if (stdin_error != 0)
            {
                [strongSelf logOutside:[NSString stringWithFormat:
                    @"stdin read error: %d", stdin_error]];
            }
            else if (read_data == NULL)
            {
                // NULL data represents EOF
                // Send a "write close" on the connection, by sending NULL data with the final message context marked as complete.
                // Note that it is valid to send with NULL data but a non-NULL context.

                // Stop reading from stdin, so don't schedule another send_loop
                nw_connection_send(strongSelf.connection, NULL,
                    NW_CONNECTION_FINAL_MESSAGE_CONTEXT, true, strongSelf->_sendCompletion);
            }
            else
            {
                // Every send is marked as complete. This has no effect with the default message context for TCP,
                // but is required for UDP to indicate the end of a packet.
                nw_connection_send(strongSelf.connection, read_data,
                    NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, true, strongSelf->_sendCompletionWithSendLoop);
            }
        });
}

- (void)setStateChangeHandlerBlock
{
    __weak typeof(self) weakSelf = self;

    _stateChangeHandler = Block_copy(
        ^(nw_connection_state_t state, nw_error_t error)
        {
            __typeof__(self) strongSelf = weakSelf;

            switch (state)
            {
                case nw_connection_state_invalid:
                {
                    strongSelf.isConnected = NO;
                    break;
                }
                case nw_connection_state_waiting:
                {
                    int errorCode = error ? nw_error_get_error_code(error) : 0;

                    strongSelf.isConnected = NO;
                    [strongSelf logOutside:[NSString stringWithFormat:
                        @"Connect failed, is waiting. Error: %d", errorCode]];

                    break;
                }
                case nw_connection_state_preparing:
                {
                    strongSelf.isConnected = NO;
                    break;
                }
                case nw_connection_state_ready:
                {
                    strongSelf.isConnected = YES;
                    [strongSelf logOutside:[NSString stringWithFormat:
                        @"Connection succeeded!"]];

                    break;
                }
                case nw_connection_state_failed:
                {
                    int errorCode = error ? nw_error_get_error_code(error) : 0;

                    strongSelf.isConnected = NO;
                    [strongSelf logOutside:[NSString stringWithFormat:
                        @"Connect failed. Error: %d", errorCode]];
                    [strongSelf connectionCanceled];

                    break;
                }
                case nw_connection_state_cancelled:
                {
                    strongSelf.isConnected = NO;
                    [strongSelf connectionCanceled];
                    break;
                }
            }
        });
}

@end
