//
//  BonjourService.m
//  NWBonjourClientService
//
//  Created by Danil Korotenko on 10/25/22.
//

#import "BonjourService.h"
#import <Network/Network.h>
#import <err.h>
#import "BonjourConnection.h"

@interface BonjourService ()

@property (strong) NSString *name;

@end

@implementation BonjourService
{
    nw_listener_t _listener;
    dispatch_queue_t _queue;

    void (^_newConnectionBlock)(BonjourConnection *aNewConnection);
}

- (instancetype)initWithName:(NSString * _Nonnull)aName
{
    self = [super init];
    if (self)
    {
        self.name = aName;
        _queue = dispatch_queue_create(aName.UTF8String, NULL);
    }
    return self;
}

- (void)setNewConnectionBlock:(void (^)(BonjourConnection *aNewConnection))aNewConnectionBlock
{
    _newConnectionBlock = aNewConnectionBlock;
}

#pragma mark -

- (BOOL)start
{
    [self createAndStartListener];
    if (_listener == nil)
    {
        return NO;
    }
    return YES;
}

- (void)createAndStartListener
{
    nw_parameters_t parameters = nw_parameters_create_secure_tcp(NW_PARAMETERS_DISABLE_PROTOCOL,
        NW_PARAMETERS_DEFAULT_CONFIGURATION);

    _listener = nw_listener_create(parameters);

    // Advertise name over Bonjour
    nw_advertise_descriptor_t advertise = nw_advertise_descriptor_create_bonjour_service(
        self.name.UTF8String, self.class.defaultType.UTF8String, self.class.localDomain.UTF8String);

    nw_listener_set_advertise_descriptor(_listener, advertise);

    nw_listener_set_advertised_endpoint_changed_handler(_listener,
        ^(nw_endpoint_t _Nonnull advertised_endpoint, bool added)
        {
            NSString *message = [NSString stringWithFormat:@"Listener %s on %s (%s.%s.%s)",
                added ? "added" : "removed",
                nw_endpoint_get_bonjour_service_name(advertised_endpoint),
                nw_endpoint_get_bonjour_service_name(advertised_endpoint),
                "_exampleService._tcp", "local"];
            [self logOutside:message];
        });

    nw_listener_set_queue(_listener, _queue);

    nw_listener_set_state_changed_handler(_listener,
        ^(nw_listener_state_t state, nw_error_t error)
        {
            if (state == nw_listener_state_waiting)
            {
                NSString *message = [NSString stringWithFormat:@"Listener on port %u (tcp) waiting",
                                     nw_listener_get_port(self->_listener)];
                [self logOutside:message];
            }
            else if (state == nw_listener_state_failed)
            {
                CFErrorRef errorRef = nw_error_copy_cf_error(error);
                NSError *err = (NSError *)CFBridgingRelease(errorRef);

                NSString *message = [NSString stringWithFormat:@"listener failed. Error: %@", [err description]];
                [self logOutside:message];
            }
            else if (state == nw_listener_state_ready)
            {
                NSString *message = [NSString stringWithFormat:@"Listener on port %u (tcp) ready!",
                                     nw_listener_get_port(self->_listener)];
                [self logOutside:message];
            }
            else if (state == nw_listener_state_cancelled)
            {
                // Release the primary reference on the listener
                // that was taken at creation time
                self->_listener = nil;
// TODO: Service canceled, notify outside.
            }
        });

    nw_listener_set_new_connection_handler(_listener,
        ^(nw_connection_t connection)
        {
        if(self->_newConnectionBlock)
            {
                BonjourConnection *newConnection =
                    [[BonjourConnection alloc] initWithConnection:connection];
                self->_newConnectionBlock(newConnection);
            }
        });

    nw_listener_start(_listener);
}

@end
