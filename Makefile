APP_NAME = MacTile
BUILD_DIR = .build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
EXECUTABLE = $(BUILD_DIR)/debug/$(APP_NAME)

.PHONY: build run run-debug clean bundle install

build:
	swift build

bundle: build
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	cp $(EXECUTABLE) "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	cp SupportFiles/Info.plist "$(APP_BUNDLE)/Contents/Info.plist"

install: bundle
	rm -rf /Applications/MacTile.app
	cp -R "$(APP_BUNDLE)" /Applications/MacTile.app

run: bundle
	open "$(APP_BUNDLE)"

run-debug: build
	$(EXECUTABLE)

clean:
	swift package clean
	rm -rf $(APP_BUNDLE)
