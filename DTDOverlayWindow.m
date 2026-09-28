#import "DTDOverlayWindow.h"
#import "DTDFloatingDotView.h"

@implementation DTDOverlayWindow

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.passThroughAllTouches || self.floatingDot.hidden || self.floatingDot.alpha <= 0.01) {
        return nil;
    }

    CGPoint dotPoint = [self convertPoint:point toView:self.floatingDot];
    UIView *hit = [self.floatingDot hitTest:dotPoint withEvent:event];
    return hit;
}

@end
