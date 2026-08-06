import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsModel
    @ObservedObject private var model = NowPlayingModel.shared
    @ObservedObject private var localization = LocalizationManager.shared

    @State private var appearScale: CGFloat = 0.95
    @State private var appearOpacity: Double = 0.0
    @State private var hoveredSection: String? = nil
    @State private var accessibilityPermissionGranted = MouseGestureManager.shared.isAccessibilityTrusted

    var body: some View {
        ZStack {
            SongletonTheme.background.ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 18) {
                    headerSection

                    if model.automationStatus != .granted {
                        permissionWarningBanner
                    }

                    generalSection
                    languageSection
                    menuBarSection
                    lyricsSection
                    permissionsSection
                    shortcutsAndGesturesGuideSection
                    footerSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 22)
            }
        }
        .frame(width: 520, height: 720)
        .scaleEffect(appearScale)
        .opacity(appearOpacity)
        .onAppear {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            model.checkAutomationPermission()
            refreshAccessibilityStatus()
            centerWindow()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                appearScale = 1.0
                appearOpacity = 1.0
            }
        }
        .onDisappear {
            let hasVisibleWindow = NSApp.windows.contains { win in
                win.isVisible && win.identifier?.rawValue != "settings" && (win.identifier?.rawValue == "onboardingWindow" || win.identifier?.rawValue == "setupRecoveryWindow")
            }
            if !hasVisibleWindow {
                NSApp.setActivationPolicy(.accessory)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshAccessibilityStatus()
            model.checkAutomationPermission()
        }
    }

    private func centerWindow() {
        DispatchQueue.main.async {
            NSApp.keyWindow?.center()
        }
    }

    private func refreshAccessibilityStatus() {
        accessibilityPermissionGranted = MouseGestureManager.shared.isAccessibilityTrusted
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(SongletonTheme.accentGradient)
                    .frame(width: 58, height: 58)
                    .shadow(color: SongletonTheme.cyan.opacity(0.18), radius: 12, y: 5)

                if let appIcon = NSImage(named: NSImage.applicationIconName) {
                    Image(nsImage: appIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 42, height: 42)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.black.opacity(0.78))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(localization.string("app.name"))
                    .font(.custom("Audiowide", size: 22))
                    .foregroundStyle(.white)

                Text(localization.string("app.subtitle"))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(SongletonTheme.secondaryText)
            }

            Spacer()
        }
        .padding(16)
        .background(SongletonTheme.panelGradient, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(SongletonTheme.borderGradient, lineWidth: 1)
        )
        .shadow(color: SongletonTheme.violet.opacity(0.1), radius: 18, y: 8)
    }

    // MARK: - General Section

    private var generalSection: some View {
        settingsCard(title: localization.string("settings.general"), icon: "gearshape.fill", sectionID: "general") {
            settingsToggleRow(
                icon: "power",
                title: localization.string("settings.launch_at_login"),
                subtitle: localization.string("settings.launch_at_login_hint"),
                isOn: $settings.launchAtLogin
            )

            sectionDivider

            settingsToggleRow(
                icon: "bell.fill",
                title: localization.string("settings.track_notifications"),
                subtitle: localization.string("settings.track_notifications_hint"),
                isOn: $settings.showTrackNotifications
            )

            if settings.showTrackNotifications {
                sectionDivider

                notificationPositionRow
            }

            sectionDivider

            settingsToggleRow(
                icon: "arrow.left.and.right.square.fill",
                title: localization.string("settings.horizontal_gestures"),
                subtitle: localization.string("settings.horizontal_gestures_hint"),
                isOn: $settings.horizontalGesturesEnabled
            )

            sectionDivider

            settingsToggleRow(
                icon: "arrow.up.and.down.square.fill",
                title: localization.string("settings.vertical_gestures"),
                subtitle: localization.string("settings.vertical_gestures_hint"),
                isOn: $settings.verticalGesturesEnabled
            )

            sectionDivider

            settingsPickerRow(
                icon: "timer",
                title: localization.string("settings.edge_gesture_duration"),
                subtitle: localization.string("settings.edge_gesture_duration_hint")
            ) {
                Slider(value: $settings.edgeGestureHoldDuration, in: 0.2...2.0, step: 0.1)
                    .tint(SongletonTheme.cyan)
                    .frame(width: 110)

                Text(String(
                    format: localization.string("settings.seconds_format"),
                    locale: localization.locale,
                    settings.edgeGestureHoldDuration
                ))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(width: 34, alignment: .trailing)
            }
        }
    }

    // MARK: - Shortcuts & Gestures Visual Guide Section

    private var shortcutsAndGesturesGuideSection: some View {
        settingsCard(
            title: localization.string("settings.shortcuts_guide"),
            icon: "keyboard.fill",
            sectionID: "shortcuts_guide"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                // Section Title: Keyboard Shortcuts Legend
                HStack {
                    Image(systemName: "command")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(SongletonTheme.cyan)
                    Text(localization.string("settings.keyboard_shortcuts_title"))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(SongletonTheme.cyan)
                }

                VStack(spacing: 8) {
                    shortcutRow(
                        keys: [keyCapView(localization.string("key.space"), width: 52)],
                        description: localization.string("shortcut.play_pause")
                    )

                    shortcutRow(
                        keys: [keyCapView("←"), keyCapView("→")],
                        description: localization.string("shortcut.prev_next_track")
                    )

                    shortcutRow(
                        keys: [keyCapView("↑"), keyCapView("↓")],
                        description: localization.string("shortcut.volume_control")
                    )

                    shortcutRow(
                        keys: [keyCapView("L")],
                        description: localization.string("shortcut.toggle_lyrics")
                    )

                    shortcutRow(
                        keys: [keyCapView("T")],
                        description: localization.string("shortcut.cycle_themes")
                    )

                    shortcutRow(
                        keys: [keyCapView("ESC")],
                        description: localization.string("shortcut.exit_ambient")
                    )
                }

                sectionDivider
                    .padding(.vertical, 2)

                // Section Title: Screen & Mouse Gestures Legend
                HStack {
                    Image(systemName: "hand.point.up.left.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(SongletonTheme.cyan)
                    Text(localization.string("settings.gestures_title"))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(SongletonTheme.cyan)

                    Spacer()

                    Button {
                        NotificationCenter.default.post(name: .songletonShowGestureTutorial, object: nil)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text(localization.string("settings.guide_demo"))
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(SongletonTheme.cyan, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                VStack(spacing: 8) {
                    gestureRow(
                        icon: "arrow.left.to.line.compact",
                        action: localization.string("gesture.left_action"),
                        description: gestureDescription("gesture.left_desc"),
                        isEnabled: settings.horizontalGesturesEnabled
                    )

                    gestureRow(
                        icon: "arrow.right.to.line.compact",
                        action: localization.string("gesture.right_action"),
                        description: gestureDescription("gesture.right_desc"),
                        isEnabled: settings.horizontalGesturesEnabled
                    )

                    gestureRow(
                        icon: "arrow.up.to.line.compact",
                        action: localization.string("gesture.top_action"),
                        description: gestureDescription("gesture.top_desc"),
                        isEnabled: settings.verticalGesturesEnabled
                    )

                    gestureRow(
                        icon: "speaker.wave.2.fill",
                        action: localization.string("gesture.volume_action"),
                        description: localization.string("gesture.volume_desc"),
                        isEnabled: settings.verticalGesturesEnabled
                    )
                }
            }
            .padding(16)
        }
    }

    private func shortcutRow(keys: [AnyView], description: String) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                ForEach(0..<keys.count, id: \.self) { idx in
                    keys[idx]
                }
            }
            .frame(width: 80, alignment: .leading)

            Text(description)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))

            Spacer()
        }
    }

    private func gestureRow(icon: String, action: String, description: String, isEnabled: Bool = true) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isEnabled ? Color.white.opacity(0.10) : Color.white.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(isEnabled ? Color.white.opacity(0.18) : Color.white.opacity(0.06), lineWidth: 0.5))
                    .frame(width: 30, height: 26)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isEnabled ? SongletonTheme.cyan : Color.white.opacity(0.3))
            }
            .opacity(isEnabled ? 1.0 : 0.4)

            Text(action)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(isEnabled ? .white : .white.opacity(0.35))

            Spacer()

            Text(description)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(isEnabled ? SongletonTheme.cyan.opacity(0.9) : .white.opacity(0.25))

            Text(verbatim: isEnabled ? "✓" : "✕")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(isEnabled ? SongletonTheme.cyan : .white.opacity(0.25))
        }
    }

    private func gestureDescription(_ key: String) -> String {
        let duration = key == "gesture.top_desc"
            ? settings.edgeGestureHoldDuration * 0.8
            : settings.edgeGestureHoldDuration
        let formattedDuration = String(format: "%.1f", locale: localization.locale, duration)
        return String(format: localization.string(key), formattedDuration)
    }

    private func keyCapView(_ text: String, width: CGFloat = 28) -> AnyView {
        AnyView(
            Text(text)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.95))
                .frame(height: 24)
                .frame(minWidth: width)
                .padding(.horizontal, 4)
                .background(
                    LinearGradient(
                        colors: [Color(white: 0.24), Color(white: 0.12)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.40), .white.opacity(0.10)],
                                startPoint: .top, endPoint: .bottom
                            ),
                            lineWidth: 0.8
                        )
                )
                .shadow(color: .black.opacity(0.45), radius: 3, x: 0, y: 2)
        )
    }

    private var languageSection: some View {
        settingsCard(title: localization.string("settings.language"), icon: "globe", sectionID: "language") {
            HStack(spacing: 12) {
                iconBadge(systemName: "character.bubble")
                VStack(alignment: .leading, spacing: 1) {
                    Text(localization.string("settings.language"))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(localization.string("settings.language_hint"))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                }
                Spacer()
                Picker("", selection: $localization.language) {
                    Text(localization.string("language.system")).tag(LocalizationManager.Language.system)
                    Text(localization.string("language.english")).tag(LocalizationManager.Language.english)
                    Text(localization.string("language.turkish")).tag(LocalizationManager.Language.turkish)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(SongletonTheme.cyan)
                .frame(width: 150, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Menu Bar Section

    private var menuBarSection: some View {
        settingsCard(title: localization.string("settings.menu_bar"), icon: "menubar.rectangle", sectionID: "menubar") {
            VStack(spacing: 0) {
                settingsToggleRow(
                    icon: "person.fill",
                    title: localization.string("settings.show_artist"),
                    subtitle: localization.string("settings.show_artist_hint"),
                    isOn: $settings.showArtistInMenuBar
                )

                sectionDivider

                settingsToggleRow(
                    icon: "forward.fill",
                    title: localization.string("settings.menu_bar_nav_buttons"),
                    subtitle: localization.string("settings.menu_bar_nav_buttons_hint"),
                    isOn: $settings.showMenuBarNavButtons
                )

                sectionDivider

                // Font Picker Row
                settingsPickerRow(icon: "textformat",
                    title: localization.string("settings.font"),
                    subtitle: localization.string("settings.font_hint")
                ) {
                    Picker("", selection: $settings.menuBarFont) {
                        Text(localization.string("settings.system_font")).tag(SettingsModel.MenuBarFont.system)
                        Text(localization.string("settings.audiowide_font")).tag(SettingsModel.MenuBarFont.audiowide)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }

                sectionDivider

                // Width Slider Row
                settingsPickerRow(icon: "arrow.left.and.right",
                    title: localization.string("settings.width"),
                    subtitle: localization.string("settings.width_hint")
                ) {
                    Slider(value: $settings.menuBarWidth, in: 80...300, step: 10)
                        .tint(SongletonTheme.cyan)
                        .frame(width: 110)

                    Text(verbatim: Int(settings.menuBarWidth).formatted(.number.locale(localization.locale)))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(width: 30, alignment: .trailing)
                }
            }
        }
    }

    // MARK: - Lyrics Section

    private var lyricsSection: some View {
        settingsCard(title: localization.string("lyrics.title"), icon: "quote.bubble.fill", sectionID: "lyrics") {
            settingsPickerRow(icon: "timer",
                title: localization.string("settings.lyrics_offset"),
                subtitle: localization.string("settings.lyrics_offset_hint"),
                subtitleSize: 10
            ) {
                Slider(value: $settings.lyricsOffset, in: -3.0...3.0, step: 0.1)
                    .tint(SongletonTheme.cyan)
                    .frame(width: 100)

                Text(String(
                    format: localization.string("settings.signed_seconds_format"),
                    locale: localization.locale,
                    settings.lyricsOffset
                ))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(width: 44, alignment: .trailing)
            }
        }
    }

    // MARK: - Permissions Section

    private var permissionsSection: some View {
        settingsCard(title: localization.string("settings.permissions"), icon: "lock.shield.fill", sectionID: "permissions") {
            VStack(spacing: 0) {
                // Player access status. macOS exposes this under Automation,
                // but the product-level label should describe what it unlocks.
                HStack(spacing: 12) {
                    iconBadge(systemName: automationStatusIcon, color: automationStatusColor)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(localization.string("permission.automation"))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(automationStatusText)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(automationStatusColor)
                        Text(localization.string("permission.explanation"))
                            .font(.system(size: 9.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.38))
                            .lineLimit(1)
                    }

                    Spacer()

                    Button {
                        model.checkAutomationPermission()
                    } label: {
                        Text(localization.string("common.check"))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(.white, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                sectionDivider

                // Open Privacy Settings Row
                Button {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 12) {
                        iconBadge(systemName: "arrow.up.forward.app.fill")

                            Text(localization.string("permission.open_settings"))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.2))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                sectionDivider

                Button {
                    MouseGestureManager.shared.requestAccessibilityAccess()
                    MouseGestureManager.shared.updateMonitoring()
                    refreshAccessibilityStatus()
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 12) {
                        iconBadge(
                            systemName: accessibilityPermissionGranted
                                ? "checkmark.circle.fill"
                                : "hand.raised.fill",
                            color: accessibilityPermissionGranted
                                ? SongletonTheme.cyan
                                : SongletonTheme.violet
                        )

                        VStack(alignment: .leading, spacing: 1) {
                            Text(localization.string("permission.accessibility"))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            Text(accessibilityPermissionGranted
                                ? localization.string("permission.granted")
                                : localization.string("permission.not_granted"))
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(accessibilityPermissionGranted
                                    ? SongletonTheme.cyan
                                    : SongletonTheme.violet)
                        }

                        Spacer()

                        Text(localization.string("permission.open_accessibility"))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(SongletonTheme.cyan)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Permission Warning Banner

    private var permissionWarningBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color(red: 1.0, green: 0.75, blue: 0.2))

            VStack(alignment: .leading, spacing: 2) {
                Text(localization.string("settings.permissions_missing"))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(localization.string("settings.permissions_missing_hint"))
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
            }

            Spacer()

            Button {
                NotificationCenter.default.post(name: .songletonShowOnboarding, object: nil)
            } label: {
                Text(localization.string("settings.grant_permissions"))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(red: 1.0, green: 0.65, blue: 0.0), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color(red: 1.0, green: 0.75, blue: 0.2).opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(red: 1.0, green: 0.75, blue: 0.2).opacity(0.4), lineWidth: 1.2))
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Button {
                    NotificationCenter.default.post(name: .songletonShowGestureTutorial, object: nil)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text(localization.string("settings.watch_demo"))
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(SongletonTheme.cyan)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(SongletonTheme.cyan.opacity(0.12), in: Capsule())
                    .overlay(Capsule().stroke(SongletonTheme.cyan.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    NotificationCenter.default.post(name: .songletonShowOnboarding, object: nil)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .bold))
                        Text(localization.string("settings.open_setup"))
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.08), in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            Text(String(
                format: localization.string("settings.version_format"),
                Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
            ))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.top, 4)
    }

    // MARK: - Reusable Components

    private var sectionDivider: some View {
        LinearGradient(
            colors: [.clear, Color.white.opacity(0.1), .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
            .frame(height: 1)
            .padding(.horizontal, 16)
    }

    private func iconBadge(systemName: String, color: Color = .white.opacity(0.7)) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(color.opacity(0.18), lineWidth: 0.5)
                )
                .frame(width: 32, height: 32)
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color)
        }
    }

    private func settingsCard<Content: View>(title: String, icon: String, sectionID: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(SongletonTheme.secondaryText)
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.leading, 4)
            .padding(.bottom, 8)

            // Card Body
            VStack(spacing: 0) {
                content()
            }
            .background(SongletonTheme.card.opacity(0.78), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        hoveredSection == sectionID
                            ? SongletonTheme.cyan.opacity(0.38)
                            : Color.white.opacity(0.09),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
            .onHover { isHovered in
                withAnimation(.easeInOut(duration: 0.2)) {
                    hoveredSection = isHovered ? sectionID : nil
                }
            }
        }
    }

    private func settingsToggleRow(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            iconBadge(systemName: icon)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
            }

            Spacer()

            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .tint(SongletonTheme.cyan)
                .labelsHidden()
                .accessibilityLabel(title)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func settingsPickerRow<Content: View>(icon: String, title: String, subtitle: String, subtitleSize: CGFloat = 11, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            iconBadge(systemName: icon)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: subtitleSize, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
            }

            Spacer()

            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var notificationPositionRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                iconBadge(systemName: "rectangle.grid.3x3.fill")

                VStack(alignment: .leading, spacing: 1) {
                    Text(localization.string("settings.notification_position"))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(localization.string("settings.notification_position_hint"))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                }

                Spacer()
            }

            NotificationPositionSelector(selection: $settings.trackNotificationPosition)

            HStack {
                Label(
                    localization.string(settings.trackNotificationPosition.localizationKey),
                    systemImage: settings.trackNotificationPosition.iconName
                )
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(SongletonTheme.secondaryText)

                Spacer()
            }

            NotificationAppearancePreview()

            Button {
                HUDToastManager.shared.showPreview()
            } label: {
                Label(localization.string("settings.preview_notification"), systemImage: "play.circle.fill")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(SongletonTheme.cyan, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityHint(localization.string("settings.preview_notification_hint"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Permission Helpers

    private var automationStatusColor: Color {
        switch model.automationStatus {
        case .granted: return Color(hue: 0.35, saturation: 0.5, brightness: 0.7)  // muted sage
        case .denied: return Color(hue: 0.0, saturation: 0.45, brightness: 0.7)   // muted coral
        case .notDetermined: return SongletonTheme.violet.opacity(0.8)
        }
    }

    private var automationStatusIcon: String {
        switch model.automationStatus {
        case .granted: return "checkmark.shield.fill"
        case .denied: return "xmark.shield.fill"
        case .notDetermined: return "shield.lefthalf.filled"
        }
    }

    private var automationStatusText: String {
        switch model.automationStatus {
        case .granted: return localization.string("permission.granted")
        case .denied: return localization.string("permission.denied")
        case .notDetermined: return localization.string("permission.not_granted")
        }
    }
}

private struct NotificationPositionSelector: View {
    @Binding var selection: TrackNotificationPosition
    @ObservedObject private var localization = LocalizationManager.shared
    @State private var hoveredPosition: TrackNotificationPosition?

    private let rows: [[TrackNotificationPosition?]] = [
        [.topLeading, .top, .topTrailing],
        [.leading, nil, .trailing],
        [.bottomLeading, .bottom, .bottomTrailing]
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                Circle().fill(.white.opacity(0.22)).frame(width: 5, height: 5)
                Circle().fill(.white.opacity(0.14)).frame(width: 5, height: 5)
                Circle().fill(.white.opacity(0.10)).frame(width: 5, height: 5)
                Spacer()
                Text(localization.string("settings.notification_position"))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.38))
                Spacer()
                Circle().fill(.white.opacity(0.12)).frame(width: 6, height: 6)
            }
            .padding(.horizontal, 13)
            .frame(height: 27)
            .background(.white.opacity(0.035))

            VStack(spacing: 9) {
                ForEach(rows.indices, id: \.self) { rowIndex in
                    HStack(spacing: 9) {
                        ForEach(rows[rowIndex].indices, id: \.self) { columnIndex in
                            if let position = rows[rowIndex][columnIndex] {
                                positionButton(position)
                            } else {
                                centerPlaceholder
                            }
                        }
                    }
                }
            }
            .padding(11)
        }
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.025, green: 0.035, blue: 0.08), Color.black.opacity(0.88)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(SongletonTheme.cyan.opacity(0.28), lineWidth: 1)
                }
        }
        .frame(height: 214)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(localization.string("settings.notification_position"))
    }

    private func positionButton(_ position: TrackNotificationPosition) -> some View {
        Button {
            withAnimation(.spring(response: 0.30, dampingFraction: 0.74)) {
                selection = position
            }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: position.iconName)
                    .font(.system(size: 14, weight: .bold))

                Text(localization.string(position.localizationKey))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(selection == position ? .black : .white.opacity(hoveredPosition == position ? 0.92 : 0.66))
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                selection == position ? SongletonTheme.cyan : SongletonTheme.cyan.opacity(hoveredPosition == position ? 0.16 : 0.055),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(selection == position ? .white.opacity(0.42) : .white.opacity(0.10), lineWidth: 1)
            }
            .shadow(color: selection == position ? SongletonTheme.cyan.opacity(0.28) : .clear, radius: 7, y: 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hoveredPosition = $0 ? position : nil }
        .accessibilityLabel(localization.string(position.localizationKey))
        .accessibilityValue(selection == position ? localization.string("common.selected") : "")
        .accessibilityAddTraits(selection == position ? .isSelected : [])
    }

    private var centerPlaceholder: some View {
        VStack(spacing: 4) {
            Image(systemName: "macbook")
                .font(.system(size: 18, weight: .medium))
            Text(localization.string("settings.notification_position_hint"))
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.white.opacity(0.20))
        .frame(maxWidth: .infinity, minHeight: 52)
    }
}

private struct NotificationAppearancePreview: View {
    @ObservedObject private var localization = LocalizationManager.shared

    var body: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.08, green: 0.12, blue: 0.21), Color.black.opacity(0.92)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 64)
            .overlay(alignment: .leading) {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(SongletonTheme.accentGradient)
                        .frame(width: 42, height: 42)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                        }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(localization.string("notification.preview_track"))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(localization.string("notification.preview_artist"))
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(.horizontal, 11)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(SongletonTheme.cyan.opacity(0.24), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: SongletonTheme.cyan.opacity(0.20), radius: 12, y: 5)
    }
}
