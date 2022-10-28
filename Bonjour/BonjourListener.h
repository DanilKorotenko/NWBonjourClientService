//
//  BonjourListener.h
//  NWBonjourService
//
//  Created by Danil Korotenko on 10/28/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol BonjourListenerDelegate <NSObject>

@required

- (void)advertisedEndpointChanged:(NSString *)message;
- (void)dataReceived:(NSData *)aData;

@end

@interface BonjourListener : NSObject

+ (instancetype)createAndStartWithName:(NSString *)aName type:(NSString *)aType domain:(NSString *)aDomain;

- (instancetype)initWithName:(NSString *)aName type:(NSString *)aType domain:(NSString *)aDomain;

@property(weak) id<BonjourListenerDelegate> delegate;

- (BOOL)start;

@end

NS_ASSUME_NONNULL_END
