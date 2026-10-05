DERIVED := build/DerivedData.noindex
APP     := $(DERIVED)/Build/Products/Release/Minesweeper.app
XCB     := xcodebuild -project Minesweeper.xcodeproj -scheme Minesweeper -derivedDataPath $(DERIVED) -quiet
ICONSET := Resources/Assets.xcassets/AppIcon.appiconset

.PHONY: help generate build test run install icon clean

help:
	@echo "Requires Xcode and XcodeGen (brew install xcodegen)."
	@echo
	@echo "make build    Release build into $(APP)"
	@echo "make test     run the unit tests"
	@echo "make run      build, then open the app"
	@echo "make install  build, then copy the app to ~/Applications"
	@echo "make icon     re-render the app icon PNGs into $(ICONSET)"
	@echo "make clean    remove build/ and the generated Xcode project"

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
