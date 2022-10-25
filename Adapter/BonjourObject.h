//
//  BonjourObject.h
//  NWBonjourService
//
//  Created by Danil Korotenko on 10/25/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BonjourObject : NSObject

@property(class, readonly) NSString *defaultType;
@property(class, readonly) NSString *localDomain;

- (void)setLogBlock:(void (^)(const char * _Nonnull aLogMessage))aLogBlock;

- (void)logOutside:(NSString *)aLogMessage;

@end

NS_ASSUME_NONNULL_END
