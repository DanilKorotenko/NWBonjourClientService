//
//  BonjourObject.m
//  NWBonjourClientService
//
//  Created by Danil Korotenko on 11/1/22.
//

#import "BonjourObject.h"

static void (^LogBlock)(NSString *aLogMessage);

@implementation BonjourObject
{
    void (^_stringReceivedBlock)(NSString *aStringReceivedMessage);
}

+ (void)setLogBlock:(void (^)(NSString *aLogMessage))aLogBlock
{
    LogBlock = aLogBlock;
}

+ (void)logOutside:(NSString *)aLogMessage, ...
{
    if (LogBlock)
    {
        NSString *message = nil;
        va_list args;
        va_start(args, aLogMessage);
        message = [[NSString alloc] initWithFormat:aLogMessage arguments:args];
        va_end(args);
        LogBlock(message);
    }
}

- (void)dealloc
{
    _stringReceivedBlock = nil;
}

- (void)setStringReceivedBlock:(void (^)(NSString *aStringReceived))aStringReceivedBlock
{
    _stringReceivedBlock = aStringReceivedBlock;
}

- (void)stringReceived:(NSString *)aStringReceived
{
    if (_stringReceivedBlock)
    {
        _stringReceivedBlock(aStringReceived);
    }
}

@end
