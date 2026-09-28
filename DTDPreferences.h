#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

FOUNDATION_EXPORT NSString * const DTDPrefsDomain;
FOUNDATION_EXPORT NSString * const DTDReloadNotification;

@interface DTDPreferences : NSObject
+ (instancetype)shared;
@property (nonatomic, readonly) BOOL enabled;
@property (nonatomic, readonly) CGFloat dotSize;
@property (nonatomic, readonly) NSUInteger intervalMs;
@property (nonatomic, readonly) CGFloat normalizedX;
@property (nonatomic, readonly) CGFloat normalizedY;
@property (nonatomic, readonly) BOOL hasSavedPosition;
- (void)reload;
- (void)saveNormalizedPosition:(CGPoint)point;
- (void)resetPosition;
@end
