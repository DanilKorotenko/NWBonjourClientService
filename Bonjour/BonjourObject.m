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
    Block_release(_logBlock);
    Block_release(_stringReceivedBlock);
    [super dealloc];
}

- (void)setLogBlock:(void (^)(NSString *aLogMessage))aLogBlock
{
    _logBlock = Block_copy(aLogBlock);
}

- (void)logOutside:(NSString *)aLogMessage
{
    if (_logBlock)
    {
        _logBlock(aLogMessage);
    }
}

- (void)setStringReceivedBlock:(void (^)(NSString *aStringReceived))aStringReceivedBlock
{
    _stringReceivedBlock = Block_copy(aStringReceivedBlock);
}

- (void)stringReceived:(NSString *)aStringReceived
{
    if (_stringReceivedBlock)
    {
        _stringReceivedBlock(aStringReceived);
    }
}

@end
