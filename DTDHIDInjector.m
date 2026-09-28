#import "DTDHIDInjector.h"
#import <mach/mach_time.h>
#import <dlfcn.h>

#ifdef __LP64__
typedef double DTDIOHIDFloat;
#else
typedef float DTDIOHIDFloat;
#endif

typedef uint32_t DTDIOOptionBits;
typedef uint32_t DTDIOHIDEventField;
typedef struct __IOHIDEvent *DTDIOHIDEventRef;
typedef struct __IOHIDEventSystemClient *DTDIOHIDEventSystemClientRef;

typedef DTDIOHIDEventRef (*DTDCreateDigitizerEventFn)(CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, DTDIOHIDFloat, DTDIOHIDFloat, DTDIOHIDFloat, DTDIOHIDFloat, DTDIOHIDFloat, Boolean, Boolean, DTDIOOptionBits);
typedef DTDIOHIDEventRef (*DTDCreateFingerEventFn)(CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t, DTDIOHIDFloat, DTDIOHIDFloat, DTDIOHIDFloat, DTDIOHIDFloat, DTDIOHIDFloat, Boolean, Boolean, DTDIOOptionBits);
typedef DTDIOHIDEventSystemClientRef (*DTDCreateClientFn)(CFAllocatorRef);
typedef void (*DTDDispatchEventFn)(DTDIOHIDEventSystemClientRef, DTDIOHIDEventRef);
typedef void (*DTDAppendEventFn)(DTDIOHIDEventRef, DTDIOHIDEventRef, DTDIOOptionBits);
typedef void (*DTDSetIntegerFn)(DTDIOHIDEventRef, DTDIOHIDEventField, CFIndex);
typedef void (*DTDSetSenderIDFn)(DTDIOHIDEventRef, uint64_t);

static const uint32_t DTDTransducerHand = 3;
static const uint32_t DTDEventRange = 1u << 0;
static const uint32_t DTDEventTouch = 1u << 1;
static const uint32_t DTDEventPosition = 1u << 2;
static const uint32_t DTDEventIdentity = 1u << 5;
static const DTDIOHIDEventField DTDFieldDigitizerIsDisplayIntegrated = 0xB0019;
static const uint64_t DTDDigitizerSenderID = 0x8000000817319375ULL;

@interface DTDHIDInjector ()
@property (nonatomic, readwrite, getter=isAvailable) BOOL available;
@end

@implementation DTDHIDInjector {
    void *_ioKitHandle;
    DTDIOHIDEventSystemClientRef _client;
    DTDCreateDigitizerEventFn _createDigitizerEvent;
    DTDCreateFingerEventFn _createFingerEvent;
    DTDCreateClientFn _createClient;
    DTDDispatchEventFn _dispatchEvent;
    DTDAppendEventFn _appendEvent;
    DTDSetIntegerFn _setInteger;
    DTDSetSenderIDFn _setSenderID;
    dispatch_queue_t _queue;
}

+ (instancetype)shared {
    static DTDHIDInjector *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [DTDHIDInjector new];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (!self) return nil;

    _queue = dispatch_queue_create("com.crctdd.doubletapdot.hid", DISPATCH_QUEUE_SERIAL);
    _ioKitHandle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW);
    if (!_ioKitHandle) return self;

    _createDigitizerEvent = (DTDCreateDigitizerEventFn)dlsym(_ioKitHandle, "IOHIDEventCreateDigitizerEvent");
    _createFingerEvent = (DTDCreateFingerEventFn)dlsym(_ioKitHandle, "IOHIDEventCreateDigitizerFingerEvent");
    _createClient = (DTDCreateClientFn)dlsym(_ioKitHandle, "IOHIDEventSystemClientCreate");
    _dispatchEvent = (DTDDispatchEventFn)dlsym(_ioKitHandle, "IOHIDEventSystemClientDispatchEvent");
    _appendEvent = (DTDAppendEventFn)dlsym(_ioKitHandle, "IOHIDEventAppendEvent");
    _setInteger = (DTDSetIntegerFn)dlsym(_ioKitHandle, "IOHIDEventSetIntegerValue");
    _setSenderID = (DTDSetSenderIDFn)dlsym(_ioKitHandle, "IOHIDEventSetSenderID");

    if (_createClient && _createDigitizerEvent && _createFingerEvent && _dispatchEvent && _appendEvent && _setInteger) {
        _client = _createClient(kCFAllocatorDefault);
    }
    self.available = (_client != NULL);
    return self;
}

static void DTDWaitMilliseconds(NSUInteger milliseconds) {
    if (milliseconds == 0) return;
    mach_timebase_info_data_t info;
    mach_timebase_info(&info);
    uint64_t now = mach_absolute_time();
    uint64_t nanos = (uint64_t)milliseconds * 1000000ULL;
    uint64_t ticks = nanos * info.denom / info.numer;
    mach_wait_until(now + ticks);
}

- (void)sendTouchAtPoint:(CGPoint)point down:(BOOL)down {
    if (!self.available) return;

    CGFloat x = MAX(0.0, MIN(1.0, point.x));
    CGFloat y = MAX(0.0, MIN(1.0, point.y));
    uint32_t parentMask = DTDEventRange | DTDEventTouch | DTDEventIdentity | DTDEventPosition;
    uint32_t childMask = DTDEventRange | DTDEventTouch;
    uint64_t timestamp = mach_absolute_time();

    DTDIOHIDEventRef parent = _createDigitizerEvent(kCFAllocatorDefault,
                                                     timestamp,
                                                     DTDTransducerHand,
                                                     1u << 22,
                                                     1,
                                                     parentMask,
                                                     0,
                                                     x,
                                                     y,
                                                     0,
                                                     0,
                                                     0,
                                                     down,
                                                     down,
                                                     0);
    if (!parent) return;

    _setInteger(parent, DTDFieldDigitizerIsDisplayIntegrated, 1);
    if (_setSenderID) _setSenderID(parent, DTDDigitizerSenderID);

    DTDIOHIDEventRef finger = _createFingerEvent(kCFAllocatorDefault,
                                                  timestamp,
                                                  3,
                                                  2,
                                                  childMask,
                                                  x,
                                                  y,
                                                  0,
                                                  down ? 1.0 : 0.0,
                                                  0,
                                                  down,
                                                  down,
                                                  0);
    if (finger) {
        _setInteger(finger, DTDFieldDigitizerIsDisplayIntegrated, 1);
        _appendEvent(parent, finger, 0);
        CFRelease(finger);
    }

    _dispatchEvent(_client, parent);
    CFRelease(parent);
}

- (void)sendSingleTapAtPoint:(CGPoint)point {
    [self sendTouchAtPoint:point down:YES];
    DTDWaitMilliseconds(8);
    [self sendTouchAtPoint:point down:NO];
}

- (void)doubleTapAtNormalizedPoint:(CGPoint)point intervalMs:(NSUInteger)intervalMs completion:(dispatch_block_t)completion {
    NSUInteger clampedInterval = MAX(1, MIN(300, intervalMs));
    dispatch_async(_queue, ^{
        [self sendSingleTapAtPoint:point];
        DTDWaitMilliseconds(clampedInterval);
        [self sendSingleTapAtPoint:point];
        if (completion) dispatch_async(dispatch_get_main_queue(), completion);
    });
}

@end
