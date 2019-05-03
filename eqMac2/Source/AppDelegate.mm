//
//  AppDelegate.m
//  eqMac2
//
//  Created by Roman on 08/11/2015.
//  Copyright © 2015 bitgapp. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()
@property (strong) NSStatusItem *statusBar;
@end


//Windows
NSPopover *eqPopover;
NSMenu *eqMenu;
NSEvent *eqPopoverTransiencyMonitor;
NSTimer *deviceChangeWatcher;
NSTimer *deviceActivityWatcher;
NSRunningApplication *focusedApplication;

@implementation AppDelegate

#pragma mark Initialization

- (id)init {
    [NSApp activateIgnoringOtherApps:NO];
    [self setupStatusBar];
    return self;
}

-(void)setupStatusBar{
    eqMenu = [[NSMenu alloc] init];
    [eqMenu setDelegate:self];
    
    NSMenuItem *appItem = [[NSMenuItem alloc] init];
    [appItem setTitle: [NSString stringWithFormat:@"Guru Voice: Version %@", [Utilities getAppVersion]]];
    NSMenuItem *uninstall = [[NSMenuItem alloc] init];
    [uninstall setTitle:@"Uninstall"];
    [uninstall setAction:@selector(uninstallApp)];
    
    NSMenuItem *quit = [[NSMenuItem alloc] init];
    [quit setTitle:@"Quit"];
    [quit setAction:@selector(quitApplication)];
    
    [eqMenu addItem: appItem];
    [eqMenu addItem: uninstall];
    [eqMenu addItem: quit];
        
    _statusBar = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    
    [_statusBar setImage:[NSImage imageNamed: [Utilities isDarkMode] ? @"statusItemLight" : @"statusItemDark"]];
    [_statusBar setMenu:eqMenu];
    [_statusBar setHighlightMode:YES];
}

-(void)uninstallApp {
    if([Utilities showAlertWithTitle:@"Uninstall Guru Voice?"
                          andMessage:@"Are you sure about this?"
                          andButtons:@[@"Yes, uninstall",@"No, cancel"]] == NSAlertFirstButtonReturn){
        
        if([Utilities runShellScriptWithName:@"uninstall_driver"]){
            if([EQHost EQEngineExists]) [EQHost deleteEQEngine];
            [Utilities setLaunchOnLogin: NO];
            NSString *helperBundlePath = [[[NSBundle mainBundle] bundlePath] stringByAppendingString:@"/Contents/Resources/eqMac2Helper.app"];
            [Utilities setLaunchOnLogin:NO forBundlePath: helperBundlePath];
            [[NSFileManager defaultManager] removeItemAtPath:[[NSBundle mainBundle] bundlePath] error:nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"closeApp" object:nil];
        }
        
    }
}

-(void)applicationDidFinishLaunching:(NSNotification *)notification{
    NSNotificationCenter *observer = [NSNotificationCenter defaultCenter];
    [observer addObserver:self selector:@selector(quitApplication) name:@"closeApp" object:nil];
    
    [self checkAndInstallDriver];
    [self startHelperIfNeeded];
    
    [Storage load];
    
    [Utilities executeBlock:^{ [Storage save]; } every: 60];
    
    //Send anonymous analytics data to the API
    [API startPinging];
    [self startWatchingDeviceChanges];
    
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(wakeUpFromSleep) name:NSWorkspaceDidWakeNotification object:NULL];
}


