#import "DTDFloatingDotView.h"

@implementation DTDFloatingDotView {
    CGPoint _dragOffset;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.backgroundColor = [UIColor colorWithRed:0.08 green:0.55 blue:1.0 alpha:0.45];
    self.layer.shadowColor = UIColor.blackColor.CGColor;
    self.layer.shadowOpacity = 0.15;
    self.layer.shadowRadius = 5.0;
    self.layer.shadowOffset = CGSizeMake(0, 2);
    self.userInteractionEnabled = YES;

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    tap.numberOfTapsRequired = 1;

    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = 1.0;
    longPress.allowableMovement = CGFLOAT_MAX;
    longPress.cancelsTouchesInView = YES;

    [tap requireGestureRecognizerToFail:longPress];
    [self addGestureRecognizer:tap];
    [self addGestureRecognizer:longPress];
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.layer.cornerRadius = CGRectGetWidth(self.bounds) * 0.5;
}

- (void)applySize:(CGFloat)size {
    CGPoint center = self.center;
    self.bounds = CGRectMake(0, 0, size, size);
    self.center = center;
    self.layer.cornerRadius = size * 0.5;
}

- (void)handleTap:(UITapGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateRecognized) {
        [self.delegate floatingDotWasTapped:self];
    }
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    UIView *container = self.superview;
    if (!container) return;

    switch (gesture.state) {
        case UIGestureRecognizerStateBegan: {
            CGPoint location = [gesture locationInView:container];
            _dragOffset = CGPointMake(location.x - self.center.x, location.y - self.center.y);
            [UIView animateWithDuration:0.12 animations:^{
                self.transform = CGAffineTransformMakeScale(1.10, 1.10);
                self.alpha = 0.85;
            }];
            break;
        }
        case UIGestureRecognizerStateChanged: {
            CGPoint location = [gesture locationInView:container];
            CGFloat halfW = CGRectGetWidth(self.bounds) * 0.5;
            CGFloat halfH = CGRectGetHeight(self.bounds) * 0.5;
            CGFloat proposedX = location.x - _dragOffset.x;
            CGFloat proposedY = location.y - _dragOffset.y;
            CGFloat x = MAX(halfW, MIN(CGRectGetWidth(container.bounds) - halfW, proposedX));
            CGFloat y = MAX(halfH, MIN(CGRectGetHeight(container.bounds) - halfH, proposedY));
            self.center = CGPointMake(x, y);
            [self.delegate floatingDot:self didMoveToCenter:self.center ended:NO];
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed: {
            [UIView animateWithDuration:0.12 animations:^{
                self.transform = CGAffineTransformIdentity;
                self.alpha = 1.0;
            }];
            [self.delegate floatingDot:self didMoveToCenter:self.center ended:YES];
            break;
        }
        default:
            break;
    }
}

@end
