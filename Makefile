ARCHS = arm64
TARGET = iphone:clang:latest:15.0

THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Chess

Chess_FILES      = Tweak.xm engine.mm
Chess_FRAMEWORKS = UIKit Foundation QuartzCore
Chess_LIBRARIES  = substrate rodent
Chess_CFLAGS     = -fobjc-arc -Wno-deprecated-declarations -std=c++17
Chess_LDFLAGS    = -Lrodent -lrodent -lc++ -framework CoreFoundation -framework Security

# embed the Rodent NNUE net + Nimzowitsch book into the dylib
# (files staged at the repo root by CI: rodent_net.bin, rodent_book.bin)
ifneq ($(wildcard rodent_net.bin),)
Chess_LDFLAGS    += -Wl,-sectcreate,__TEXT,__rodent_net,rodent_net.bin
Chess_LDFLAGS    += -Wl,-sectcreate,__TEXT,__rodent_book,rodent_book.bin
endif

include $(THEOS)/makefiles/tweak.mk
