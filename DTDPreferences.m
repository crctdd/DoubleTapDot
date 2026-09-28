#import "DTDPreferences.h"
#import <math.h>

NSString * const DTDPrefsDomain = @"com.crctdd.doubletapdot";
NSString * const DTDReloadNotification = @"com.crctdd.doubletapdot/ReloadPrefs";

static id DTDReadValue(NSString *key) {
    return CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)DTDPrefsDomain));
}

static void DTDWriteValue(NSString *key, id value) {
    CFPreferencesSetAppValue((__bridge CFStringRef)key,
                             value ? (__bridge CFPropertyListRef)value : NULL,
                             (__bridge CFStringRef)DTDPrefsDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)DTDPrefsDomain);
}

@interface DTDPreferences ()
@property (nonatomic, readwrite) BOOL enabled;
@property (nonatomic, readwrite) CGFloat dotSize;
@property (nonatomic, readwrite) NSUInteger intervalMs;
@property (nonatomic, readwrite) CGFloat normalizedX;
@property (nonatomic, readwrite) CGFloat normalizedY;
@property (nonatomic, readwrite) BOOL hasSavedPosition;
@end

@implementation DTDPreferences

+ (instancetype)shared {
    static DTDPreferences *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [DTDPreferences new];
        [instance reload];
    });
    return instance;
}

- (void)reload {
    id enabled = DTDReadValue(@"enabled");
    id size = DTDReadValue(@"dotSize");
    id interval = DTDReadValue(@"intervalMs");
    id x = DTDReadValue(@"normalizedX");
    id y = DTDReadValue(@"normalizedY");

    self.enabled = enabled ? [enabled boolValue] : YES;
    self.dotSize = size ? MAX(20.0, MIN(100.0, [size doubleValue])) : 44.0;

    NSInteger intervalValue = interval ? llround([interval doubleValue]) : 30;
    self.intervalMs = (NSUInteger)MAX(1, MIN(300, intervalValue));

    self.hasSavedPosition = (x != nil && y != nil);
    self.normalizedX = x ? MAX(0.0, MIN(1.0, [x doubleValue])) : 0.90;
    self.normalizedY = y ? MAX(0.0, MIN(1.0, [y doubleValue])) : 0.50;
}

- (void)saveNormalizedPosition:(CGPoint)point {
    CGFloat x = MAX(0.0, MIN(1.0, point.x));
    CGFloat y = MAX(0.0, MIN(1.0, point.y));
    DTDWriteValue(@"normalizedX", @(x));
    DTDWriteValue(@"normalizedY", @(y));
    self.normalizedX = x;
    self.normalizedY = y;
    self.hasSavedPosition = YES;
}

- (void)resetPosition {
    DTDWriteValue(@"normalizedX", nil);
    DTDWriteValue(@"normalizedY", nil);
    [self reload];
}

@end
