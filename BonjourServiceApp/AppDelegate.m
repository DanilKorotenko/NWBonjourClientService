//
//  AppDelegate.m
//  BonjourServiceApp
//
//  Created by Danil Korotenko on 10/28/22.
//

#import "AppDelegate.h"
#import "BonjourListener.h"

@interface AppDelegate ()

@property (strong) IBOutlet NSWindow *window;

@property (strong) IBOutlet NSTextField *serviceUPYes;
@property (strong) IBOutlet NSTextField *serviceUPNo;

@property (strong) IBOutlet NSTextField *clientConnectedYes;
@property (strong) IBOutlet NSTextField *clientConnectedNo;

@property (strong) IBOutlet NSTextView *clientLog;
@property (strong) IBOutlet NSTextField *inputField;

@property (strong) BonjourListener *listener;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.listener = [[BonjourListener alloc] initWithName:@"danilkorotenko.hellobonjour"
        type:@"_exampleService._tcp" domain:@"local"];

    __weak typeof(self) weakSelf = self;

    [self.listener setLogBlock:
        ^(NSString * _Nonnull aLogMessage)
        {
            [weakSelf performSelectorOnMainThread:@selector(appendToLog:)
                withObject:aLogMessage waitUntilDone:NO];
        }];
    [self.listener setStringReceivedBlock:
        ^(NSString * _Nonnull aStringReceived)
        {
            [weakSelf performSelectorOnMainThread:@selector(appendToLog:)
                withObject:aStringReceived waitUntilDone:NO];
        }];

    [self.listener start];
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app
{
    return YES;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    NSLog(@"App will terminate");
}

#pragma mark -

- (IBAction)sendToClient:(id)sender
{
    NSString *textToSend = self.inputField.stringValue;

    [self.listener send:textToSend];

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

@end
