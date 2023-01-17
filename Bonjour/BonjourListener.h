
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BonjourListener : NSObject

- (instancetype)initWithName:(NSString *)aName type:(NSString *)aType domain:(NSString *)aDomain;

- (BOOL)start;
- (void)stop;

- (void)sendData:(dispatch_data_t)aData
    withSendCompletionBlock:(void (^)(NSError *error))aSendCompletionBlock;
- (void)sendString:(NSString *)aString
    withSendCompletionBlock:(void (^)(NSInteger errorCode))aSendCompletionBlock;

- (void)setLogBlock:(void (^)(NSString *aLogMessage))aLogBlock;
- (void)setStringReceivedBlock:(void (^)(NSString *aStringReceived))aStringReceivedBlock;

@end

NS_ASSUME_NONNULL_END
