//
//  BonjourService.h
//  NWBonjourClientService
//
//  Created by Danil Korotenko on 10/25/22.
//

#import <Foundation/Foundation.h>
#import "BonjourConnection.h"
#import "BonjourObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface BonjourService : BonjourObject

- (instancetype)initWithName:(NSString * _Nonnull)aName;

- (void)setNewConnectionBlock:(void (^)(BonjourConnection *aNewConnection))aNewConnectionBlock;

- (BOOL)start;

@end

NS_ASSUME_NONNULL_END
