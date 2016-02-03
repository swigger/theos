ifeq ($(_THEOS_TARGET_LOADED),)
_THEOS_TARGET_LOADED := 1
THEOS_TARGET_NAME := iphone

_THEOS_TARGET_CC := arm-apple-darwin9-gcc
_THEOS_TARGET_CXX := arm-apple-darwin9-g++
_THEOS_TARGET_ARG_ORDER := 1 2
ifeq ($(__THEOS_TARGET_ARG_1),clang)
_THEOS_TARGET_CC := clang
_THEOS_TARGET_CXX := clang++
_THEOS_TARGET_ARG_ORDER := 2 3
else ifeq ($(__THEOS_TARGET_ARG_1),gcc)
_THEOS_TARGET_ARG_ORDER := 2 3
endif

_SDKVERSION := $(or $(__THEOS_TARGET_ARG_$(word 1,$(_THEOS_TARGET_ARG_ORDER))),$(SDKVERSION))
_THEOS_TARGET_SDK_VERSION := $(or $(_SDKVERSION),latest)

_SDK_DIR := $(THEOS)/sdks
_IOS_SDKS := $(sort $(patsubst $(_SDK_DIR)/iPhoneOS%.sdk,%,$(wildcard $(_SDK_DIR)/iPhoneOS*.sdk)))
ifeq ($(words $(_IOS_SDKS)),0)
before-all::
	@$(PRINT_FORMAT_ERROR) "You do not have an SDK in $(_SDK_DIR)." >&2
endif
_LATEST_SDK := $(lastword $(_IOS_SDKS))

ifeq ($(_THEOS_TARGET_SDK_VERSION),latest)
override _THEOS_TARGET_SDK_VERSION := $(_LATEST_SDK)
endif

# We have to figure out the target version here, as we need it in the calculation of the deployment version.
_TARGET_VERSION_GE_8_4 = $(call __simplify,_TARGET_VERSION_GE_8_4,$(shell $(THEOS_BIN_PATH)/vercmp.pl $(_THEOS_TARGET_SDK_VERSION) ge 8.4))
_TARGET_VERSION_GE_7_0 = $(call __simplify,_TARGET_VERSION_GE_7_0,$(shell $(THEOS_BIN_PATH)/vercmp.pl $(_THEOS_TARGET_SDK_VERSION) ge 7.0))
_TARGET_VERSION_GE_6_0 = $(call __simplify,_TARGET_VERSION_GE_6_0,$(shell $(THEOS_BIN_PATH)/vercmp.pl $(_THEOS_TARGET_SDK_VERSION) ge 6.0))
_TARGET_VERSION_GE_4_0 = $(call __simplify,_TARGET_VERSION_GE_4_0,$(shell $(THEOS_BIN_PATH)/vercmp.pl $(_THEOS_TARGET_SDK_VERSION) ge 4.0))
_TARGET_VERSION_GE_3_0 = $(call __simplify,_TARGET_VERSION_GE_3_0,$(shell $(THEOS_BIN_PATH)/vercmp.pl $(_THEOS_TARGET_SDK_VERSION) ge 3.0))

ifeq ($(_TARGET_VERSION_GE_7_0),1)
_THEOS_TARGET_DEFAULT_IPHONEOS_DEPLOYMENT_VERSION := 5.0
else
ifeq ($(_TARGET_VERSION_GE_6_0),1)
_THEOS_TARGET_DEFAULT_IPHONEOS_DEPLOYMENT_VERSION := 4.3
else
_THEOS_TARGET_DEFAULT_IPHONEOS_DEPLOYMENT_VERSION := 3.0
endif
endif

_THEOS_TARGET_IPHONEOS_DEPLOYMENT_VERSION := $(or $(__THEOS_TARGET_ARG_$(word 2,$(_THEOS_TARGET_ARG_ORDER))),$(TARGET_IPHONEOS_DEPLOYMENT_VERSION),$(_SDKVERSION),$(_THEOS_TARGET_DEFAULT_IPHONEOS_DEPLOYMENT_VERSION))

ifeq ($(_THEOS_TARGET_IPHONEOS_DEPLOYMENT_VERSION),latest)
override _THEOS_TARGET_IPHONEOS_DEPLOYMENT_VERSION := $(_LATEST_SDK)
endif

