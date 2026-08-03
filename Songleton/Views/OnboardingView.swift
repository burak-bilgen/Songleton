import AppKit
import SwiftUI

// MARK: - OnboardingView

struct OnboardingView: View {
    @ObservedObject var model: NowPlayingModel
    @ObservedObject private var localization = LocalizationManager.shared
    let onFinish: () -> Void

    @State private var step: Step = .welcome
    @State private var animateIcon = false
    @State private var hoveredCard: Int? = nil
    @State private var transitionDirection: Edge = .trailing

    enum Step: Int, CaseIterable {
        case welcome = 0
        case hoverAndTriggers = 1
        case ambientMode = 2
        case gestures = 3
        case permissions = 4
    }

    var body: some View {
        ZStack {
            SongletonTheme.background.ignoresSafeArea()

            Circle()
                .fill(SongletonTheme.cyan.opacity(0.04))
                .frame(width: 320, height: 320)
                .blur(radius: 80)
                .offset(x: -180, y: -240)

            Circle()
                .fill(SongletonTheme.violet.opacity(0.04))
                .frame(width: 300, height: 300)
                .blur(radius: 90)
                .offset(x: 190, y: 250)

            VStack(spacing: 0) {
                // Top Progress Bar & Navigation Header
                headerView
                    .padding(.top, 22)
                    .padding(.horizontal, 24)

                Spacer(minLength: 12)

                // Step Pages Content
                ZStack {
                    switch step {
                    case .welcome:
                        welcomeStepView
                            .transition(pageTransition)
                    case .hoverAndTriggers:
                        hoverStepView
                            .transition(pageTransition)
                    case .ambientMode:
                        ambientStepView
                            .transition(pageTransition)
                    case .gestures:
                        gesturesStepView
                            .transition(pageTransition)
                    case .permissions:
                        permissionsStepView
                            .transition(pageTransition)
                    }
                }
                .padding(.horizontal, 28)

                Spacer(minLength: 12)
            }
        }
        .frame(width: 540, height: 680)
        .onAppear {
            model.checkAutomationPermission(askUser: false)
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                animateIcon = true
            }
        }
    }

    // MARK: - Navigation Header & Indicator

    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                if step != .welcome {
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            move(to: Step(rawValue: step.rawValue - 1)!)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .bold))
                            Text(localization.string("common.back"))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.06), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                if step != .permissions {
                    Button(localization.string("onboarding.skip"), action: onFinish)
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                }

                Text("\(step.rawValue + 1) / \(Step.allCases.count)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
            }

            // Progress Indicators
            HStack(spacing: 6) {
                ForEach(Step.allCases, id: \.rawValue) { s in
                    Capsule()
                        .fill(step.rawValue >= s.rawValue ? SongletonTheme.accentGradient : LinearGradient(colors: [Color.white.opacity(0.1)], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 4)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: step)
                }
            }
        }
    }

    // MARK: - Step 1: Welcome

    private var welcomeStepView: some View {
        VStack(spacing: 20) {
            // App Icon Badge
            ZStack {
                Circle()
                    .fill(SongletonTheme.violet.opacity(0.18))
                    .frame(width: 90, height: 90)
                    .scaleEffect(animateIcon ? 1.06 : 0.96)

                if let icon = NSImage(named: NSImage.applicationIconName) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 76, height: 76)
                        .shadow(color: SongletonTheme.cyan.opacity(0.35), radius: 14, y: 6)
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(SongletonTheme.cyan)
                }
            }

            VStack(spacing: 6) {
                Text(localization.string("onboarding.step_1_title"))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(localization.string("onboarding.step_1_subtitle"))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            VStack(spacing: 10) {
                featureCard(
                    id: 1,
                    icon: "menubar.rectangle",
                    color: SongletonTheme.cyan,
                    title: localization.string("onboarding.feature_live_title"),
                    desc: localization.string("onboarding.feature_live_hint")
                )

                featureCard(
                    id: 2,
                    icon: "sparkles",
                    color: SongletonTheme.violet,
                    title: localization.string("onboarding.feature_lyrics_title"),
                    desc: localization.string("onboarding.feature_lyrics_hint")
                )

                featureCard(
                    id: 3,
                    icon: "bolt.horizontal.fill",
                    color: SongletonTheme.pink,
                    title: localization.string("onboarding.feature_control_title"),
                    desc: localization.string("onboarding.feature_control_hint")
                )
            }

            Spacer(minLength: 4)

            actionButton(title: localization.string("common.continue"), color: SongletonTheme.cyan) {
                move(to: .hoverAndTriggers)
            }
        }
    }

    // MARK: - Step 2: Hover Panel & Triggers

    private var hoverStepView: some View {
        VStack(spacing: 18) {
            badgeIcon("hand.point.up.left.fill", color: SongletonTheme.cyan)

            VStack(spacing: 6) {
                Text(localization.string("onboarding.step_2_title"))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(localization.string("onboarding.step_2_subtitle"))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                featureCard(
                    id: 4,
                    icon: "computermouse.fill",
                    color: SongletonTheme.cyan,
                    title: localization.string("onboarding.right_click_title"),
                    desc: localization.string("onboarding.right_click_hint")
                )

                featureCard(
                    id: 5,
                    icon: "hand.tap.fill",
                    color: SongletonTheme.violet,
                    title: localization.string("onboarding.double_click_title"),
                    desc: localization.string("onboarding.double_click_hint")
                )

                featureCard(
                    id: 6,
                    icon: "doc.on.doc.fill",
                    color: SongletonTheme.pink,
                    title: localization.string("onboarding.tip_copy_title"),
                    desc: localization.string("onboarding.tip_copy_hint")
                )
            }

            Spacer(minLength: 4)

            actionButton(title: localization.string("common.continue"), color: SongletonTheme.cyan) {
                move(to: .ambientMode)
            }
        }
    }

    // MARK: - Step 3: Ambient Mode & Shortcuts

    private var ambientStepView: some View {
        VStack(spacing: 16) {
            badgeIcon("sparkles.tv.fill", color: SongletonTheme.violet)

            VStack(spacing: 4) {
                Text(localization.string("onboarding.step_3_title"))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(localization.string("onboarding.step_3_subtitle"))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            }

            // Keyboard Shortcuts Showcase Grid
            VStack(spacing: 6) {
                shortcutRow(keys: [keyCapView("Space", width: 50)], desc: localization.string("shortcut.play_pause"))
                shortcutRow(keys: [keyCapView("←"), keyCapView("→")], desc: localization.string("shortcut.prev_next_track"))
                shortcutRow(keys: [keyCapView("↑"), keyCapView("↓")], desc: localization.string("shortcut.volume_control"))
                shortcutRow(keys: [keyCapView("L")], desc: localization.string("shortcut.toggle_lyrics"))
                shortcutRow(keys: [keyCapView("T")], desc: localization.string("shortcut.cycle_themes"))
                shortcutRow(keys: [keyCapView("ESC")], desc: localization.string("shortcut.exit_ambient"))
            }
            .padding(12)
            .background(SongletonTheme.card.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))

            Spacer(minLength: 4)

            actionButton(title: localization.string("common.continue"), color: SongletonTheme.violet) {
                move(to: .gestures)
            }
        }
    }

    // MARK: - Step 4: Screen Edge & Mouse Gestures

    private var gesturesStepView: some View {
        VStack(spacing: 16) {
            badgeIcon("hand.raised.fill", color: SongletonTheme.pink)

            VStack(spacing: 4) {
                Text(localization.string("onboarding.step_4_title"))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(localization.string("onboarding.step_4_subtitle"))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 8) {
                gestureItem(badge: "👈", title: localization.string("gesture.left_action"), desc: gestureDescription("gesture.left_desc"))
                gestureItem(badge: "👉", title: localization.string("gesture.right_action"), desc: gestureDescription("gesture.right_desc"))
                gestureItem(badge: "👆", title: localization.string("gesture.top_action"), desc: gestureDescription("gesture.top_desc"))
                gestureItem(badge: "🎚️", title: localization.string("gesture.volume_action"), desc: localization.string("gesture.volume_desc"))
            }

            Spacer(minLength: 4)

            actionButton(title: localization.string("common.continue"), color: SongletonTheme.pink) {
                move(to: .permissions)
            }
        }
    }

    // MARK: - Step 5: Permissions & Launch

    private var permissionsStepView: some View {
        VStack(spacing: 18) {
            badgeIcon(automationStatusIcon, color: automationStatusColor)

            VStack(spacing: 6) {
                Text(localization.string("onboarding.step_5_title"))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(localization.string("onboarding.step_5_subtitle"))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                playerPermissionCard(appName: "Spotify", bundleID: "com.spotify.client", iconName: "music.note.list", color: .green)
                playerPermissionCard(appName: "Apple Music", bundleID: "com.apple.Music", iconName: "music.note", color: .pink)
                accessibilityPermissionCard
            }

            Spacer(minLength: 4)

            VStack(spacing: 8) {
                actionButton(title: localization.string("common.start"), color: SongletonTheme.cyan, action: onFinish)

                if model.automationStatus != .granted {
                    Button(action: model.requestPermissionByScript) {
                        Text(localization.string("permission.request_all"))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Reusable UI Components

    private var pageTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: transitionDirection).combined(with: .opacity),
            removal: .move(edge: transitionDirection == .trailing ? .leading : .trailing).combined(with: .opacity)
        )
    }

    private func move(to nextStep: Step) {
        transitionDirection = nextStep.rawValue > step.rawValue ? .trailing : .leading
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            step = nextStep
        }
    }

    private func badgeIcon(_ systemName: String, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.16))
                .frame(width: 72, height: 72)
            Image(systemName: systemName)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(color)
        }
    }

    private func featureCard(id: Int, icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.16))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(desc)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(SongletonTheme.card.opacity(hoveredCard == id ? 0.9 : 0.68))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(hoveredCard == id ? color.opacity(0.38) : Color.white.opacity(0.08), lineWidth: 1)
        )
        .onHover { isHovered in
            withAnimation(.easeInOut(duration: 0.2)) {
                hoveredCard = isHovered ? id : nil
            }
        }
    }

    private func gestureItem(badge: String, title: String, desc: String) -> some View {
        HStack(spacing: 10) {
            Text(badge)
                .font(.system(size: 14))
                .frame(width: 28, height: 26)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 0.5))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(desc)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(SongletonTheme.card.opacity(0.65), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    private func gestureDescription(_ key: String) -> String {
        let configuredDuration = SettingsModel.shared.edgeGestureHoldDuration
        let duration = key == "gesture.top_desc"
            ? configuredDuration * 0.8
            : configuredDuration
        return String(format: localization.string(key), String(format: "%.1f", duration))
    }

    private func shortcutRow(keys: [AnyView], desc: String) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                ForEach(0..<keys.count, id: \.self) { idx in
                    keys[idx]
                }
            }
            .frame(width: 76, alignment: .leading)

            Text(desc)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))

            Spacer()
        }
    }

    private func keyCapView(_ text: String, width: CGFloat = 26) -> AnyView {
        AnyView(
            Text(text)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.95))
                .frame(height: 22)
                .frame(minWidth: width)
                .padding(.horizontal, 4)
                .background(
                    LinearGradient(
                        colors: [Color(white: 0.24), Color(white: 0.12)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.40), .white.opacity(0.10)],
                                startPoint: .top, endPoint: .bottom
                            ),
                            lineWidth: 0.8
                        )
                )
        )
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
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(statusText(for: status))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
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
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(SongletonTheme.cyan, in: Capsule())
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(SongletonTheme.card.opacity(0.68), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    private var accessibilityPermissionCard: some View {
        let isGranted = MouseGestureManager.shared.isAccessibilityTrusted
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(SongletonTheme.violet.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(SongletonTheme.violet)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(localization.string("permission.accessibility"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(isGranted ? localization.string("permission.granted") : localization.string("permission.not_granted"))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(isGranted ? .green : .white.opacity(0.4))
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.green)
            } else {
                Button(action: requestAccessibilityPermission) {
                    Text(localization.string("permission.open_accessibility"))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(SongletonTheme.violet, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(SongletonTheme.card.opacity(0.68), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    private func requestAccessibilityPermission() {
        MouseGestureManager.shared.requestAccessibilityAccess()
        MouseGestureManager.shared.updateMonitoring()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func actionButton(title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    LinearGradient(
                        colors: [color, color.opacity(0.78)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .foregroundStyle(.black.opacity(0.88))
                .shadow(color: color.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

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
        case .notDetermined: .white.opacity(0.4)
        }
    }
}
