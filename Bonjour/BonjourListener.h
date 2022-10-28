//
//  BonjourListener.h
//  NWBonjourService
//
//  Created by Danil Korotenko on 10/28/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BonjourListener : NSObject

+ (instancetype)createAndStartWithName:(NSString *)aName type:(NSString *)aType domain:(NSString *)aDomain;

@end

NS_ASSUME_NONNULL_END