-(void)checkAndInstallDriver{
    if(![Devices eqMacDriverInstalled]){
        //Install only the new driver
        switch([Utilities showAlertWithTitle:@"Guru Voice Requires a Driver Update"
                                  andMessage:@"In order to install the driver, the app will ask for your system password."
                                  andButtons:@[@"Install", @"Quit"]]){
            case NSAlertFirstButtonReturn:{
                if([Utilities runShellScriptWithName:@"install_driver"]){
                    [NSThread sleepForTimeInterval: .1];
                    if (![Devices eqMacDriverInstalled]) {
                        [Utilities runAppleScriptWithName:@"open_security_settings"];
                        switch([Utilities showAlertWithTitle:@"Problem installing the Driver"
                                                  andMessage:@"Most likely your Security settings don't allow non-Appstore apps to be installed with drivers.\nWe have openned your System Preferences.\nDown where it says \"Allow apps downloaded from:\"\nTry to switch to \"App Store and identified developers\"\nAnd then try to install the driver again..."
                                                  andButtons:@[@"I changed my settings, try to install again..."]]){
                            case NSAlertFirstButtonReturn: {
                                if([Utilities runShellScriptWithName:@"install_driver"]){
                                    [NSThread sleepForTimeInterval: .1];
                                    if (![Devices eqMacDriverInstalled]) {
                                        switch([Utilities showAlertWithTitle:@"Still a problem installing the Driver"
                                                                  andMessage:@"Please restart your Mac and try to run eqMac2 again.\nIf you have restarted and retried already and it still doesn't work, \nYou can try to resolve the issue by chatting with the developer, or quit Guru Voice now"
                                                                  andButtons:@[@"Chat with the developer", @"Quit Guru Voice"]]){
                                            case NSAlertFirstButtonReturn: {
                                                [Utilities openBrowserWithURL: HELP_URL];
                                            }
                                            default: {
                                                return [self quitApplication];
                                            }
                                        }
                                    } else {
                                        return [self checkAndInstallDriver];
                                    }
                                } else {
                                    return [self checkAndInstallDriver];
                                }
                            }
                            default: {
                                [self quitApplication];
                            }
                        }
                    }
                } else {
                    [self checkAndInstallDriver];
                }
                break;
            }
            default :{
                [self quitApplication];
                break;
            }
        }
    }
}

-(void)startHelperIfNeeded{
    NSString *helperBundlePath = [[[NSBundle mainBundle] bundlePath] stringByAppendingString:@"/Contents/Resources/eqMac2Helper.app"];
    [Utilities setLaunchOnLogin:YES forBundlePath: helperBundlePath];
    if (![Utilities appWithBundleIdentifierIsRunning: HELPER_BUNDLE_IDENTIFIER]) {
        [[NSWorkspace sharedWorkspace] launchApplication: helperBundlePath];
    }
}

-(void)startWatchingDeviceChanges{
    deviceChangeWatcher = [Utilities executeBlock:^{
        AudioDeviceID selectedDeviceID = [Devices getCurrentDeviceID];
        if(selectedDeviceID != [Devices getEQMacDeviceID] && [Devices getIsAliveForDeviceID:selectedDeviceID]){
            [EQHost createEQEngineWithOutputDevice: selectedDeviceID];
            [self startWatchingActivityOfDeviceWithID:selectedDeviceID];
        }
    } every:.1];
}

-(void)startWatchingActivityOfDeviceWithID:(AudioDeviceID)ID{
    deviceActivityWatcher = [Utilities executeBlock:^{
        if(![Devices getIsAliveForDeviceID:ID]){
            [EQHost deleteEQEngine];
            [deviceActivityWatcher invalidate];
            deviceActivityWatcher = nil;
        }
    } every:1];
}

-(void)wakeUpFromSleep{
    [deviceChangeWatcher invalidate];
    deviceChangeWatcher = nil;
    
    [EQHost deleteEQEngine];
    [Devices switchToOutputDeviceWithID:[EQHost getSelectedOutputDeviceID]];
    
    //delay the start a little so os has time to catchup with the Audio Processing
    [Utilities executeBlock:^{
        [self startWatchingDeviceChanges];
    } after:3];
}

- (void)quitApplication{
    [NSApp terminate:nil];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [self tearDownApplication];
}

-(void)tearDownApplication{
    [Storage save];
    [EQHost deleteEQEngine];
}

@end
