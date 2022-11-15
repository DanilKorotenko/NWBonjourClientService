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
        @"gtb-agent" type:@"_scan4DLPService._tcp" domain:@"local"];

    if (self.connection == nil)
    {
        return;
    }

    [self.connection start];
}

- (void)logOutside:(NSString *)aLogMessage
{
    [self performSelectorOnMainThread:@selector(appendToLog:)
        withObject:aLogMessage waitUntilDone:NO];
}

- (void)stringReceived:(NSString *)aStringReceived
{
    [self performSelectorOnMainThread:@selector(appendToLog:)
        withObject:aStringReceived waitUntilDone:NO];
}

- (void)didCancel
{
    [self setupConnection];
}

@end
