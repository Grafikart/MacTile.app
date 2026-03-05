APP_NAME = MacTile
BUILD_DIR = .build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
EXECUTABLE = $(BUILD_DIR)/debug/$(APP_NAME)

.PHONY: build run run-debug clean bundle

build:
	swift build

bundle: build
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	cp $(EXECUTABLE) "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	cp SupportFiles/Info.plist "$(APP_BUNDLE)/Contents/Info.plist"

run: bundle
	open "$(APP_BUNDLE)"

run-debug: build
	$(EXECUTABLE)

clean:
	swift package clean
	rm -rf $(APP_BUNDLE)
