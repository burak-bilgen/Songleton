APP_NAME     = Songleton
SCHEME       = Songleton
PROJECT      = Songleton.xcodeproj
BUNDLE_ID    = bilgenworks.app.Songleton

# DerivedData'daki debug build çıktısı
DERIVED_DATA := $(shell xcodebuild -project $(PROJECT) -scheme $(SCHEME) -showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR' | head -1 | awk '{print $$3}')
DEBUG_APP    = $(DERIVED_DATA)/$(APP_NAME).app

# Release build klasörü
RELEASE_DIR  = build/Release
RELEASE_APP  = $(RELEASE_DIR)/$(APP_NAME).app
DMG_NAME     = $(APP_NAME)-1.0.dmg
DMG_PATH     = build/$(DMG_NAME)

# ─────────────────────────────────────────────
# Geliştirme sırasında kullanılanlar
# ─────────────────────────────────────────────

## Derle + çalıştır (en sık kullanılan)
run: build-debug
	@echo "▶ Uygulama başlatılıyor..."
	@pkill -x $(APP_NAME) 2>/dev/null || true
	@sleep 0.3
	@open "$(DEBUG_APP)"

## Sadece derle (çalıştırmadan)
build-debug:
	@echo "🔨 Debug build..."
	@xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug build \
		| grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" \
		| grep -v appintentsmetadata

## Fresh start: UserDefaults + TCC izinlerini sıfırla + derle + çalıştır
fresh: build-debug
	@echo "🧹 UserDefaults sıfırlanıyor..."
	@defaults delete $(BUNDLE_ID) 2>/dev/null || true
	@echo "🔐 TCC Automation izni sıfırlanıyor..."
	@tccutil reset AppleEvents $(BUNDLE_ID) 2>/dev/null || true
	@pkill -x $(APP_NAME) 2>/dev/null || true
	@sleep 0.3
	@open "$(DEBUG_APP)"

## Çalışan uygulamayı kapat
kill:
	@pkill -x $(APP_NAME) 2>/dev/null && echo "⏹ Kapatıldı" || echo "Zaten kapalıydı"

## Sadece yeniden başlat (rebuild yok)
restart: kill
	@sleep 0.3
	@open "$(DEBUG_APP)"
	@echo "🔄 Yeniden başlatıldı"

## Console loglarını izle (crash ve print çıktıları)
logs:
	@log stream --predicate 'subsystem == "$(BUNDLE_ID)" OR process == "$(APP_NAME)"' --level debug

# ─────────────────────────────────────────────
# Dağıtım
# ─────────────────────────────────────────────

## Release build yap + DMG oluştur
dmg: build-release
	@echo "📦 DMG oluşturuluyor..."
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
		"$(DMG_PATH)" 2>&1 | grep -v WARNING
	@rm -rf build/dmg-stage
	@echo "✅ DMG hazır: $(DMG_PATH)"
	@ls -lh "$(DMG_PATH)"
	@open build/

build-release:
	@echo "🔨 Release build..."
	@xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release build \
		CONFIGURATION_BUILD_DIR="$(PWD)/$(RELEASE_DIR)" \
		| grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" \
		| grep -v appintentsmetadata

## Build klasörünü temizle
clean:
	@echo "🗑 Temizleniyor..."
	@rm -rf build/
	@xcodebuild -project $(PROJECT) -scheme $(SCHEME) clean -quiet
	@echo "✓ Temiz"

.PHONY: run build-debug fresh kill restart logs dmg build-release clean
.DEFAULT_GOAL := run
