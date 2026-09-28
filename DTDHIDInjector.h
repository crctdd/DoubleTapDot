#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@interface DTDHIDInjector : NSObject
+ (instancetype)shared;
@property (nonatomic, readonly, getter=isAvailable) BOOL available;
- (void)doubleTapAtNormalizedPoint:(CGPoint)point intervalMs:(NSUInteger)intervalMs completion:(dispatch_block_t)completion;
@end
