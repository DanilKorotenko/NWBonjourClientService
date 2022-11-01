//
//  BonjourObject.m
//  NWBonjourClientService
//
//  Created by Danil Korotenko on 11/1/22.
//

#import "BonjourObject.h"

@implementation BonjourObject
{
    void (^_logBlock)(const char *aLogMessage);
    void (^_stringReceivedBlock)(const char *aStringReceivedMessage);
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

- (void)setStringReceivedBlock:(void (^)(const char *aStringReceived))aStringReceivedBlock
{
    _stringReceivedBlock = aStringReceivedBlock;
}

- (void)stringReceived:(NSString *)aStringReceived
{
    if (_stringReceivedBlock)
    {
        _stringReceivedBlock([aStringReceived UTF8String]);
    }
}

@end
