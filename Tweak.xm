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
    UIWindowScene *_windowScene;
    BOOL _observersInstalled;
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

- (UIWindowScene *)foregroundWindowScene {
    UIApplication *application = UIApplication.sharedApplication;
    UIWindowScene *fallback = nil;

    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in application.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;

            UIWindowScene *windowScene = (UIWindowScene *)scene;
            if (!fallback) fallback = windowScene;

            if (scene.activationState == UISceneActivationStateForegroundActive &&
                windowScene.screen == UIScreen.mainScreen) {
                return windowScene;
            }
        }

        for (UIWindow *existingWindow in application.windows) {
            if (existingWindow.windowScene && existingWindow.screen == UIScreen.mainScreen) {
                if (!fallback) fallback = existingWindow.windowScene;
                if (!existingWindow.hidden && existingWindow.alpha > 0.01) {
                    return existingWindow.windowScene;
                }
            }
        }
    }

    return fallback;
}

- (CGRect)boundsForScene:(UIWindowScene *)scene {
    if (scene) {
        CGRect bounds = scene.coordinateSpace.bounds;
        if (!CGRectIsEmpty(bounds)) return bounds;
    }
    return UIScreen.mainScreen.bounds;
}

- (void)destroyOverlay {
    _dot.delegate = nil;
    [_dot removeFromSuperview];
    _dot = nil;

    _window.hidden = YES;
    _window.rootViewController = nil;
    _window = nil;
    _rootController = nil;
    _windowScene = nil;
}

- (BOOL)ensureOverlayVisible {
    NSAssert(NSThread.isMainThread, @"DoubleTapDot overlay must be created on main thread");

    UIWindowScene *scene = [self foregroundWindowScene];
    if (!scene) {
        NSLog(@"[DoubleTapDot] UIWindowScene not ready yet");
        return NO;
    }

    if (_window && _windowScene != scene) {
        [self destroyOverlay];
    }

    if (!_window) {
        CGRect bounds = [self boundsForScene:scene];

        if (@available(iOS 13.0, *)) {
            _window = [[DTDOverlayWindow alloc] initWithWindowScene:scene];
        } else {
            _window = [[DTDOverlayWindow alloc] initWithFrame:bounds];
        }

        _windowScene = scene;
        _window.frame = bounds;
        _window.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _window.backgroundColor = UIColor.clearColor;
        _window.opaque = NO;
        _window.windowLevel = UIWindowLevelAlert + 10000.0;
        _window.userInteractionEnabled = YES;

        _rootController = [UIViewController new];
        _rootController.view.frame = bounds;
        _rootController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _rootController.view.backgroundColor = UIColor.clearColor;
        _rootController.view.userInteractionEnabled = YES;
        _window.rootViewController = _rootController;

        DTDPreferences *prefs = DTDPreferences.shared;
        CGFloat size = prefs.dotSize;
        _dot = [[DTDFloatingDotView alloc] initWithFrame:CGRectMake(0, 0, size, size)];
        _dot.delegate = self;
        [_rootController.view addSubview:_dot];
        _window.floatingDot = _dot;

        _window.hidden = NO;
        _window.alpha = 1.0;

        NSLog(@"[DoubleTapDot] overlay created, scene=%@ bounds=%@",
              scene,
              NSStringFromCGRect(bounds));
    } else {
        _window.hidden = NO;
        _window.alpha = 1.0;
    }

    [self applyCurrentPreferences];
    return YES;
}

- (void)scheduleEnsureAttempt:(NSInteger)attempt {
    if (attempt >= 12) return;

    NSTimeInterval delay = (attempt == 0) ? 0.5 : 1.5;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        BOOL ready = [self ensureOverlayVisible];
        if (!ready) {
            [self scheduleEnsureAttempt:attempt + 1];
        }
    });
}

- (void)start {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self->_observersInstalled) {
            self->_observersInstalled = YES;

            NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
            [center addObserver:self
                       selector:@selector(sceneOrApplicationBecameActive:)
                           name:UIApplicationDidBecomeActiveNotification
                         object:nil];

            if (@available(iOS 13.0, *)) {
                [center addObserver:self
                           selector:@selector(sceneOrApplicationBecameActive:)
                               name:UISceneDidActivateNotification
                             object:nil];
                [center addObserver:self
                           selector:@selector(sceneOrApplicationBecameActive:)
                               name:UISceneWillEnterForegroundNotification
                             object:nil];
            }

            [center addObserver:self
                       selector:@selector(screenGeometryChanged:)
                           name:UIDeviceOrientationDidChangeNotification
                         object:nil];
            [UIDevice.currentDevice beginGeneratingDeviceOrientationNotifications];
        }

        [self ensureOverlayVisible];
        [self scheduleEnsureAttempt:0];
    });
}

- (void)sceneOrApplicationBecameActive:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self ensureOverlayVisible];
    });
}

- (void)screenGeometryChanged:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self->_window) {
            [self ensureOverlayVisible];
            return;
        }

        CGRect bounds = [self boundsForScene:self->_windowScene];
        self->_window.frame = bounds;
        self->_rootController.view.frame = bounds;
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
    if (!_dot || !_rootController) return;

    CGRect bounds = _rootController.view.bounds;
    if (CGRectIsEmpty(bounds)) {
        bounds = [self boundsForScene:_windowScene];
    }

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

- (void)applyCurrentPreferences {
    if (!_dot || !_window) return;

    DTDPreferences *prefs = DTDPreferences.shared;
    [_dot applySize:prefs.dotSize];
    _dot.hidden = !prefs.enabled;
    _window.hidden = NO;
    [self applySavedPosition];
}

- (void)reloadPreferences {
    [DTDPreferences.shared reload];

    dispatch_async(dispatch_get_main_queue(), ^{
        if (![self ensureOverlayVisible]) return;
        [self applyCurrentPreferences];
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

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_MSEC)),
                   dispatch_get_main_queue(), ^{
        [[DTDHIDInjector shared] doubleTapAtNormalizedPoint:normalized
                                                intervalMs:interval
                                                completion:^{
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
    [[DTDOverlayManager shared] start];
}

%end

%ctor {
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                    NULL,
                                    DTDPreferencesChanged,
                                    CFSTR("com.crctdd.doubletapdot/ReloadPrefs"),
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);

    dispatch_async(dispatch_get_main_queue(), ^{
        [[DTDOverlayManager shared] start];
    });
}
