//
//  AppDelegate.m
//  BonjourClientApp
//
//  Created by Danil Korotenko on 11/1/22.
//

#import "AppDelegate.h"
#import "BonjourConnection.h"

@interface AppDelegate ()

@property (strong) IBOutlet NSWindow *window;

@property (strong) IBOutlet NSTextField *serviceUPYes;
@property (strong) IBOutlet NSTextField *serviceUPNo;

@property (strong) IBOutlet NSTextField *clientConnectedYes;
@property (strong) IBOutlet NSTextField *clientConnectedNo;

@property (strong) IBOutlet NSTextView *clientLog;
@property (strong) IBOutlet NSTextField *inputField;

@property (strong) BonjourConnection *connection;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self setupConnection];
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app
{
    return YES;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}

#pragma mark -

- (IBAction)sendToClient:(id)sender
{
    NSString *textToSend = self.inputField.stringValue;

    [self.connection send:textToSend];

    self.inputField.stringValue = @"";
}

#pragma mark -

- (void)appendToLog:(NSString *)aString
{
    NSMutableString *log = [NSMutableString stringWithString:self.clientLog.string];
    [log appendString:aString];
    [log appendString:@"\n"];
    self.clientLog.string = log;
}

- (void)setupConnection
{
    self.connection = [[BonjourConnection alloc] initWithName:
        @"danilkorotenko.hellobonjour" type:@"_exampleService._tcp" domain:@"local"];

    if (self.connection == nil)
    {
        return;
    }

    __weak typeof(self) weakSelf = self;

    [self.connection setLogBlock:
        ^(NSString * _Nonnull aLogMessage)
        {
            [weakSelf performSelectorOnMainThread:@selector(appendToLog:)
                withObject:aLogMessage waitUntilDone:NO];
        }];
    [self.connection setStringReceivedBlock:
        ^(NSString * _Nonnull aStringReceived)
        {
            [weakSelf performSelectorOnMainThread:@selector(appendToLog:)
                withObject:aStringReceived waitUntilDone:NO];
        }];
    [self.connection setConnectionCanceledBlock:
        ^{
            [weakSelf setupConnection];
        }];
    [self.connection start];
}

@end
