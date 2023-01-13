//
//  BonjourConnectionsManager.m
//  NWBonjourClientService
//
//  Created by Danil Korotenko on 1/13/23.
//

#import "BonjourConnectionsManager.h"

#import <Network/Network.h>

@interface BonjourConnectionsManager ()

@property (strong) NSMutableArray *readyConnections;
@property (strong) dispatch_queue_t queue;

@end

@implementation BonjourConnectionsManager

//// singleton implementation
//+ (BonjourConnectionsManager *)sharedManager
//{
//    static BonjourConnectionsManager *sharedManager = nil;
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken,
//    ^{
//        sharedManager = [[BonjourConnectionsManager alloc] init];
//    });
//    return sharedManager;
//}

+ (nw_connection_t)newConnectionWithName:(NSString *)aName type:(NSString *)aType
    domain:(NSString *)aDomain
{
    // If we are using bonjour to connect, treat the name as a bonjour name
    // Otherwise, treat the name as a hostname
    nw_endpoint_t endpoint =
        nw_endpoint_create_bonjour_service(aName.UTF8String, aType.UTF8String,
        aDomain.UTF8String);

    nw_parameters_t parameters = nw_parameters_create_secure_tcp(NW_PARAMETERS_DISABLE_PROTOCOL,
        NW_PARAMETERS_DEFAULT_CONFIGURATION);

    nw_connection_t result = nw_connection_create(endpoint, parameters);

    return result;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        self.readyConnections = [NSMutableArray array];
        self.queue = dispatch_queue_create("BonjourConnectionsManager.queue", NULL);
    }
    return self;
}

- (void)startBonjourConnectionWithName:(NSString *)aName type:(NSString *)aType domain:(NSString *)aDomain
    didConnectBlock:(void (^)(void))aDidConnectBlock
{
    nw_connection_t connection = [[self class] newConnectionWithName:aName type:aType domain:aDomain];
    [self startConnection:connection didConnectBlock:aDidConnectBlock];
}

- (void)startConnection:(nw_connection_t)aConnection
    didConnectBlock:(void (^)(void))aDidConnectBlock
{
    nw_connection_set_queue(aConnection, _queue);

    nw_connection_set_state_changed_handler(aConnection,
        ^(nw_connection_state_t state, nw_error_t  _Nullable error)
        {
            if (error)
            {
                CFErrorRef errorRef = nw_error_copy_cf_error(error);
                if (NULL != errorRef)
                {
                    NSError *err = CFBridgingRelease(errorRef);
//                    NSString *errorDescr = CFBridgingRelease(errDescrRef);
                    [self logOutside:@"Connection error: %@", err];
                }
                if ([self.readyConnections containsObject:aConnection])
                {
                    [self.readyConnections removeObject:aConnection];
                }
                if (nil != self.connectionCanceledBlock)
                {
                    self.connectionCanceledBlock();
                }
                return;
            }

            if (state == nw_connection_state_ready)
            {
                [self.readyConnections addObject:aConnection];
                if (aDidConnectBlock)
                {
                    aDidConnectBlock();
                }
            }
        });

    nw_connection_start(aConnection);
}

#pragma mark -

- (void)sendData:(dispatch_data_t)aData
    withSendCompletionBlock:(void (^)(NSError *error))aSendCompletionBlock
{
    [self.readyConnections enumerateObjectsUsingBlock:
        ^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop)
        {
            nw_connection_t connection = (nw_connection_t)obj;
            nw_connection_send(connection, aData, NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, true,
                ^(nw_error_t  _Nullable error)
                {
                    NSError *err = nil;
                    if (error)
                    {
                        CFErrorRef errRef = nw_error_copy_cf_error(error);
                        if (NULL != errRef)
                        {
                            err = CFBridgingRelease(errRef);
                        }
                    }
                    if (aSendCompletionBlock)
                    {
                        aSendCompletionBlock(err);
                    }
                });
        }];

}

- (void)sendString:(NSString *)aString
    withSendCompletionBlock:(void (^)(NSInteger errorCode))aSendCompletionBlock
{

}

#pragma mark -

- (void)logOutside:(NSString *)aLogMessage, ...
{
    if (self.logBlock)
    {
        NSString *message = nil;
        va_list args;
        va_start(args, aLogMessage);
        message = [[NSString alloc] initWithFormat:aLogMessage arguments:args];
        va_end(args);
        self.logBlock(message);
    }
}

@end
