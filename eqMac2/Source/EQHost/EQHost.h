#import "Devices.h"
#import "EQEngine.h"
#import "Utilities.h"

@interface EQHost : NSObject

+(void)createEQEngineWithOutputDevice:(AudioDeviceID)output;
+(void)deleteEQEngine;
+(BOOL)EQEngineExists;
+(AudioDeviceID)getSelectedOutputDeviceID;
@end
