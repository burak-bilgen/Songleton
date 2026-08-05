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
VERSION      := $(shell xcodebuild -project $(PROJECT) -scheme $(SCHEME) -showBuildSettings 2>/dev/null | grep ' MARKETING_VERSION' | head -1 | awk '{print $$3}')
DMG_NAME     = $(APP_NAME)-$(VERSION).dmg
DMG_PATH     = build/$(DMG_NAME)
ARCHIVE_PATH = build/$(APP_NAME).xcarchive
ARCHIVE_APP  = $(ARCHIVE_PATH)/Products/Applications/$(APP_NAME).app

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
	@echo "Resetting UserDefaults & Containers..."
	@pkill -9 -x $(APP_NAME) 2>/dev/null || true
	@defaults delete $(BUNDLE_ID) 2>/dev/null || true
	@rm -rf ~/Library/Containers/$(BUNDLE_ID) 2>/dev/null || true
	@rm -rf ~/Library/Preferences/$(BUNDLE_ID).plist 2>/dev/null || true
	@rm -rf ~/Library/Caches/$(BUNDLE_ID) 2>/dev/null || true
	@rm -rf ~/Library/HTTPStorages/$(BUNDLE_ID) 2>/dev/null || true
	@rm -rf ~/Library/Saved\ Application\ State/$(BUNDLE_ID).savedState 2>/dev/null || true
	@killall cfprefsd 2>/dev/null || true
	@echo "Resetting TCC Automation permission..."
	@tccutil reset AppleEvents $(BUNDLE_ID) 2>/dev/null || true
	@sleep 0.5
	@open "$(DEBUG_APP)" --args --reset-onboarding

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

## Create a distributable DMG from a Developer ID-signed archive.
dmg: archive
	@echo "Creating DMG..."
	@rm -rf build/dmg-stage
	@mkdir -p build/dmg-stage
	@cp -R "$(ARCHIVE_APP)" build/dmg-stage/
	@ln -sf /Applications build/dmg-stage/Applications
	@rm -f "$(DMG_PATH)"
	@diskutil image create from \
		--volumeName "$(APP_NAME)" \
		--format UDZO \
		build/dmg-stage \
		"$(DMG_PATH)"
	@codesign --force --timestamp --sign "$(DEVELOPER_IDENTITY)" "$(DMG_PATH)"
	@codesign --verify --strict --verbose=2 "$(DMG_PATH)"
	@rm -rf build/dmg-stage
	@echo "DMG ready: $(DMG_PATH)"
	@ls -lh "$(DMG_PATH)"
	@open build/

build-release:
	@echo "🔨 Release build..."
	@xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release build \
		CONFIGURATION_BUILD_DIR="$(PWD)/$(RELEASE_DIR)"
	@codesign --verify --deep --strict --verbose=2 "$(RELEASE_APP)"

## Create a Developer ID-signed archive suitable for distribution.
archive:
	@test -n "$(DEVELOPER_IDENTITY)" || (echo "DEVELOPER_IDENTITY is required, for example: Developer ID Application: Your Name (TEAMID)" && exit 1)
	@echo "📦 Archiving release..."
	@rm -rf "$(ARCHIVE_PATH)"
	@xcodebuild archive -project $(PROJECT) -scheme $(SCHEME) -configuration Release \
		-archivePath "$(ARCHIVE_PATH)" \
		CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$(DEVELOPER_IDENTITY)"
	@codesign --verify --deep --strict --verbose=2 "$(ARCHIVE_APP)"

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

## Run static security checks.
security:
	@chmod +x scripts/security-audit.sh && ./scripts/security-audit.sh

## Validate localization coverage and reject hardcoded user-facing strings.
localization:
	@chmod +x scripts/localization-audit.sh && ./scripts/localization-audit.sh

## Validate the static site, translations, assets, and accessibility boundaries.
site:
	@chmod +x scripts/site-audit.sh && ./scripts/site-audit.sh

## Run security, localization, site checks, tests, and fail on Swift compiler warnings.
quality: security localization site test
	@xcodebuild -quiet -project $(PROJECT) -scheme $(SCHEME) -configuration Debug build \
		CODE_SIGNING_ALLOWED=NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
	@xcodebuild -quiet -project $(PROJECT) -scheme $(SCHEME) -configuration Release \
		-destination 'generic/platform=macOS' build \
		CODE_SIGNING_ALLOWED=NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES

## Create a notarized release DMG using credentials stored in Keychain.
notarize: dmg
	@test -n "$(NOTARY_PROFILE)" || (echo "NOTARY_PROFILE is required. Store credentials with notarytool store-credentials." && exit 1)
	@xcrun notarytool submit "$(DMG_PATH)" --keychain-profile "$(NOTARY_PROFILE)" --wait
	@xcrun stapler staple "$(DMG_PATH)"
	@xcrun stapler validate "$(DMG_PATH)"
	@spctl --assess --type open --context context:primary-signature --verbose=2 "$(DMG_PATH)"

.PHONY: run build-debug fresh kill restart logs dmg build-release archive clean test coverage security localization site quality notarize
.DEFAULT_GOAL := run
