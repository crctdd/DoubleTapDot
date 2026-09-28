#import "DTDRootListController.h"
#import <math.h>
#import <Preferences/PSSpecifier.h>
#import <CoreFoundation/CoreFoundation.h>
#import <UIKit/UIKit.h>

static NSString * const DTDPrefsDomain = @"com.crctdd.doubletapdot";
static NSString * const DTDReloadNotification = @"com.crctdd.doubletapdot/ReloadPrefs";

@implementation DTDRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    id value = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key,
                                                            (__bridge CFStringRef)DTDPrefsDomain));
    return value ?: [specifier propertyForKey:@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if ([key isEqualToString:@"intervalMs"]) {
        NSInteger rounded = llround([value doubleValue]);
        value = @(MAX(1, MIN(300, rounded)));
    } else if ([key isEqualToString:@"dotSize"]) {
        double rounded = round([value doubleValue]);
        value = @(MAX(20.0, MIN(100.0, rounded)));
    }

    CFPreferencesSetAppValue((__bridge CFStringRef)key,
                             (__bridge CFPropertyListRef)value,
                             (__bridge CFStringRef)DTDPrefsDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)DTDPrefsDomain);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (__bridge CFStringRef)DTDReloadNotification,
                                         NULL,
                                         NULL,
                                         true);
}

- (void)resetDotPosition {
    CFPreferencesSetAppValue(CFSTR("normalizedX"), NULL, (__bridge CFStringRef)DTDPrefsDomain);
    CFPreferencesSetAppValue(CFSTR("normalizedY"), NULL, (__bridge CFStringRef)DTDPrefsDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)DTDPrefsDomain);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (__bridge CFStringRef)DTDReloadNotification,
                                         NULL,
                                         NULL,
                                         true);

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"已重置"
                                                                   message:@"蓝点位置已恢复为默认位置。"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
