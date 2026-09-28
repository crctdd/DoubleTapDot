#import <UIKit/UIKit.h>
#import "DTDPreferences.h"
#import "DTDOverlayWindow.h"
#import "DTDFloatingDotView.h"
#import "DTDHIDInjector.h"

@interface DTDOverlayManager : NSObject <DTDFloatingDotViewDelegate>
+ (instancetype)shared;
- (void)start;
- (void)reloadPreferences;
@end

@implementation DTDOverlayManager {
    DTDOverlayWindow *_window;
    DTDFloatingDotView *_dot;
    UIViewController *_rootController;
    BOOL _started;
    BOOL _injecting;
}

+ (instancetype)shared {
    static DTDOverlayManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [DTDOverlayManager new];
    });
    return instance;
}

- (void)start {
    if (_started) return;
    _started = YES;

    CGRect screenBounds = UIScreen.mainScreen.bounds;
    _window = [[DTDOverlayWindow alloc] initWithFrame:screenBounds];
    _window.backgroundColor = UIColor.clearColor;
    _window.windowLevel = UIWindowLevelAlert + 1000.0;
    _window.hidden = NO;

    _rootController = [UIViewController new];
    _rootController.view.backgroundColor = UIColor.clearColor;
    _rootController.view.userInteractionEnabled = YES;
    _window.rootViewController = _rootController;

    DTDPreferences *prefs = DTDPreferences.shared;
    CGFloat size = prefs.dotSize;
    _dot = [[DTDFloatingDotView alloc] initWithFrame:CGRectMake(0, 0, size, size)];
    _dot.delegate = self;
    [_rootController.view addSubview:_dot];
    _window.floatingDot = _dot;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(screenGeometryChanged:)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];

    [self reloadPreferences];
}

- (void)screenGeometryChanged:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_window.frame = UIScreen.mainScreen.bounds;
        [self applySavedPosition];
    });
}

- (CGPoint)defaultCenterForBounds:(CGRect)bounds dotSize:(CGFloat)size {
    CGFloat half = size * 0.5;
    return CGPointMake(CGRectGetWidth(bounds) - half - 16.0, CGRectGetMidY(bounds));
}

- (CGPoint)clampedCenter:(CGPoint)center inBounds:(CGRect)bounds size:(CGFloat)size {
    CGFloat half = size * 0.5;
    CGFloat x = MAX(half, MIN(CGRectGetWidth(bounds) - half, center.x));
    CGFloat y = MAX(half, MIN(CGRectGetHeight(bounds) - half, center.y));
    return CGPointMake(x, y);
}

- (void)applySavedPosition {
    if (!_dot) return;
    CGRect bounds = _rootController.view.bounds;
    DTDPreferences *prefs = DTDPreferences.shared;
    CGPoint center;

    if (prefs.hasSavedPosition) {
        center = CGPointMake(prefs.normalizedX * CGRectGetWidth(bounds),
                             prefs.normalizedY * CGRectGetHeight(bounds));
    } else {
        center = [self defaultCenterForBounds:bounds dotSize:prefs.dotSize];
    }
    _dot.center = [self clampedCenter:center inBounds:bounds size:prefs.dotSize];
}

- (void)reloadPreferences {
    [DTDPreferences.shared reload];
    DTDPreferences *prefs = DTDPreferences.shared;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_dot applySize:prefs.dotSize];
        self->_dot.hidden = !prefs.enabled;
        self->_window.hidden = NO;
        [self applySavedPosition];
    });
}

- (CGPoint)normalizedPointForCenter:(CGPoint)center {
    CGSize size = _rootController.view.bounds.size;
    if (size.width <= 0 || size.height <= 0) return CGPointMake(0.5, 0.5);
    return CGPointMake(center.x / size.width, center.y / size.height);
}

- (void)floatingDot:(DTDFloatingDotView *)dot didMoveToCenter:(CGPoint)center ended:(BOOL)ended {
    if (!ended) return;
    CGPoint normalized = [self normalizedPointForCenter:center];
    [DTDPreferences.shared saveNormalizedPosition:normalized];
}

- (void)floatingDotWasTapped:(DTDFloatingDotView *)dot {
    if (_injecting || !DTDPreferences.shared.enabled) return;
    _injecting = YES;

    CGPoint normalized = [self normalizedPointForCenter:dot.center];
    NSUInteger interval = DTDPreferences.shared.intervalMs;

    _window.passThroughAllTouches = YES;
    dot.hidden = YES;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        [[DTDHIDInjector shared] doubleTapAtNormalizedPoint:normalized intervalMs:interval completion:^{
            self->_window.passThroughAllTouches = NO;
            self->_dot.hidden = !DTDPreferences.shared.enabled;
            self->_injecting = NO;
        }];
    });
}

@end

static void DTDPreferencesChanged(CFNotificationCenterRef center,
                                  void *observer,
                                  CFStringRef name,
                                  const void *object,
                                  CFDictionaryRef userInfo) {
    [[DTDOverlayManager shared] reloadPreferences];
}

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{
        [[DTDOverlayManager shared] start];
    });
}

%end

%ctor {
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                    NULL,
                                    DTDPreferencesChanged,
                                    CFSTR("com.crctdd.doubletapdot/ReloadPrefs"),
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
}
