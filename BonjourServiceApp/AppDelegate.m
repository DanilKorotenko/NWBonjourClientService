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

@property (strong) IBOutlet NSTextField *clientLog;
@property (strong) IBOutlet NSTextField *inputField;

@property (strong) BonjourListener *listener;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.listener = [[BonjourListener alloc] initWithName:@"danilkorotenko.hellobonjour"
        type:@"_exampleService._tcp" domain:@"local"];

    self.listener.delegate = self;

    [self.listener start];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{

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

    self.inputField.stringValue = @"";
}

#pragma mark -

@end
