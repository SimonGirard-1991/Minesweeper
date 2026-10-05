DERIVED := build/DerivedData.noindex
APP     := $(DERIVED)/Build/Products/Release/Minesweeper.app
XCB     := xcodebuild -project Minesweeper.xcodeproj -scheme Minesweeper -derivedDataPath $(DERIVED) -quiet
ICONSET := Resources/Assets.xcassets/AppIcon.appiconset

TV_XCB       := xcodebuild -project Minesweeper.xcodeproj -scheme MinesweeperTV -derivedDataPath $(DERIVED) -quiet
TV_APP       := $(DERIVED)/Build/Products/Release-appletvsimulator/MinesweeperTV.app
TV_BRAND     := ResourcesTV/Assets.xcassets/AppIcon.brandassets
TV_SIMULATOR ?= Apple TV 4K (3rd generation)

.PHONY: help generate build test run install icon clean tv-build tv-build-device tv-test tv-run tv-icon

help:
	@echo "Requires Xcode and XcodeGen (brew install xcodegen)."
	@echo
	@echo "make build    Release build into $(APP)"
	@echo "make test     run the unit tests"
	@echo "make run      build, then open the app"
	@echo "make install  build, then copy the app to ~/Applications"
	@echo "make icon     re-render the app icon PNGs into $(ICONSET)"
	@echo "make clean    remove build/ and the generated Xcode project"
	@echo
	@echo "Apple TV:"
	@echo "make tv-build         Release build for the tvOS Simulator into $(TV_APP)"
	@echo "make tv-build-device  Release build for a real Apple TV (TV_TEAM=<team id> required)"
	@echo "make tv-test          run the unit tests on the '$(TV_SIMULATOR)' simulator"
	@echo "make tv-run           build, then install and launch on that simulator"
	@echo "make tv-icon          re-render the tvOS icon and Top Shelf PNGs into $(TV_BRAND)"
	@echo "(TV_SIMULATOR=<name> picks another simulator; 'xcrun simctl list devices' lists them.)"

generate:
	@command -v xcodegen >/dev/null || { echo "xcodegen not found: brew install xcodegen" >&2; exit 1; }
	xcodegen generate --quiet

build: generate
	$(XCB) -configuration Release build

test: generate
	rm -rf build/TestResults.xcresult
	$(XCB) -resultBundlePath build/TestResults.xcresult test; status=$$?; \
	xcrun xcresulttool get test-results summary --path build/TestResults.xcresult \
	  | grep -E '"(result|passedTests|failedTests)"' | sort -u; exit $$status

run: build
	open "$(APP)"

install: build
	rm -rf "$(HOME)/Applications/Minesweeper.app"
	ditto "$(APP)" "$(HOME)/Applications/Minesweeper.app"

icon:
	mkdir -p build
	xcrun swiftc -O -swift-version 6 -o build/icon-exporter Sources/Graphics/*.swift Tools/IconExporter/main.swift
	build/icon-exporter "$(ICONSET)"

clean:
	rm -rf build Minesweeper.xcodeproj

tv-build: generate
	$(TV_XCB) -configuration Release -destination 'generic/platform=tvOS Simulator' build

tv-build-device: generate
	@test -n "$(TV_TEAM)" || { echo "set TV_TEAM=<your Apple developer team id>" >&2; exit 2; }
	$(TV_XCB) -configuration Release -destination 'generic/platform=tvOS' -allowProvisioningUpdates \
	  DEVELOPMENT_TEAM="$(TV_TEAM)" CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY="Apple Development" build

tv-test: generate
	rm -rf build/TestResultsTV.xcresult
	$(TV_XCB) -destination 'platform=tvOS Simulator,name=$(TV_SIMULATOR)' \
	  -resultBundlePath build/TestResultsTV.xcresult test; status=$$?; \
	xcrun xcresulttool get test-results summary --path build/TestResultsTV.xcresult \
	  | grep -E '"(result|passedTests|failedTests)"' | sort -u; exit $$status

tv-run: tv-build
	xcrun simctl bootstatus "$(TV_SIMULATOR)" -b
	open -a Simulator
	xcrun simctl install "$(TV_SIMULATOR)" "$(TV_APP)"
	xcrun simctl launch "$(TV_SIMULATOR)" local.minesweeper.tv

tv-icon:
	mkdir -p build
	xcrun swiftc -O -swift-version 6 -o build/tv-icon-exporter Sources/Core/*.swift Sources/Graphics/*.swift Tools/TVIconExporter/main.swift
	build/tv-icon-exporter "$(TV_BRAND)"
