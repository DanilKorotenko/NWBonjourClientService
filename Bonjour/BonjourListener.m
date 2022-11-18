
#import "BonjourListener.h"
#import <Network/Network.h>
#import <err.h>
#import "BonjourConnection.h"

@interface BonjourListener ()

@property (strong) NSString *name;
@property (strong) NSString *type;
@property (strong) NSString *domain;
@property (strong) NSMutableArray *inboundConnections;

@end

@implementation BonjourListener
{
    nw_listener_t       _listener;
    dispatch_queue_t    _queue;
    void (^_stdInReadHandler)(dispatch_data_t data, int error);

    void (^_inboundConnectionLogBlock)(NSString *aLogMessage);
    void (^_inboundConnectionStringReceivedBlock)(NSString *aStringReceivedMessage);
    void (^_inboundConnectionCanceledBlock)(BonjourConnection *aConnection);
}

- (instancetype)initWithName:(NSString *)aName type:(NSString *)aType domain:(NSString *)aDomain
{
    self = [super init];
    if (self)
    {
        self.name = aName;
        self.type = aType;
        self.domain = aDomain;
        self.inboundConnections = [NSMutableArray array];
        _queue = dispatch_queue_create("BonjourService.queue", NULL);

        [self setInboundConnectionLogBlock];
        [self setInboundConnectionStringReceivedBlock];
        [self setInboundConnectionCancelledBlock];
    }
    return self;
}

- (void)dealloc
{
    self.name = nil;
    self.type = nil;
    self.domain = nil;
    [self.inboundConnections removeAllObjects];

    _queue = nil;
    _listener = nil;
}

#pragma mark -

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
            [self logOutside:message];
        });

    nw_listener_set_queue(_listener, _queue);

    nw_listener_set_state_changed_handler(_listener,
        ^(nw_listener_state_t state, nw_error_t error)
        {
            errno = error ? nw_error_get_error_code(error) : 0;
            if (state == nw_listener_state_waiting)
            {
                NSString *message = [NSString stringWithFormat:@"Listener on port %u waiting",
                    nw_listener_get_port(self->_listener)];
                [self logOutside:message];
            }
            else if (state == nw_listener_state_failed)
            {
                [self logOutside:@"listener failed"];
            }
            else if (state == nw_listener_state_ready)
            {
                [self logOutside:[NSString stringWithFormat:@"Listener on port %u ready!",
                    nw_listener_get_port(self->_listener)]];
            }
            else if (state == nw_listener_state_cancelled)
            {
                // Release the primary reference on the listener
                // that was taken at creation time
                [self logOutside:@"listener canceled. Try to restart."];
                [self.inboundConnections removeAllObjects];
                self->_listener = nil;
                [self start];
            }
        });

    __weak typeof(self) weakSelf = self;
    nw_listener_set_new_connection_handler(_listener,
        ^(nw_connection_t connection)
        {
            __typeof__(self) strongSelf = weakSelf;

            // Accept the incoming connection and start sending
            // and receiving on it.
            BonjourConnection *inboundConnection = [[BonjourConnection alloc]
                initWithConnection:connection];

            [inboundConnection setLogBlock:strongSelf->_inboundConnectionLogBlock];
            [inboundConnection setStringReceivedBlock:
                strongSelf->_inboundConnectionStringReceivedBlock];
            [inboundConnection setConnectionCanceledBlock:
                strongSelf->_inboundConnectionCanceledBlock];
            [inboundConnection start];

            [self.inboundConnections addObject:inboundConnection];
        });

    nw_listener_start(_listener);

    return _listener != nil;
}

- (void)startSendFromStdIn
{
    [self setStdInReadHandler];

    // Start reading from stdin
    [self sendStdInLoop];
}

- (void)sendStdInLoop
{
    dispatch_read(STDIN_FILENO, 8192, _queue, _stdInReadHandler);
}

#pragma mark -

- (void)sendData:(dispatch_data_t)aDataToSend
{
    for (BonjourConnection *connection in self.inboundConnections)
    {
        [connection sendDataWithRegularCompletion:aDataToSend];
    }
}

- (void)send:(NSString *)aStringToSend
{
    for (BonjourConnection *connection in self.inboundConnections)
    {
        [connection sendStringWithRegularCompletion:aStringToSend];
    }
}

#pragma mark -

- (void)setStdInReadHandler
{
    __weak typeof(self) weakSelf = self;
    _stdInReadHandler =
        ^(dispatch_data_t _Nonnull read_data, int stdin_error)
        {
            __typeof__(self) strongSelf = weakSelf;
            if (stdin_error != 0)
            {
                [strongSelf logOutside:[NSString stringWithFormat:
                    @"stdin read error: %d", stdin_error]];
            }
            else if (read_data != NULL)
            {
                [strongSelf sendData:read_data];

                // Continue reading from stdin
                [strongSelf sendStdInLoop];
            }
        };
}

- (void)setInboundConnectionLogBlock
{
    __weak typeof(self) weakSelf = self;
    _inboundConnectionLogBlock =
        ^(NSString *aLogMessage)
        {
            __typeof__(self) strongSelf = weakSelf;
            [strongSelf logOutside:aLogMessage];
        };
}

- (void)setInboundConnectionStringReceivedBlock
{
    __weak typeof(self) weakSelf = self;
    _inboundConnectionStringReceivedBlock =
        ^(NSString *aStringReceived)
        {
            __typeof__(self) strongSelf = weakSelf;
            [strongSelf stringReceived:aStringReceived];
        };
}

- (void)setInboundConnectionCancelledBlock
{
    __weak typeof(self) weakSelf = self;
    _inboundConnectionCanceledBlock =
        ^(BonjourConnection *aConnection)
        {
            __typeof__(self) strongSelf = weakSelf;
            [strongSelf logOutside:@"Client disconnected."];
            if ([strongSelf.inboundConnections containsObject:aConnection])
            {
                [strongSelf.inboundConnections removeObject:aConnection];
            }
        };
}

@end
