
#import "BonjourListener.h"
#import <Network/Network.h>
#import <err.h>
#import "BonjourConnectionsManager.h"

@interface BonjourListener ()

@property (strong) NSString *name;
@property (strong) NSString *type;
@property (strong) NSString *domain;
@property (strong) BonjourConnectionsManager *connectionsManager;
@property (readwrite) BOOL shouldStop;
@property (readwrite) BOOL didStop;

@property (strong, nonatomic) void (^logBlock)(NSString *aLogMessage);

@property (strong) nw_listener_t listener;
@property (strong) dispatch_queue_t queue;

@end

@implementation BonjourListener
{
    nw_listener_state_changed_handler_t     _listenerStateChangeHandler;
    nw_listener_new_connection_handler_t    _listenerNewConnectionHandler;
}

- (instancetype)initWithName:(NSString *)aName type:(NSString *)aType domain:(NSString *)aDomain
{
    self = [super init];
    if (self)
    {
        self.name = aName;
        self.type = aType;
        self.domain = aDomain;
        self.connectionsManager = [[BonjourConnectionsManager alloc] init];
        __weak typeof(self) weakSelf = self;

        self.connectionsManager.connectionCanceledBlock =
            ^{
                __typeof__(self) strongSelf = weakSelf;
                [strongSelf logOutside:@"Connection closed."];
            };
        self.queue = dispatch_queue_create("BonjourListener.queue", NULL);

        [self setListenerStateChangeHandler];
        [self setListenerNewConnectionHandler];
    }
    return self;
}

- (void)dealloc
{
    self.name = nil;
    self.type = nil;
    self.domain = nil;
    self.connectionsManager = nil;

    self.queue = nil;
    self.listener = nil;
}

#pragma mark -

- (BOOL)start
{
    nw_parameters_t parameters = nw_parameters_create_secure_tcp(NW_PARAMETERS_DISABLE_PROTOCOL,
        NW_PARAMETERS_DEFAULT_CONFIGURATION);

    self.listener = nw_listener_create(parameters);

    if (self.listener != nil)
    {
        // Advertise name over Bonjour
        nw_advertise_descriptor_t advertise = nw_advertise_descriptor_create_bonjour_service(
            self.name.UTF8String,
            self.type.UTF8String,
            self.domain.UTF8String);

        nw_listener_set_advertise_descriptor(self.listener, advertise);

        __weak typeof(self) weakSelf = self;
        nw_listener_set_advertised_endpoint_changed_handler(self.listener,
            ^(nw_endpoint_t _Nonnull advertised_endpoint, bool added)
            {
                __typeof__(self) strongSelf = weakSelf;
                [strongSelf logOutside: @"Listener %s on %s (%s.%s.%s)", added ? "added" : "removed",
                    nw_endpoint_get_bonjour_service_name(advertised_endpoint),
                    nw_endpoint_get_bonjour_service_name(advertised_endpoint),
                    strongSelf.type.UTF8String,
                    strongSelf.domain.UTF8String];
            });

        nw_listener_set_queue(self.listener, self.queue);

        nw_listener_set_state_changed_handler(self.listener, _listenerStateChangeHandler);
        nw_listener_set_new_connection_handler(self.listener, _listenerNewConnectionHandler);

        nw_listener_start(self.listener);
    }

    return self.listener != nil;
}

- (void)stop
{
    if (self.listener)
    {
        self.shouldStop = YES;
        self.didStop = NO;
        nw_listener_cancel(self.listener);
        // wait until it really stop
        while (!self.didStop)
        {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1f]];
        }
    }
}

#pragma mark -

- (void)sendData:(dispatch_data_t)aData
    withSendCompletionBlock:(void (^)(NSError *error))aSendCompletionBlock
{
    [self.connectionsManager sendData:aData withSendCompletionBlock:aSendCompletionBlock];
}

- (void)sendString:(NSString *)aString
    withSendCompletionBlock:(void (^)(NSInteger errorCode))aSendCompletionBlock
{
    [self.connectionsManager sendString:aString withSendCompletionBlock:aSendCompletionBlock];
}

#pragma mark -

- (void)setListenerStateChangeHandler
{
    __weak typeof(self) weakSelf = self;
    _listenerStateChangeHandler =
        ^(nw_listener_state_t state, nw_error_t error)
        {
            __typeof__(self) strongSelf = weakSelf;
            if (state == nw_listener_state_waiting)
            {
                [strongSelf logOutside:@"Listener on port %u waiting",
                    nw_listener_get_port(strongSelf.listener)];
            }
            else if (state == nw_listener_state_failed)
            {
                [strongSelf logOutside:@"listener failed"];
            }
            else if (state == nw_listener_state_ready)
            {
                [strongSelf logOutside:@"Listener on port %u ready!",
                    nw_listener_get_port(strongSelf.listener)];
            }
            else if (state == nw_listener_state_cancelled)
            {
                // Release the primary reference on the listener
                // that was taken at creation time
                [strongSelf logOutside:@"listener canceled."];
                if (!strongSelf.shouldStop)
                {
                    [strongSelf logOutside:@"Try to restart."];
                    strongSelf.connectionsManager = nil;
                    strongSelf.connectionsManager = [[BonjourConnectionsManager alloc] init];

                    strongSelf.listener = nil;
                    [strongSelf start];
                }
                else
                {
                    strongSelf.didStop = YES;
                }
            }
        };
}

- (void)setListenerNewConnectionHandler
{
    __weak typeof(self) weakSelf = self;
    _listenerNewConnectionHandler =
        ^(nw_connection_t connection)
        {
            __typeof__(self) strongSelf = weakSelf;

            [strongSelf.connectionsManager startConnection:connection
                didConnectBlock:
                ^{
                    [strongSelf logOutside:@"New Connection"];
                }];
        };
}

#pragma mark -

- (void)logOutside:(NSString *)aLogMessage, ...
{
    if (nil != self.logBlock)
    {
        NSString *message = nil;
        va_list args;
        va_start(args, aLogMessage);
        message = [[NSString alloc] initWithFormat:aLogMessage arguments:args];
        va_end(args);
        self.logBlock(message);
    }
}

#pragma mark -

- (void)setLogBlock:(void (^)(NSString *aLogMessage))aLogBlock
{
    self->_logBlock = aLogBlock;
    self.connectionsManager.logBlock = aLogBlock;
}

- (void)setStringReceivedBlock:(void (^)(NSString *aStringReceived))aStringReceivedBlock
{
    self.connectionsManager.stringReceivedBlock = aStringReceivedBlock;
}

@end
