//
//  BonjourObject.h
//  NWBonjourClientService
//
//  Created by Danil Korotenko on 11/1/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BonjourObject : NSObject

+ (void)setLogBlock:(void (^)(NSString *aLogMessage))aLogBlock;
+ (void)logOutside:(NSString *)aLogMessage, ...;

- (void)setStringReceivedBlock:(void (^)(NSString *aStringReceived))aStringReceivedBlock;
- (void)stringReceived:(NSString *)aStringReceived;

@end

NS_ASSUME_NONNULL_END
