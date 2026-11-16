ARCHS = arm64
TARGET = iphone:clang:latest:15.0

THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Chess

Chess_FILES      = Tweak.xm engine.mm
Chess_FRAMEWORKS = UIKit Foundation QuartzCore
Chess_LIBRARIES  = substrate
Chess_CFLAGS     = -fobjc-arc -Wno-deprecated-declarations -Imidnight/src -std=c++20
Chess_LDFLAGS    = midnight/lib/libmidnight.a -lc++ -framework CoreFoundation

include $(THEOS)/makefiles/tweak.mk
