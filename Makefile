APP_NAME     = Songleton
SCHEME       = Songleton
PROJECT      = Songleton.xcodeproj
BUNDLE_ID    = bilgenworks.app.Songleton

# Debug build output path from DerivedData.
DERIVED_DATA := $(shell xcodebuild -project $(PROJECT) -scheme $(SCHEME) -showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR' | head -1 | awk '{print $$3}')
DEBUG_APP    = $(DERIVED_DATA)/$(APP_NAME).app

# Release build directory.
RELEASE_DIR  = build/Release
RELEASE_APP  = $(RELEASE_DIR)/$(APP_NAME).app
DMG_NAME     = $(APP_NAME)-1.0.dmg
DMG_PATH     = build/$(DMG_NAME)

# ─────────────────────────────────────────────
# Development targets.
# ─────────────────────────────────────────────

## Build and run.
run: build-debug
	@echo "Starting application..."
	@pkill -x $(APP_NAME) 2>/dev/null || true
	@sleep 0.3
	@open "$(DEBUG_APP)"

## Build without launching.
build-debug:
	@echo "🔨 Debug build..."
	@xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug build

## Reset UserDefaults and TCC permissions, then build and launch.
fresh: build-debug
	@echo "Resetting UserDefaults..."
	@defaults delete $(BUNDLE_ID) 2>/dev/null || true
	@echo "Resetting TCC Automation permission..."
	@tccutil reset AppleEvents $(BUNDLE_ID) 2>/dev/null || true
	@pkill -x $(APP_NAME) 2>/dev/null || true
	@sleep 0.3
	@open "$(DEBUG_APP)"

## Terminate the running application.
kill:
	@pkill -x $(APP_NAME) 2>/dev/null && echo "Terminated" || echo "Already stopped"

## Restart without rebuilding.
restart: kill
	@sleep 0.3
	@open "$(DEBUG_APP)"
	@echo "Restarted"

## Stream application logs.
logs:
	@log stream --predicate 'subsystem == "$(BUNDLE_ID)" OR process == "$(APP_NAME)"' --level debug

# ─────────────────────────────────────────────
# Distribution targets.
# ─────────────────────────────────────────────

## Build a release and create a DMG.
dmg: build-release
	@echo "Creating DMG..."
	@rm -rf build/dmg-stage
	@mkdir -p build/dmg-stage
	@cp -R "$(RELEASE_APP)" build/dmg-stage/
	@ln -sf /Applications build/dmg-stage/Applications
	@rm -f "$(DMG_PATH)"
	@hdiutil create \
		-volname "$(APP_NAME)" \
		-srcfolder build/dmg-stage \
		-ov -format UDZO \
		-imagekey zlib-level=9 \
		"$(DMG_PATH)"
	@rm -rf build/dmg-stage
	@echo "DMG ready: $(DMG_PATH)"
	@ls -lh "$(DMG_PATH)"
	@open build/

build-release:
	@echo "🔨 Release build..."
	@xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release build \
		CONFIGURATION_BUILD_DIR="$(PWD)/$(RELEASE_DIR)"
	@codesign --verify --deep --strict --verbose=2 "$(RELEASE_APP)"

## Clean build artifacts.
clean:
	@echo "Cleaning..."
	@rm -rf build/
	@xcodebuild -project $(PROJECT) -scheme $(SCHEME) clean -quiet
	@echo "Clean"

## Run the native test runner.
test:
	@chmod +x run_tests.sh && ./run_tests.sh

## Run tests with an LLVM coverage report.
coverage:
	@echo "📊 Measuring test coverage..."
	@rm -rf /tmp/SongletonCoverage
	@mkdir -p /tmp/SongletonCoverage
	@LLVM_PROFILE_FILE="/tmp/SongletonCoverage/Songleton-%p.profraw" BUILD_DIR=/tmp/SongletonCoverage SWIFT_EXTRA_FLAGS="-profile-generate -profile-coverage-mapping" ./run_tests.sh
	@xcrun llvm-profdata merge -sparse /tmp/SongletonCoverage/*.profraw -o /tmp/SongletonCoverage/Songleton.profdata
	@xcrun llvm-cov report /tmp/SongletonCoverage/RunTests -instr-profile=/tmp/SongletonCoverage/Songleton.profdata --ignore-filename-regex='Songleton/(App|Views)/|SongletonTests/'

## Create a notarized release DMG (Apple credentials required).
notarize: dmg
	@test -n "$(APPLE_ID)" || (echo "APPLE_ID is required" && exit 1)
	@test -n "$(TEAM_ID)" || (echo "TEAM_ID is required" && exit 1)
	@test -n "$(APP_PASSWORD)" || (echo "APP_PASSWORD is required" && exit 1)
	@xcrun notarytool submit "$(DMG_PATH)" --apple-id "$(APPLE_ID)" --team-id "$(TEAM_ID)" --password "$(APP_PASSWORD)" --wait
	@xcrun stapler staple "$(DMG_PATH)"

.PHONY: run build-debug fresh kill restart logs dmg build-release clean test coverage notarize
.DEFAULT_GOAL := run