_DEPLOY_VERSION_GE_3_0 = $(call __simplify,_DEPLOY_VERSION_GE_3_0,$(shell $(THEOS_BIN_PATH)/vercmp.pl $(_THEOS_TARGET_IPHONEOS_DEPLOYMENT_VERSION) ge 3.0))
_DEPLOY_VERSION_LT_4_3 = $(call __simplify,_DEPLOY_VERSION_LT_4_3,$(shell $(THEOS_BIN_PATH)/vercmp.pl $(_THEOS_TARGET_IPHONEOS_DEPLOYMENT_VERSION) lt 4.3))

ifeq ($(_TARGET_VERSION_GE_4_0),1)
ifeq ($(_THEOS_TARGET_CC),arm-apple-darwin9-gcc)
ifeq ($(_THEOS_TARGET_WARNED_TARGETGCC),)
before-all::
	@$(PRINT_FORMAT_WARNING) "Targeting iOS 4.0 and higher is not supported with iphone-gcc. Forcing clang." >&2
export _THEOS_TARGET_WARNED_TARGETGCC := 1
endif
override _THEOS_TARGET_CC := clang
override _THEOS_TARGET_CXX := clang++
endif
endif

ifeq ($(_TARGET_VERSION_GE_6_0)$(_DEPLOY_VERSION_GE_3_0)$(_DEPLOY_VERSION_LT_4_3),111)
ifeq ($(ARCHS)$(IPHONE_ARCHS)$(_THEOS_TARGET_WARNED_DEPLOY),)
before-all::
	@$(PRINT_FORMAT_WARNING) "Deploying to iOS 3.0 while building for 6.0 will generate armv7-only binaries." >&2
export _THEOS_TARGET_WARNED_DEPLOY := 1
endif
endif

SYSROOT ?= $(_SDK_DIR)/iPhoneOS$(_THEOS_TARGET_SDK_VERSION).sdk

TARGET_CC ?= $(_THEOS_TARGET_CC)
TARGET_CXX ?= $(_THEOS_TARGET_CXX)
TARGET_LD ?= $(_THEOS_TARGET_CXX)
TARGET_STRIP ?= strip
TARGET_STRIP_FLAGS ?= -x
TARGET_CODESIGN_ALLOCATE ?= codesign_allocate
TARGET_CODESIGN ?= ldid
TARGET_CODESIGN_FLAGS ?= -S

TARGET_PRIVATE_FRAMEWORK_PATH = $(SYSROOT)/System/Library/PrivateFrameworks
TARGET_PRIVATE_FRAMEWORK_INCLUDE_PATH = $(ISYSROOT)/System/Library/PrivateFrameworks

include $(THEOS_MAKE_PATH)/targets/_common/darwin.mk
include $(THEOS_MAKE_PATH)/targets/_common/darwin_flat_bundle.mk

ifeq ($(_TARGET_VERSION_GE_6_0),1) # >= 6.0 {
	ARCHS ?= armv7
else # } < 6.0 {
ifeq ($(_TARGET_VERSION_GE_3_0),1) # >= 3.0 {
ifeq ($(_THEOS_TARGET_CC),arm-apple-darwin9-gcc) # iphone-gcc doesn't support armv7
	ARCHS ?= armv6
else
	ARCHS ?= armv6 armv7
endif
else # } < 3.0 {
	ARCHS ?= armv6
endif # }
endif # }

ifeq ($(THEOS_CURRENT_ARCH),arm64)
LEGACYFLAGS :=
else
LEGACYFLAGS := -Wl,-segalign,4000
endif

SDKFLAGS := -isysroot "$(SYSROOT)" -D__IPHONE_OS_VERSION_MIN_REQUIRED=__IPHONE_$(subst .,_,$(_THEOS_TARGET_IPHONEOS_DEPLOYMENT_VERSION)) -miphoneos-version-min=$(_THEOS_TARGET_IPHONEOS_DEPLOYMENT_VERSION)
_THEOS_TARGET_CFLAGS := $(SDKFLAGS)
_THEOS_TARGET_LDFLAGS := $(SDKFLAGS) $(LEGACYFLAGS) -multiply_defined suppress

TARGET_INSTALL_REMOTE := $(_THEOS_FALSE)
ifeq ($(THEOS_INSTALL_USING_SSH),1)
	TARGET_INSTALL_REMOTE := $(_THEOS_TRUE)
endif
_THEOS_TARGET_DEFAULT_PACKAGE_FORMAT := deb
PREINSTALL_TARGET_PROCESSES ?= Cydia
endif
