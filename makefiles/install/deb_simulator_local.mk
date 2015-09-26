internal-install-check::
	@if [ -z "$(THEOS_SIMULATOR_ID)" ]; then \
		$(PRINT_FORMAT_ERROR) "$(MAKE) install requires you to specify a device with $$THEOS_SIMULATOR_ID." >&2; \
		$(PRINT_FORMAT_ERROR) "To view a list of simulators, run: xcrun simctl list" >&2; \
		exit 1; \
	fi

internal-install:: internal-install-check
	$(ECHO_INSTALLING)true$(ECHO_END)
	$(ECHO_NOTHING)open $(shell xcode-select -print-path)/Applications/Simulator.app$(ECHO_END)
	$(ECHO_NOTHING)SIMCTL_CHILD_DYLD_INSERT_LIBRARIES=/Library/MobileSubstrate/MobileSubstrate.dylib xcrun simctl boot $(THEOS_SIMULATOR_ID)$(ECHO_END)
	$(ECHO_NOTHING)install.exec "$(THEOS_SUDO_COMMAND) dpkg --root=$(HOME)/Library/Developer/CoreSimulator/Devices/$(THEOS_SIMULATOR_ID)/data/Root -i \"$(_THEOS_PACKAGE_LAST_FILENAME)\""$(ECHO_END)

internal-after-install::
	#$(ECHO_NOTHING)install.exec "launchctl debug system/com.apple.SpringBoard --environment DYLD_INSERT_LIBRARIES=$PWD/SBShortcutMenuSimulator.dylib"
	$(ECHO_NOTHING)install.exec "launchctl stop com.apple.SpringBoard"$(ECHO_END)
