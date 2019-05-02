#import <Foundation/Foundation.h>
#import "EQHost.h"

@implementation EQHost

static EQEngine *mEngine;
static AudioDeviceID selectedOutputDeviceID;
static NSNumber *bandMode;

+(void)createEQEngineWithOutputDevice:(AudioDeviceID)output{
    BOOL selectedDeviceIsMuted = [Devices getIsMutedForDeviceID: output];
    Float32 stashedVolume = [Devices audioDeviceHasVolumeControls:output] ? [Devices getOutputVolumeForDeviceID: output] : 1;
    [Devices setOutputVolumeForDeviceID:output to: 0]; //silence the output for now
    
    if([self EQEngineExists]) [self deleteEQEngine];
    
    AudioDeviceID input = [Devices getEQMacDeviceID];
    selectedOutputDeviceID = output;
    
    [Devices setOutputVolumeForDeviceID: input to: stashedVolume];
    [Devices setDevice: input toMuted: selectedDeviceIsMuted];

    [Devices switchToOutputDeviceWithID: input];
    [Devices switchToSystemDeviceWithID: input];

    mEngine = new EQEngine(input, output);
    
    bandMode = [Storage getSelectedBandMode];
    NSArray *frequenciesArray = [Constants getFrequenciesForBandMode: bandMode.stringValue];
    UInt32 *frequencies = new UInt32[frequenciesArray.count]();
    for (int i = 0; i < frequenciesArray.count; i++) {
        frequencies[i] = [[[frequenciesArray objectAtIndex: i] objectForKey:@"frequency"] intValue];
    }
    
    mEngine->SetEqFrequencies(frequencies, (UInt32)frequenciesArray.count);
    mEngine->Start();
    
    [Devices setOutputVolumeForDeviceID:output to: 1]; //full blast
}


+(void)deleteEQEngine{
    if(mEngine){
        [Devices setOutputVolumeForDeviceID:[EQHost getSelectedOutputDeviceID] to: 0]; //silence the output for now
        mEngine->Stop();
        BOOL eqMacDeviceIsMuted = [Devices getIsMutedForDeviceID: [Devices getEQMacDeviceID]];
        Float32 volumeToReach = [Devices getOutputVolumeForDeviceID: [Devices getEQMacDeviceID]];
        [Devices switchToOutputDeviceWithID:[EQHost getSelectedOutputDeviceID]];
        [Devices switchToSystemDeviceWithID: [EQHost getSelectedOutputDeviceID]];

        delete mEngine;
        mEngine = NULL;
        [Devices setOutputVolumeForDeviceID: [self getSelectedOutputDeviceID] to: volumeToReach];
        [Devices setDevice: [self getSelectedOutputDeviceID] toMuted: eqMacDeviceIsMuted];
    }
}

+(BOOL)EQEngineExists{
    return (mEngine != NULL) ? true : false;
}


+(AudioDeviceID)getSelectedOutputDeviceID{
    if(selectedOutputDeviceID){
        return selectedOutputDeviceID;
    }
    return 0;
}



@end
