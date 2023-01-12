
#import "BonjourConnection.h"
#import <Network/Network.h>
#import <err.h>
#import "DispatchData.h"

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
    void (^_connectionCanceledBlock)(BonjourConnection *aConnection);
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
        [self setStateChangeHandlerBlock];
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

    if (self)
    {
    }
    return self;
}

- (void)dealloc
{
    self.connection = nil;

    _connectionCanceledBlock = nil;
    _didConnectBlock = nil;
    _receiveCompletion = nil;
    _sendCompletion = nil;
    _sendCompletionWithSendLoop = nil;
    _stdInReadHandler = nil;
    _stateChangeHandler = nil;
}

- (NSString *)description
{
    NSString *result = [super description];

    if (self.connection != nil)
    {
        char *descr = nw_connection_copy_description(self.connection);
        result = [NSString stringWithFormat:@"%@ %@", result, [NSString stringWithUTF8String:descr]];
        free(descr);
    }
    return result;
}

#pragma mark -

- (void)setConnectionCanceledBlock:(void (^)(BonjourConnection *aConnection))aConnectionCanceledBlock
{
    _connectionCanceledBlock = aConnectionCanceledBlock;
}

- (void)connectionCanceled
{
    if (_connectionCanceledBlock)
    {
        _connectionCanceledBlock(self);
    }
}

- (void)setDidConnectBlock:(void (^)(void))aDidConnectBlock
{
    _didConnectBlock = aDidConnectBlock;
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
        connection = aConnection;
    }
}

#pragma mark -

- (void)start
{
    nw_connection_set_queue(self.connection, _queue);

    nw_connection_set_state_changed_handler(self.connection, _stateChangeHandler);

    nw_connection_start(self.connection);
}

- (void)startWithDidConnectBlock:(void (^)(void))aDidConnectBlock
{
    [self setDidConnectBlock:aDidConnectBlock];
    [self start];
}

- (void)startSendFromStdIn
{
    [self setStdInReadHandler];
    [self setSendCompletionWithSendLoopBlock];

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

- (void)receiveLoop:(nw_connection_t)aConnection
{
    nw_connection_receive(aConnection, 1, UINT32_MAX, _receiveCompletion);
}

#pragma mark -

- (void)sendDataWithRegularCompletion:(dispatch_data_t)aDataToSend
{
    [self sendData:aDataToSend sendCompletion:_sendCompletion];
}

- (void)sendStringWithRegularCompletion:(NSString *)aStringToSend
{
    [self sendString:aStringToSend sendCompletion:_sendCompletion];
}

- (void)sendData:(dispatch_data_t)aDataToSend sendCompletion:(nw_connection_send_completion_t)aSendCompletion
{
    nw_connection_send(self.connection, aDataToSend,
        NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, true, aSendCompletion);
}

- (void)sendString:(NSString *)aStringToSend sendCompletion:(nw_connection_send_completion_t)aSendCompletion
{
    dispatch_data_t data = [DispatchData dispatch_data_from_NSString:aStringToSend queue:_queue];
    [self sendData:data sendCompletion:aSendCompletion];
}

#pragma mark -

- (void)setReceiveCompletionBlock
{
    __weak typeof(self) weakSelf = self;
    _receiveCompletion =
        ^(dispatch_data_t content, nw_content_context_t context, bool is_complete,
            nw_error_t receive_error)
        {
            __typeof__(self) strongSelf = weakSelf;

            if (content != NULL)
            {
                NSData *data = [NSData dataWithData:(NSData *)content];
                NSString *stringRecieved = [[NSString alloc] initWithData:data
                    encoding:NSUTF8StringEncoding];
                [strongSelf stringReceived:stringRecieved];
            }

            // If the context is marked as complete, and is the final context,
            // we're read-closed.
            if (is_complete &&
                (context == NULL || nw_content_context_get_is_final(context)))
            {
                [strongSelf logOutside:@"is_complete, context is final. reset connection;"];
                [strongSelf connectionCanceled];
            }
            else if (receive_error == NULL)
            {
                // If there was no error in receiving, request more data
                [strongSelf receiveLoop:strongSelf.connection];
            }
        };
}

- (void)setSendCompletionBlock
{
    __weak typeof(self) weakSelf = self;
    _sendCompletion =
        ^(nw_error_t  _Nullable error)
        {
            if (error != NULL)
            {
                [weakSelf logOutside:@"write close error: %d", nw_error_get_error_code(error)];
            }
        };
}

- (void)setSendCompletionWithSendLoopBlock
{
    __weak typeof(self) weakSelf = self;
    _sendCompletionWithSendLoop =
        ^(nw_error_t  _Nullable error)
        {
            __typeof__(self) strongSelf = weakSelf;

            if (error != NULL)
            {
                [strongSelf logOutside:@"send error: %d", nw_error_get_error_code(error)];
            }
            else
            {
                // Continue reading from stdin
                [strongSelf sendLoop];
            }
        };
}

- (void)setStdInReadHandler
{
    __weak typeof(self) weakSelf = self;

    _stdInReadHandler =
        ^(dispatch_data_t _Nonnull read_data, int stdin_error)
        {
            __typeof__(self) strongSelf = weakSelf;
            if (stdin_error != 0)
            {
                [strongSelf logOutside:@"stdin read error: %d", stdin_error];
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
        };
}

- (void)setStateChangeHandlerBlock
{
    __weak typeof(self) weakSelf = self;
    _stateChangeHandler =
        ^(nw_connection_state_t state, nw_error_t error)
        {
            __typeof__(self) strongSelf = weakSelf;
            switch (state)
            {
                case nw_connection_state_invalid:
                {
                    int errorCode = error ? nw_error_get_error_code(error) : 0;
                    [strongSelf logOutside:@"Connection state invalid. Error: %d", errorCode];
                    strongSelf.isConnected = NO;
                    break;
                }
                case nw_connection_state_waiting:
                {
                    int errorCode = error ? nw_error_get_error_code(error) : 0;

                    strongSelf.isConnected = NO;
                    [strongSelf logOutside:@"Connection state waiting. Error: %d", errorCode];

                    break;
                }
                case nw_connection_state_preparing:
                {
                    [strongSelf logOutside:@"Connection state preparing."];
                    strongSelf.isConnected = NO;
                    break;
                }
                case nw_connection_state_ready:
                {
                    strongSelf.isConnected = YES;
                    [strongSelf logOutside:@"Connection succeeded!"];
                    [strongSelf didConnect];
                    strongSelf->_didConnectBlock = nil;

                    [strongSelf receiveLoop:strongSelf.connection];
                    break;
                }
                case nw_connection_state_failed:
                {
                    int errorCode = error ? nw_error_get_error_code(error) : 0;
                    strongSelf.isConnected = NO;
                    [strongSelf logOutside:@"Connect failed. Error: %d", errorCode];
                    [strongSelf connectionCanceled];

                    break;
                }
                case nw_connection_state_cancelled:
                {
                    int errorCode = error ? nw_error_get_error_code(error) : 0;
                    [strongSelf logOutside:@"Connection cancelled. Error: %d", errorCode];
                    strongSelf.isConnected = NO;
                    [strongSelf connectionCanceled];
                    break;
                }
            }
        };
}

@end
