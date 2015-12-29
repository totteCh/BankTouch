include $(THEOS)/makefiles/common.mk

ARCHS = arm64

TWEAK_NAME = BankTouch
BankTouch_FILES = Tweak.xm BioServer.mm UICKeyChainStore.m
BankTouch_FRAMEWORKS = Security
BankTouch_PRIVATE_FRAMEWORKS = BiometricKit
include $(THEOS_MAKE_PATH)/tweak.mk

BUNDLE_NAME = net.tottech.banktouch
net.tottech.banktouch_INSTALL_PATH = /Library/Application Support
include $(THEOS_MAKE_PATH)/bundle.mk

after-install::
	install.exec "killall -9 BankID"
