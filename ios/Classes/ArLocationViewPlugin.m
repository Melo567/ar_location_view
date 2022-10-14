#import "ArLocationViewPlugin.h"
#if __has_include(<ar_location_view/ar_location_view-Swift.h>)
#import <ar_location_view/ar_location_view-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "ar_location_view-Swift.h"
#endif

@implementation ArLocationViewPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftArLocationViewPlugin registerWithRegistrar:registrar];
}
@end
