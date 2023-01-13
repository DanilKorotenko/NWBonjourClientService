
#import <Foundation/Foundation.h>
#import "BonjourObject.h"
#import <Network/Network.h>

NS_ASSUME_NONNULL_BEGIN

@interface BonjourConnection : BonjourObject

- (instancetype)initWithName:(NSString *)aName type:(NSString *)aType domain:(NSString *)aDomain;
- (instancetype)initWithConnection:(nw_connection_t)aConnection;

- (void)start;
- (void)startWithDidConnectBlock:(void (^)(void))aDidConnectBlock;
- (void)cancel;

// For tests
- (void)startSendFromStdIn;
///////

- (void)sendDataWithRegularCompletion:(dispatch_data_t)aDataToSend;
- (void)sendStringWithRegularCompletion:(NSString *)aStringToSend;

- (void)sendData:(dispatch_data_t)aDataToSend sendCompletion:(nw_connection_send_completion_t)aSendCompletion;
- (void)sendString:(NSString *)aStringToSend sendCompletion:(nw_connection_send_completion_t)aSendCompletion;

- (void)setConnectionCanceledBlock:(void (^)(BonjourConnection *aConnection))aConnectionCanceledBlock;
- (void)setDidConnectBlock:(void (^)(void))aDidConnectBlock;

@end

NS_ASSUME_NONNULL_END
