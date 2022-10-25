//
//  BonjourObject.m
//  NWBonjourService
//
//  Created by Danil Korotenko on 10/25/22.
//

#import "BonjourObject.h"

@implementation BonjourObject
{
    void (^_logBlock)(const char *aLogMessage);
}

+ (NSString *)defaultType
{
    return @"_exampleService._tcp";
}

+ (NSString *)localDomain
{
    return @"local";
}


- (void)setLogBlock:(void (^)(const char *aLogMessage))aLogBlock
{
    _logBlock = aLogBlock;
}

- (void)logOutside:(NSString *)aLogMessage
{
    if (_logBlock)
    {
        _logBlock([aLogMessage UTF8String]);
    }
}

@end
