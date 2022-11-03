
#import "BonjourListener.h"
#import <Network/Network.h>
#import <err.h>
#import "BonjourConnection.h"

@interface BonjourListener ()

@property (strong) NSString *name;
@property (strong) NSString *type;
@property (strong) NSString *domain;
@property (strong) BonjourConnection   *inboundConnection;

@end

@implementation BonjourListener
{
    nw_listener_t       _listener;
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
        _queue = dispatch_queue_create("BonjourService.queue", NULL);
    }
    return self;
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
                self.inboundConnection = nil;
                self->_listener = nil;
                [self start];
            }
        });

    __weak typeof(self) weakSelf = self;
    nw_listener_set_new_connection_handler(_listener,
        ^(nw_connection_t connection)
        {
            if (self.inboundConnection != nil)
            {
                // We only support one connection at a time, so if we already
                // have one, reject the incoming connection.
                nw_connection_cancel(connection);
            }
            else
            {
                // Accept the incoming connection and start sending
                // and receiving on it.
                self.inboundConnection = [[BonjourConnection alloc] initWithConnection:connection];

                [self.inboundConnection setLogBlock:
                    ^(NSString * _Nonnull aLogMessage)
                    {
                        [weakSelf logOutside:aLogMessage];
                    }];
                [self.inboundConnection setStringReceivedBlock:
                    ^(NSString * _Nonnull aStringReceived)
                    {
                        [weakSelf stringReceived:aStringReceived];
                    }];
                [self.inboundConnection setConnectionCanceledBlock:
                    ^{
                        [weakSelf logOutside:@"Client disconnected."];
                        weakSelf.inboundConnection = nil;
                    }];

                [self.inboundConnection start];
                if (self.sendFromStdIn)
                {
                    [self.inboundConnection startSendFromStdIn];
                }
            }
        });

    nw_listener_start(_listener);

    return _listener != nil;
}

- (void)send:(NSString *)aStringToSend
{
    [self.inboundConnection send:aStringToSend];
}

@end
