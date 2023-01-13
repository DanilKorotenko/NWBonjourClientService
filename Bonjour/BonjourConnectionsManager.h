//
//  BonjourConnectionsManager.h
//  NWBonjourClientService
//
//  Created by Danil Korotenko on 1/13/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BonjourConnectionsManager : NSObject

@property (strong) void (^logBlock)(NSString *aLogMessage);
@property (strong) void (^stringReceivedBlock)(NSString *aStringReceived);
@property (strong) void (^connectionCanceledBlock)(void);

//+ (BonjourConnectionsManager *)sharedManager;

- (void)startBonjourConnectionWithName:(NSString *)aName type:(NSString *)aType
    domain:(NSString *)aDomain didConnectBlock:(void (^)(void))aDidConnectBlock;

- (void)sendData:(dispatch_data_t)aData
    withSendCompletionBlock:(void (^)(NSError *error))aSendCompletionBlock;
- (void)sendString:(NSString *)aString
    withSendCompletionBlock:(void (^)(NSInteger errorCode))aSendCompletionBlock;


@end

NS_ASSUME_NONNULL_END
