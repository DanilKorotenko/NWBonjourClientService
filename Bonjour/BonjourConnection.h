
#import <Foundation/Foundation.h>
#import "BonjourObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface BonjourConnection : BonjourObject

+ (instancetype)createAndStartWithName:(NSString *)aName type:(NSString *)aType
    domain:(NSString *)aDomain;

- (instancetype)initWithName:(NSString *)aName type:(NSString *)aType domain:(NSString *)aDomain;

- (void)start;
- (void)startSendRecieveLoop;

- (void)setConnectionCanceledBlock:(void (^)(void))aConnectionCanceledBlock;
- (void)connectionCanceled;

@end

NS_ASSUME_NONNULL_END
