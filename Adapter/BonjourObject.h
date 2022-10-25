//
//  BonjourObject.h
//  NWBonjourService
//
//  Created by Danil Korotenko on 10/25/22.
//

#import <Foundation/Foundation.h>
#import <Network/Network.h>

NS_ASSUME_NONNULL_BEGIN

@interface BonjourObject : NSObject

@property(class, readonly) NSString *defaultType;
@property(class, readonly) NSString *localDomain;
@property(strong) NSString *bonjourServiceName;

- (void)setLogBlock:(void (^)(const char * _Nonnull aLogMessage))aLogBlock;

- (void)logOutside:(NSString *)aLogMessage;

//- (NSString *)getBonjourNameFromEndpoint:(nw_endpoint_t _Nonnull)anEndpoint;

@end

NS_ASSUME_NONNULL_END
