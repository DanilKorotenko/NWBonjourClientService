
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BonjourListener : NSObject

+ (instancetype)createAndStartWithName:(NSString *)aName type:(NSString *)aType
    domain:(NSString *)aDomain;

- (instancetype)initWithName:(NSString *)aName type:(NSString *)aType domain:(NSString *)aDomain;

- (BOOL)start;

- (void)setLogBlock:(void (^)(const char *aLogMessage))aLogBlock;
- (void)setStringReceivedBlock:(void (^)(const char *aStringReceived))aStringReceivedBlock;

@end

NS_ASSUME_NONNULL_END
