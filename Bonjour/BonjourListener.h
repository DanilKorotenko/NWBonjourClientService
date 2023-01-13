
#import <Foundation/Foundation.h>
#import "BonjourObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface BonjourListener : NSObject

//[@property (strong) void (^logBlock)(NSString *aLogMessage);
//@property (strong) void (^stringReceivedBlock)(NSString *aStringReceivedMessage);

- (instancetype)initWithName:(NSString *)aName type:(NSString *)aType domain:(NSString *)aDomain;

- (BOOL)start;
- (void)stop;

//- (void)startSendFromStdIn;
//- (void)send:(NSString *)aStringToSend;

- (void)setLogBlock:(void (^)(NSString *aLogMessage))aLogBlock;
- (void)setStringReceivedBlock:(void (^)(NSString *aStringReceived))aStringReceivedBlock;

@end

NS_ASSUME_NONNULL_END
