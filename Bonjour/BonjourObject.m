//
//  BonjourObject.m
//  NWBonjourClientService
//
//  Created by Danil Korotenko on 11/1/22.
//

#import "BonjourObject.h"

@implementation BonjourObject
{
    void (^_logBlock)(NSString *aLogMessage);
    void (^_stringReceivedBlock)(NSString *aStringReceivedMessage);
}

- (void)dealloc
{
    _logBlock = nil;
    _stringReceivedBlock = nil;
}

- (void)setLogBlock:(void (^)(NSString *aLogMessage))aLogBlock
{
    _logBlock = aLogBlock;
}

- (void)logOutside:(NSString *)aLogMessage, ...
{
    if (_logBlock)
    {
        NSString *message = nil;
        va_list args;
        va_start(args, aLogMessage);
        message = [[NSString alloc] initWithFormat:aLogMessage arguments:args];
        va_end(args);
        _logBlock(message);
    }
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
