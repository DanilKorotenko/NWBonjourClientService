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

- (NSString *)getBonjourNameFromEndpoint:(nw_endpoint_t _Nonnull)anEndpoint
{
    return [NSString stringWithFormat:@"%s.%s.%s",
        nw_endpoint_get_bonjour_service_name(anEndpoint),
        self.class.defaultType.UTF8String, self.class.localDomain.UTF8String];
}

@end
