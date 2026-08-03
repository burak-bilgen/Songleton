import SwiftUI

// MARK: - OnboardingView

struct OnboardingView: View {
    @ObservedObject var model: NowPlayingModel
    @ObservedObject private var localization = LocalizationManager.shared
    let onFinish: () -> Void

    @State private var step: Step = .welcome
    @State private var animateIcon = false
    @State private var hoveredCard: Int? = nil

    enum Step { case welcome, permission, ready }

    var body: some View {
        ZStack {
            // Modern gradient backdrop
            LinearGradient(
                colors: [
                    SongletonTheme.background,
                    SongletonTheme.violet.opacity(0.16),
                    SongletonTheme.panelTop
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(SongletonTheme.cyan.opacity(0.1))
                .frame(width: 280, height: 280)
                .blur(radius: 70)
                .offset(x: -170, y: -260)

            Circle()
                .fill(SongletonTheme.violet.opacity(0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 80)
                .offset(x: 180, y: 260)

            VStack(spacing: 0) {
                // Header drag area & step indicator
                headerView
                    .padding(.top, 24)
                    .padding(.horizontal, 24)

                Spacer(minLength: 12)

                // Animated step views
                ZStack {
                    switch step {
                    case .welcome:
                        welcomeView
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    case .permission:
                        permissionView
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    case .ready:
                        readyView
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
                .padding(.horizontal, 32)

                Spacer(minLength: 12)
            }
        }
        .frame(width: 520, height: 660)
        .onAppear {
            model.checkAutomationPermission(askUser: false)
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                animateIcon = true
            }
        }
    }

    private var stepIndex: Int {
        switch step {
        case .welcome: 0
        case .permission: 1
        case .ready: 2
        }
    }

    // MARK: - Header & Step Indicator

    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                if step != .welcome {
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            step = (step == .ready) ? .permission : .welcome
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .bold))
                            Text(localization.string("common.back"))
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.primary.opacity(0.06), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Text("\(stepIndex + 1) / 3")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            // Step Progress Bar
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(stepIndex >= i ? SongletonTheme.accentGradient : LinearGradient(colors: [Color.white.opacity(0.1)], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 4)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: stepIndex)
                }
            }
        }
    }

    // MARK: - 1. Welcome Step

    private var welcomeView: some View {
        VStack(spacing: 22) {
            // Hero Icon
            ZStack {
                Circle()
                    .fill(SongletonTheme.violet.opacity(0.18))
                    .frame(width: 96, height: 96)
                    .scaleEffect(animateIcon ? 1.06 : 0.96)

                if let icon = NSImage(named: NSImage.applicationIconName) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 80, height: 80)
                        .shadow(color: SongletonTheme.cyan.opacity(0.35), radius: 14, y: 6)
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }

            // Title & Description (No Overflow)
            VStack(spacing: 8) {
                Text(localization.string("onboarding.welcome"))
                    .font(.system(size: 22, weight: .bold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(localization.string("onboarding.welcome_hint"))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Feature Cards
            VStack(spacing: 10) {
                featureCard(
                    id: 1,
                    icon: "music.note.house.fill",
                    color: SongletonTheme.pink,
                    title: localization.string("onboarding.feature_live_title"),
                    desc: localization.string("onboarding.feature_live_hint")
                )
                featureCard(
                    id: 2,
                    icon: "playpause.circle.fill",
                    color: SongletonTheme.cyan,
                    title: localization.string("onboarding.feature_control_title"),
                    desc: localization.string("onboarding.feature_control_hint")
                )
                featureCard(
                    id: 3,
                    icon: "quote.bubble.fill",
                    color: SongletonTheme.violet,
                    title: localization.string("onboarding.feature_lyrics_title"),
                    desc: localization.string("onboarding.feature_lyrics_hint")
                )
            }

            Spacer(minLength: 4)

            // Primary Button
            actionButton(title: localization.string("common.continue"), color: .accentColor) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    step = .permission
                }
            }
        }
    }

    private func featureCard(id: Int, icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.16))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(SongletonTheme.card.opacity(hoveredCard == id ? 0.9 : 0.68))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(hoveredCard == id ? color.opacity(0.38) : Color.white.opacity(0.08), lineWidth: 1)
        )
        .onHover { isHovered in
            withAnimation(.easeInOut(duration: 0.2)) {
                hoveredCard = isHovered ? id : nil
            }
        }
    }

    // MARK: - 2. Permission Step

    private var permissionView: some View {
        VStack(spacing: 20) {
            // Header Icon
            ZStack {
                Circle()
                    .fill(automationStatusColor.opacity(0.14))
                    .frame(width: 80, height: 80)
                Image(systemName: automationStatusIcon)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(automationStatusColor)
            }

            VStack(spacing: 8) {
                Text(localization.string("permission.automation"))
                    .font(.system(size: 20, weight: .bold))

             Text(localization.string("permission.onboarding_explanation"))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                     .fixedSize(horizontal: false, vertical: true)

                Text(localization.string("permission.onboarding_privacy"))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.48))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
             }

            // Per-Player Permission List
            VStack(spacing: 10) {
                playerPermissionCard(
                    appName: "Spotify",
                    bundleID: "com.spotify.client",
                    iconName: "music.note.list",
                    color: .green
                )

                playerPermissionCard(
                    appName: "Apple Music",
                    bundleID: "com.apple.Music",
                    iconName: "music.note",
                    color: .pink
                )
            }

            // Global System Settings Link
            if model.automationStatus != .granted {
                Button(action: { openAutomationSettings() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape.fill")
                        Text(localization.string("permission.settings_path"))
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SongletonTheme.cyan)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(SongletonTheme.cyan.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 4)

            // Bottom Actions
            VStack(spacing: 8) {
                actionButton(
                    title: model.automationStatus == .granted ? localization.string("common.continue") : localization.string("permission.request_all"),
                    color: .accentColor
                ) {
                    if model.automationStatus == .granted {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { step = .ready }
                    } else {
                        model.requestPermissionByScript()
                    }
                }

                if model.automationStatus != .granted {
                    Button(action: {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { step = .ready }
                    }) {
                        Text(localization.string("permission.skip"))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear {
            model.checkAutomationPermission(askUser: false)
        }
    }

    private func playerPermissionCard(appName: String, bundleID: String, iconName: String, color: Color) -> some View {
        let status = model.permissionStatus(for: bundleID)
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: iconName)
                    .font(.system(size: 15))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(appName)
                    .font(.system(size: 13, weight: .semibold))
                Text(statusText(for: status))
                    .font(.system(size: 11))
                    .foregroundStyle(statusColor(for: status))
            }

            Spacer()

            if status == .granted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.green)
            } else {
                Button(action: {
                    model.requestPermissionFor(bundleID: bundleID)
                }) {
                    Text(localization.string("permission.grant"))
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.accentColor, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
                    .background(SongletonTheme.card.opacity(0.68), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.primary.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - 3. Ready Step

    private var readyView: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.16))
                    .frame(width: 88, height: 88)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
            }

            VStack(spacing: 8) {
                Text(localization.string("onboarding.ready"))
                    .font(.system(size: 22, weight: .bold))

                Text(localization.string("onboarding.ready_hint"))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                tipItem(icon: "menubar.rectangle", title: localization.string("onboarding.tip_menu_title"), desc: localization.string("onboarding.tip_menu_hint"))
                tipItem(icon: "music.note", title: localization.string("onboarding.tip_artwork_title"), desc: localization.string("onboarding.tip_artwork_hint"))
                tipItem(icon: "doc.on.doc", title: localization.string("onboarding.tip_copy_title"), desc: localization.string("onboarding.tip_copy_hint"))
            }
            .padding(14)
            .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))

            Spacer(minLength: 4)

            actionButton(title: localization.string("common.start"), color: .green) {
                onFinish()
            }
        }
    }

    private func tipItem(icon: String, title: String, desc: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(SongletonTheme.cyan)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Reusable Action Button

    private func actionButton(title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    LinearGradient(
                        colors: [color, color.opacity(0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .foregroundStyle(.black.opacity(0.82))
                .contentShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: color.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var automationStatusIcon: String {
        switch model.automationStatus {
        case .granted: "checkmark.shield.fill"
        case .denied: "xmark.shield.fill"
        case .notDetermined: "shield.lefthalf.filled"
        }
    }

    private var automationStatusColor: Color {
        switch model.automationStatus {
        case .granted: .green
        case .denied: .red
        case .notDetermined: .orange
        }
    }

    private func statusText(for status: NowPlayingModel.AutomationStatus) -> String {
        switch status {
        case .granted: localization.string("permission.granted")
        case .denied: localization.string("permission.denied")
        case .notDetermined: localization.string("permission.not_granted")
        }
    }

    private func statusColor(for status: NowPlayingModel.AutomationStatus) -> Color {
        switch status {
        case .granted: .green
        case .denied: .red
        case .notDetermined: .secondary
        }
    }

    private func openAutomationSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension"
        ]
        for urlString in urls {
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
                return
            }
        }
    }
}
