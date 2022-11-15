
#import <Foundation/Foundation.h>
#import "BonjourObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface BonjourListener : BonjourObject

@property(readwrite) BOOL sendFromStdIn;

- (instancetype)initWithName:(NSString *)aName type:(NSString *)aType domain:(NSString *)aDomain;

- (BOOL)start;
- (void)send:(NSString *)aStringToSend;

@end

NS_ASSUME_NONNULL_END
