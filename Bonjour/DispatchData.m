//
//  data.m
//  NWBonjourClientService
//
//  Created by Danil Korotenko on 11/17/22.
//

#import "DispatchData.h"

@implementation DispatchData

+ (dispatch_data_t)dispatch_data_from_NSData:(NSData *)aData queue:(dispatch_queue_t)aQueue
{
    return dispatch_data_create(aData.bytes, aData.length, aQueue, DISPATCH_DATA_DESTRUCTOR_DEFAULT);
}

+ (dispatch_data_t)dispatch_data_from_NSString:(NSString *)aString queue:(dispatch_queue_t)aQueue
{
    NSData *data = [aString dataUsingEncoding:NSUTF8StringEncoding];
    return [self dispatch_data_from_NSData:data queue:aQueue];
}

@end
