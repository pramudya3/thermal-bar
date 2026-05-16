# ThermalBar Makefile

APP_NAME = ThermalBar
PROJECT_DIR = ThermalBar
BUILD_DIR = build
APP_BUNDLE = $(APP_NAME).app
ENTITLEMENTS = $(PROJECT_DIR)/Resources/ThermalBar.entitlements
BRIDGING_HEADER = $(PROJECT_DIR)/ThermalBar-Bridging-Header.h
INFO_PLIST = $(PROJECT_DIR)/Resources/Info.plist

SWIFTC = swiftc
SWIFT_FLAGS = -O -framework SwiftUI -framework IOKit -framework ServiceManagement -framework AppKit -framework UserNotifications

.PHONY: all build clean run sign

all: build

build: clean
	@echo "🚀 Building $(APP_NAME)..."
	@mkdir -p $(BUILD_DIR)
	$(SWIFTC) -import-objc-header $(BRIDGING_HEADER) \
		-o $(BUILD_DIR)/$(APP_NAME) \
		$$(find $(PROJECT_DIR) -name "*.swift") \
		$(SWIFT_FLAGS)
	@echo "📦 Bundling into $(APP_BUNDLE)..."
	@rm -rf "$(APP_BUNDLE)"
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@cp "$(BUILD_DIR)/$(APP_NAME)" "$(APP_BUNDLE)/Contents/MacOS/"
	@cp "$(INFO_PLIST)" "$(APP_BUNDLE)/Contents/Info.plist"
	@$(MAKE) sign
	@rm -rf $(BUILD_DIR)
	@echo "✅ $(APP_NAME) is ready."

sign:
	@echo "🔏 Code-signing with entitlements..."
	@codesign --force --deep --sign "-" --entitlements $(ENTITLEMENTS) "$(APP_BUNDLE)"

run:
	@open "$(APP_BUNDLE)"

clean:
	@rm -rf $(BUILD_DIR)
	@rm -rf "$(APP_BUNDLE)"
	@rm -f "$(APP_NAME).zip"

dist: build
	@echo "📦 Creating $(APP_NAME).zip for GitHub release..."
	@zip -r -9 "$(APP_NAME).zip" "$(APP_BUNDLE)"
	@echo "✅ Distribution package created: $(APP_NAME).zip"
