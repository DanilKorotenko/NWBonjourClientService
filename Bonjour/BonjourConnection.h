
#import <Foundation/Foundation.h>
#import "BonjourObject.h"
#import <Network/Network.h>

NS_ASSUME_NONNULL_BEGIN

@interface BonjourConnection : BonjourObject

+ (instancetype)createAndStartWithName:(NSString *)aName type:(NSString *)aType
    domain:(NSString *)aDomain;

- (instancetype)initWithName:(NSString *)aName type:(NSString *)aType domain:(NSString *)aDomain;
- (instancetype)initWithConnection:(nw_connection_t)aConnection;

@property(readonly) BOOL isConnected;

- (void)start;
- (void)startSendFromStdIn;
- (void)cancel;

- (void)send:(NSString *)aStringToSend;

- (void)setConnectionCanceledBlock:(void (^)(void))aConnectionCanceledBlock;
- (void)connectionCanceled;

@end

NS_ASSUME_NONNULL_END
