//
//  BonjourConnection.h
//  NWBonjourService
//
//  Created by Danil Korotenko on 10/25/22.
//

#import <Foundation/Foundation.h>
#import <Network/Network.h>
#import "BonjourObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface BonjourConnection : BonjourObject

- (instancetype)initWithConnection:(nw_connection_t)aConnection;
- (instancetype)initOutboundToBonjourServiceName:(NSString *)aServiceName;

- (void)setIsCompleteBlock:(void (^)(void))anIsCompleteBlock;
- (void)setDataAvaliableBlock:(void (^)(NSData *aData))aDataAvaliableBlock;

- (void)cancel;

- (void)start;

- (void)sendStdInloop;

@end

NS_ASSUME_NONNULL_END
