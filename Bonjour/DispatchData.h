//
//  data.h
//  NWBonjourClientService
//
//  Created by Danil Korotenko on 11/17/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DispatchData : NSObject

+ (dispatch_data_t)dispatch_data_from_NSData:(NSData *)aData queue:(dispatch_queue_t)aQueue;
+ (dispatch_data_t)dispatch_data_from_NSString:(NSString *)aString queue:(dispatch_queue_t)aQueue;

@end

NS_ASSUME_NONNULL_END
