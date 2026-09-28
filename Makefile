ARCHS = arm64 arm64e
TARGET = iphone:clang:16.5:15.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DoubleTapDot
DoubleTapDot_FILES = Tweak.xm DTDPreferences.m DTDOverlayWindow.m DTDFloatingDotView.m DTDHIDInjector.m
DoubleTapDot_FRAMEWORKS = UIKit Foundation
DoubleTapDot_CFLAGS = -fobjc-arc
DoubleTapDot_LDFLAGS = -ldl

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
