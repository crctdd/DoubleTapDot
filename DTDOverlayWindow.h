#import <UIKit/UIKit.h>

@class DTDFloatingDotView;

@interface DTDOverlayWindow : UIWindow
@property (nonatomic, weak) DTDFloatingDotView *floatingDot;
@property (nonatomic) BOOL passThroughAllTouches;
@end
