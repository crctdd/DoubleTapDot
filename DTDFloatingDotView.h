#import <UIKit/UIKit.h>

@class DTDFloatingDotView;

@protocol DTDFloatingDotViewDelegate <NSObject>
- (void)floatingDotWasTapped:(DTDFloatingDotView *)dot;
- (void)floatingDot:(DTDFloatingDotView *)dot didMoveToCenter:(CGPoint)center ended:(BOOL)ended;
@end

@interface DTDFloatingDotView : UIView
@property (nonatomic, weak) id<DTDFloatingDotViewDelegate> delegate;
- (void)applySize:(CGFloat)size;
@end
