#import "FlutterKinSdkPlugin.h"
#import <flutter_kin_sdk/flutter_kin_sdk-Swift.h>

@implementation FlutterKinSdkPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterKinSdkPlugin registerWithRegistrar:registrar];
}
@end
