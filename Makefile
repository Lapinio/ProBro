# Local shortcuts for a Mac with Xcode 26+. CI uses the same commands.
.PHONY: bootstrap project open build-macos build-ios test-macos test-ios release-ios release-macos clean

IOS_SIM ?= platform=iOS Simulator,name=iPhone 17
XCB = xcodebuild -project ProBro.xcodeproj -scheme ProBro CODE_SIGNING_ALLOWED=NO

bootstrap:
	brew list xcodegen >/dev/null 2>&1 || brew install xcodegen

project: bootstrap
	xcodegen generate

open: project
	open ProBro.xcodeproj

build-macos: project
	$(XCB) -destination 'platform=macOS' build

build-ios: project
	$(XCB) -destination 'generic/platform=iOS Simulator' build

test-macos: project
	$(XCB) -destination 'platform=macOS' test

test-ios: project
	$(XCB) -destination '$(IOS_SIM)' test

release-ios: project
	scripts/release.sh ios

release-macos: project
	scripts/release.sh macos

clean:
	rm -rf build ProBro.xcodeproj
