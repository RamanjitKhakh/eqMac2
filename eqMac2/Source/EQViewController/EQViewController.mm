//
//  EQViewController.m
//  eqMac2
//
//  Created by Romans Kisils on 10/12/2016.
//  Copyright © 2016 bitgapp. All rights reserved.
//

#import "EQViewController.h"

@interface EQViewController ()

@property (strong) IBOutlet NSButton *deleteButton;
@property (strong) IBOutlet NSPopUpButton *presetsPopup;
@property (strong) IBOutlet NSButton *saveButton;

@property (strong) IBOutlet NSView *bandFrequencyLabelsView;
@property (strong) IBOutlet NSView *mockSliderView;
@property (strong) IBOutlet NSView *bandGainLabelsView;
@property (strong) IBOutlet NSPopUpButton *outputPopup;
@property (strong) IBOutlet NSButton *bandModeButton;

@property (strong) IBOutlet NSImageView *speakerIcon;
@property (strong) IBOutlet NSSlider *volumeSlider;
@property (strong) IBOutlet NSImageView *volumeBars;

@property (strong) IBOutlet NSView *optionsView;

@property (strong) IBOutlet NSView *settingsView;
@property (strong) IBOutlet NSButton *launchOnStartupCheckbox;
@property (strong) IBOutlet NSButton *showDefaultPresetsCheckbox;
@property (strong) IBOutlet NSTextField *buildLabel;

@end

NSNotificationCenter *notify;
NSArray *outputDevices;
NSNumber *bandMode;
CGFloat originalWidth;
CGFloat originalHeight;

@implementation EQViewController

-(void)viewDidLoad {
    [super viewDidLoad];
    
    originalWidth = self.view.frame.size.width;
    originalHeight = self.view.frame.size.height;
    
    [_presetsPopup setTitle:@""];
    [_outputPopup setTitle:@""];
    
    notify = [NSNotificationCenter defaultCenter];
    [notify addObserver:self selector:@selector(populateOutputPopup) name:@"devicesChanged" object:nil];
   
    [notify addObserver:self selector:@selector(readjustView) name:@"popoverWillOpen" object:nil];
    
    [_buildLabel setStringValue:[@"Build " stringByAppendingString:[Utilities getAppVersion]]];
    
    bandMode = [Storage getSelectedBandMode];
    
    [_showDefaultPresetsCheckbox setState: [Storage getShowDefaultPresets] ? NSOnState : NSOffState];
    
    [self setBandModeSettings];
    [self readjustView];
    [self populatePresetPopup];
    [self populateOutputPopup];
    
}

-(void)viewDidAppear{
    [self populateOutputPopup];
    [_deleteButton setImage:[Utilities isDarkMode] ? [NSImage imageNamed:@"deleteLight.png"] : [NSImage imageNamed:@"deleteDark.png"]];
    [_saveButton setImage:[Utilities isDarkMode] ? [NSImage imageNamed:@"saveLight.png"] : [NSImage imageNamed:@"saveDark.png"]];
    [_speakerIcon setImage:[Utilities isDarkMode] ? [NSImage imageNamed:@"speakerLight.png"] : [NSImage imageNamed:@"speakerDark.png"]];
    
    [_launchOnStartupCheckbox setState: [Utilities launchOnLogin] ? NSOnState : NSOffState];
    
    [Utilities executeBlock:^{
        [self setState];
    } after:.1];
}

-(void)populatePresetPopup{
    [_presetsPopup removeAllItems];
    NSArray *presets = [Storage getPresetsNames];
    [_presetsPopup addItemsWithTitles: [Utilities orderedStringArrayFromStringArray: presets]];
    [_presetsPopup setTitle: [Storage getSelectedPresetName]];
}

-(void)setState{
    NSLog(@"setState");
    [_presetsPopup setTitle: [Storage getSelectedPresetName]];
    NSArray *selectedGains = [Storage getSelectedGains];
    [EQHost setEQEngineFrequencyGains: selectedGains];
}


-(void)populateOutputPopup{
    [_outputPopup removeAllItems];
    outputDevices = [Devices getAllUsableDevices];
    NSMutableArray *outputDeviceNames = [[NSMutableArray alloc] init];
    for (NSDictionary *device in outputDevices) {
        [outputDeviceNames addObject: [device objectForKey:@"name"]];
    }
    [_outputPopup addItemsWithTitles: [Utilities orderedStringArrayFromStringArray: outputDeviceNames]];
    AudioDeviceID selectedDeviceID = [EQHost EQEngineExists] ? [EQHost getSelectedOutputDeviceID] : [Devices getCurrentDeviceID];
    NSString *nameOfSelectedDevice = [Devices getDeviceNameByID: selectedDeviceID];
    [_outputPopup selectItemWithTitle: nameOfSelectedDevice];
}

- (IBAction)changeOutputDevice:(id)sender {
    AudioDeviceID selectedOutputDevice = [EQHost getSelectedOutputDeviceID];
    for (NSDictionary *device in outputDevices) {
        if ([[device objectForKey:@"name"] isEqualToString: [_outputPopup titleOfSelectedItem]]) {
            selectedOutputDevice = [[device objectForKey:@"id"] intValue];
        }
    }
    [Devices setOutputVolumeForDeviceID: selectedOutputDevice to: [Devices getOutputVolumeForDeviceID:[Devices getEQMacDeviceID]]];
    [Devices switchToOutputDeviceWithID: selectedOutputDevice];
}

-(void)setBandModeSettings{
    [_showDefaultPresetsCheckbox setEnabled: [bandMode intValue] == 10];
}

-(void)readjustView{
    
    CGFloat width = [bandMode intValue] == 10 ? originalWidth : originalWidth * 2;
    CGFloat height = [bandMode intValue] == 10 ? originalHeight : 338;
    
    [self.view setFrame: NSMakeRect(self.view.frame.origin.x, self.view.frame.origin.y, width, height)];
    [notify postNotificationName:@"readjustPopover" object:nil];
}


- (IBAction)changeLaunchOnStartup:(NSButton*)sender {
    [Utilities setLaunchOnLogin:[sender state] == NSOnState ? true : false];
}

- (IBAction)quitApplication:(id)sender {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"closeApp" object:nil];
}

- (IBAction)uninstallApplication:(id)sender {
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

@end
