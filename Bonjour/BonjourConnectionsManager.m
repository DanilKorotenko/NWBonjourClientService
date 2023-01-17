//
//  BonjourConnectionsManager.m
//  NWBonjourClientService
//
//  Created by Danil Korotenko on 1/13/23.
//

#import "BonjourConnectionsManager.h"

#import <Network/Network.h>

@interface BonjourConnectionsManager ()

@property (strong) NSMutableArray<nw_connection_t> *readyConnections;
@property (strong) dispatch_queue_t queue;

@end

@implementation BonjourConnectionsManager

+ (nw_connection_t)newConnectionWithName:(NSString *)aName type:(NSString *)aType
    domain:(NSString *)aDomain
{
    nw_endpoint_t endpoint =
        nw_endpoint_create_bonjour_service(aName.UTF8String, aType.UTF8String, aDomain.UTF8String);

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
            switch (state)
            {
                case nw_connection_state_invalid:
                case nw_connection_state_waiting:
                case nw_connection_state_preparing:
                {
                    // do nothing
                    break;
                }

                case nw_connection_state_ready:
                {
                    [self.readyConnections addObject:aConnection];
                    [self logOutside:@"Connections: %d", self.readyConnections.count];
                    if (aDidConnectBlock)
                    {
                        aDidConnectBlock();
                    }
                    [self receiveFromConnection:aConnection];
                    break;
                }

                case nw_connection_state_failed:
                case nw_connection_state_cancelled:
                {
                    if (error)
                    {
                        CFErrorRef errorRef = nw_error_copy_cf_error(error);
                        if (NULL != errorRef)
                        {
                            NSError *err = CFBridgingRelease(errorRef);
                            if (err.code != 54) // connection reset by peer
                            {
                                [self logOutside:@"Connection error: %@", err];
                            }
                        }
                    }

                    if ([self.readyConnections containsObject:aConnection])
                    {
                        [self logOutside:@"Connection closed."];
                        [self connectionCancelled:aConnection];
                    }
                    break;
                }
            }
        });

    nw_connection_start(aConnection);
}

#pragma mark -

- (void)sendData:(dispatch_data_t)aData withEnumerator:(NSEnumerator<nw_connection_t> *)anEnumerator
    withSendCompletionBlock:(void (^)(NSError *error))aSendCompletionBlock
{
    nw_connection_t connection = (nw_connection_t)[anEnumerator nextObject];
    if (connection)
    {
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
                        if (aSendCompletionBlock)
                        {
                            aSendCompletionBlock(err);
                        }
                    }
                }
                else
                {
                    [self sendData:aData withEnumerator:anEnumerator
                        withSendCompletionBlock:aSendCompletionBlock];
                }
            });
    }
    else if (aSendCompletionBlock)
    {
        aSendCompletionBlock(nil);
    }
}

- (void)sendData:(dispatch_data_t)aData
    withSendCompletionBlock:(void (^)(NSError *error))aSendCompletionBlock
{
    NSEnumerator<nw_connection_t> *enumerator = [self.readyConnections objectEnumerator];
    [self sendData:aData withEnumerator:enumerator withSendCompletionBlock:aSendCompletionBlock];
}

- (void)sendString:(NSString *)aString
    withSendCompletionBlock:(void (^)(NSInteger errorCode))aSendCompletionBlock
{

}

#pragma mark -

- (void)receiveFromConnection:(nw_connection_t)aConnection
{
    nw_connection_receive(aConnection, 1, UINT32_MAX,
        ^(dispatch_data_t  _Nullable content, nw_content_context_t  _Nullable context,
            bool is_complete, nw_error_t  _Nullable receive_error)
        {
            if (content != NULL)
            {
                NSData *data = [NSData dataWithData:(NSData *)content];
                NSString *stringRecieved = [[NSString alloc] initWithData:data
                    encoding:NSUTF8StringEncoding];
                [self stringReceived:stringRecieved];
            }

            // If the context is marked as complete, and is the final context,
            // we're read-closed.
            if (is_complete &&
                (context == NULL || nw_content_context_get_is_final(context)))
            {
                [self connectionCancelled:aConnection];
            }
            else if (receive_error == NULL)
            {
                // If there was no error in receiving, request more data
                [self receiveFromConnection:aConnection];
            }
        });
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

- (void)stringReceived:(NSString *)aStringReceived
{
    if (nil != self.stringReceivedBlock)
    {
        self.stringReceivedBlock(aStringReceived);
    }
}

- (void)connectionCancelled:(nw_connection_t)aConnection
{
    if ([self.readyConnections containsObject:aConnection])
    {
        [self.readyConnections removeObject:aConnection];
        [self logOutside:@"Connections: %d", self.readyConnections.count];
    }
    else
    {
        [self logOutside:@"Zombie connection!"];
    }
    if (nil != self.connectionCanceledBlock)
    {
        self.connectionCanceledBlock();
    }
}

@end
