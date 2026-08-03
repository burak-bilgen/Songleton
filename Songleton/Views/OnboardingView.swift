import AppKit
import SwiftUI

// MARK: - OnboardingView

struct OnboardingView: View {
    @ObservedObject var model: NowPlayingModel
    @ObservedObject private var localization = LocalizationManager.shared
    let onFinish: () -> Void

    @State private var step: Step = .welcome
    @State private var appeared = false
    @State private var pulseIcon = false
    @State private var rotateRing = false
    @State private var noteFloat = false
    @State private var auroraDrift = false
    @State private var hoveredCard: Int? = nil
    @State private var transitionDirection: Edge = .trailing
    @State private var checkmarkPop = false

    enum Step: Int, CaseIterable {
        case welcome = 0
        case hoverAndTriggers = 1
        case ambientMode = 2
        case gestures = 3
        case permissions = 4
    }

    var body: some View {
        ZStack {
            backgroundView

            VStack(spacing: 0) {
                headerView
                    .padding(.top, 30)
                    .padding(.horizontal, 26)

                Spacer(minLength: 10)

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
                .padding(.horizontal, 26)
                .padding(.top, 6)

                Spacer(minLength: 10)
            }
        }
        .frame(width: 540, height: 680)
        .onAppear {
            model.checkAutomationPermission(askUser: false)
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulseIcon = true
            }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                noteFloat = true
            }
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                auroraDrift = true
            }
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.7)) {
                    rotateRing = true
                }
                withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                    appeared = true
                }
            }
        }
    }

    // MARK: - Background

    private var backgroundView: some View {
        ZStack {
            SongletonTheme.background.ignoresSafeArea()

            Circle()
                .fill(SongletonTheme.cyan.opacity(0.05))
                .frame(width: 400, height: 400)
                .blur(radius: 90)
                .offset(x: auroraDrift ? -170 : -200, y: -250)

            Circle()
                .fill(SongletonTheme.violet.opacity(0.06))
                .frame(width: 360, height: 360)
                .blur(radius: 100)
                .offset(x: auroraDrift ? 210 : 180, y: auroraDrift ? 230 : 270)

            Circle()
                .fill(SongletonTheme.pink.opacity(0.035))
                .frame(width: 300, height: 300)
                .blur(radius: 90)
                .offset(x: auroraDrift ? 40 : 80, y: auroraDrift ? -180 : -220)

            LinearGradient(
                colors: [.clear, SongletonTheme.background.opacity(0.55)],
                startPoint: .center,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .animation(.easeInOut(duration: 9).repeatForever(autoreverses: true), value: auroraDrift)
    }

    // MARK: - Navigation Header & Indicator

    private var headerView: some View {
        VStack(spacing: 14) {
            HStack {
                if step != .welcome {
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            move(to: Step(rawValue: step.rawValue - 1)!)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 10, weight: .bold))
                            Text(localization.string("common.back"))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.07), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .entrance(0, appeared: appeared, delay: 0)
                }

                Spacer()

                if step != .permissions {
                    Button(localization.string("onboarding.skip"), action: onFinish)
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            HStack(spacing: 6) {
                ForEach(Step.allCases, id: \.rawValue) { s in
                    progressSegment(for: s)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: step)
                }
            }
        }
    }

    private func progressSegment(for s: Step) -> some View {
        let fill: LinearGradient
        if step.rawValue > s.rawValue {
            fill = SongletonTheme.accentGradient
        } else if step.rawValue == s.rawValue {
            fill = LinearGradient(
                colors: [SongletonTheme.cyan.opacity(0.85), SongletonTheme.violet.opacity(0.85)],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            fill = LinearGradient(colors: [Color.white.opacity(0.09)], startPoint: .leading, endPoint: .trailing)
        }

        return Capsule()
            .fill(fill)
            .frame(height: 4)
            .overlay(
                Capsule().stroke(
                    step.rawValue == s.rawValue ? SongletonTheme.cyan.opacity(0.35) : Color.clear,
                    lineWidth: 1
                )
            )
    }

    // MARK: - Step 1: Welcome

    private var welcomeStepView: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [SongletonTheme.cyan.opacity(0.30), SongletonTheme.violet.opacity(0.30)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 158, height: 158)
                    .blur(radius: 30)
                    .scaleEffect(pulseIcon ? 1.2 : 0.92)
                    .opacity(pulseIcon ? 0.9 : 0.6)

                Circle()
                    .strokeBorder(
                        AngularGradient(
                            colors: [SongletonTheme.cyan, .clear, SongletonTheme.violet, SongletonTheme.pink.opacity(0.6), .clear],
                            center: .center
                        ),
                        lineWidth: 2.5
                    )
                    .frame(width: 128, height: 128)
                    .rotationEffect(.degrees(rotateRing ? 360 : 0))
                    .shadow(color: SongletonTheme.violet.opacity(0.45), radius: 10)

                Circle()
                    .fill(SongletonTheme.card)
                    .frame(width: 96, height: 96)
                    .shadow(color: .black.opacity(0.6), radius: 14, y: 4)

                if let icon = NSImage(named: NSImage.applicationIconName) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 88, height: 88)
                        .clipShape(Circle())
                        .scaleEffect(pulseIcon ? 1.04 : 0.97)
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(SongletonTheme.cyan)
                }

                floatingNote("music.note", x: -66, y: -14, duration: 2.3)
                floatingNote("music.quarternote.3", x: 64, y: 10, duration: 3.1)
            }
            .frame(height: 158)
            .entrance(0, appeared: appeared)

            VStack(spacing: 8) {
                Text(localization.string("onboarding.step_1_title"))
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, SongletonTheme.cyan.opacity(0.95), SongletonTheme.violet.opacity(0.95)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text(localization.string("onboarding.step_1_subtitle"))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .entrance(1, appeared: appeared)

            VStack(spacing: 10) {
                featureCard(
                    id: 1,
                    icon: "menubar.rectangle",
                    color: SongletonTheme.cyan,
                    title: localization.string("onboarding.feature_live_title"),
                    desc: localization.string("onboarding.feature_live_hint")
                )
                .entrance(2, appeared: appeared)

                featureCard(
                    id: 2,
                    icon: "sparkles",
                    color: SongletonTheme.violet,
                    title: localization.string("onboarding.feature_lyrics_title"),
                    desc: localization.string("onboarding.feature_lyrics_hint")
                )
                .entrance(3, appeared: appeared)

                featureCard(
                    id: 3,
                    icon: "bolt.horizontal.fill",
                    color: SongletonTheme.pink,
                    title: localization.string("onboarding.feature_control_title"),
                    desc: localization.string("onboarding.feature_control_hint")
                )
                .entrance(4, appeared: appeared)
            }

            actionButton(title: localization.string("common.continue"), color: SongletonTheme.cyan) {
                move(to: .hoverAndTriggers)
            }
            .entrance(5, appeared: appeared)
            .modifier(GlowPulse(pulse: pulseIcon))
        }
    }

    // MARK: - Step 2: Hover Panel & Triggers

    private var hoverStepView: some View {
        VStack(spacing: 20) {
            badgeIcon("hand.point.up.left.fill", color: SongletonTheme.cyan)
                .entrance(0, appeared: appeared)

            VStack(spacing: 6) {
                Text(localization.string("onboarding.step_2_title"))
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(localization.string("onboarding.step_2_subtitle"))
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .entrance(1, appeared: appeared)

            VStack(spacing: 10) {
                featureCard(
                    id: 4,
                    icon: "computermouse.fill",
                    color: SongletonTheme.cyan,
                    title: localization.string("onboarding.right_click_title"),
                    desc: localization.string("onboarding.right_click_hint")
                )
                .entrance(2, appeared: appeared)

                featureCard(
                    id: 5,
                    icon: "hand.tap.fill",
                    color: SongletonTheme.violet,
                    title: localization.string("onboarding.double_click_title"),
                    desc: localization.string("onboarding.double_click_hint")
                )
                .entrance(3, appeared: appeared)

                featureCard(
                    id: 6,
                    icon: "doc.on.doc.fill",
                    color: SongletonTheme.pink,
                    title: localization.string("onboarding.tip_copy_title"),
                    desc: localization.string("onboarding.tip_copy_hint")
                )
                .entrance(4, appeared: appeared)
            }

            actionButton(title: localization.string("common.continue"), color: SongletonTheme.cyan) {
                move(to: .ambientMode)
            }
            .entrance(5, appeared: appeared)
        }
    }

    // MARK: - Step 3: Ambient Mode & Shortcuts

    private var ambientStepView: some View {
        VStack(spacing: 18) {
            badgeIcon("sparkles.tv.fill", color: SongletonTheme.violet)
                .entrance(0, appeared: appeared)

            VStack(spacing: 4) {
                Text(localization.string("onboarding.step_3_title"))
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(localization.string("onboarding.step_3_subtitle"))
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .entrance(1, appeared: appeared)

            VStack(spacing: 7) {
                shortcutRow(keys: [keyCapView("Space", width: 52)], desc: localization.string("shortcut.play_pause"))
                shortcutRow(keys: [keyCapView("←"), keyCapView("→")], desc: localization.string("shortcut.prev_next_track"))
                shortcutRow(keys: [keyCapView("↑"), keyCapView("↓")], desc: localization.string("shortcut.volume_control"))
                shortcutRow(keys: [keyCapView("L")], desc: localization.string("shortcut.toggle_lyrics"))
                shortcutRow(keys: [keyCapView("T")], desc: localization.string("shortcut.cycle_themes"))
                shortcutRow(keys: [keyCapView("ESC")], desc: localization.string("shortcut.exit_ambient"))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(SongletonTheme.card.opacity(0.75))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [SongletonTheme.violet.opacity(0.22), Color.white.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .entrance(2, appeared: appeared)

            actionButton(title: localization.string("common.continue"), color: SongletonTheme.violet) {
                move(to: .gestures)
            }
            .entrance(3, appeared: appeared)
        }
    }

    // MARK: - Step 4: Screen Edge & Mouse Gestures

    private var gesturesStepView: some View {
        VStack(spacing: 18) {
            badgeIcon("hand.raised.fill", color: SongletonTheme.pink)
                .entrance(0, appeared: appeared)

            VStack(spacing: 4) {
                Text(localization.string("onboarding.step_4_title"))
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(localization.string("onboarding.step_4_subtitle"))
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .entrance(1, appeared: appeared)

            VStack(spacing: 8) {
                gestureItem(
                    icon: "chevron.left",
                    color: SongletonTheme.cyan,
                    title: localization.string("gesture.left_action"),
                    desc: gestureDescription("gesture.left_desc")
                )
                gestureItem(
                    icon: "chevron.right",
                    color: SongletonTheme.violet,
                    title: localization.string("gesture.right_action"),
                    desc: gestureDescription("gesture.right_desc")
                )
                gestureItem(
                    icon: "chevron.up",
                    color: SongletonTheme.pink,
                    title: localization.string("gesture.top_action"),
                    desc: gestureDescription("gesture.top_desc")
                )
                gestureItem(
                    icon: "speaker.wave.2.fill",
                    color: SongletonTheme.cyan,
                    title: localization.string("gesture.volume_action"),
                    desc: localization.string("gesture.volume_desc")
                )
            }
            .entrance(2, appeared: appeared)

            actionButton(title: localization.string("common.continue"), color: SongletonTheme.pink) {
                move(to: .permissions)
            }
            .entrance(3, appeared: appeared)
        }
    }

    // MARK: - Step 5: Permissions & Launch

    private var permissionsStepView: some View {
        VStack(spacing: 20) {
            badgeIcon(automationStatusIcon, color: automationStatusColor)
                .entrance(0, appeared: appeared)

            VStack(spacing: 6) {
                Text(localization.string("onboarding.step_5_title"))
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(localization.string("onboarding.step_5_subtitle"))
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .entrance(1, appeared: appeared)

            VStack(spacing: 10) {
                playerPermissionCard(appName: "Spotify", bundleID: "com.spotify.client", iconName: "music.note.list", color: .green)
                playerPermissionCard(appName: "Apple Music", bundleID: "com.apple.Music", iconName: "music.note", color: .pink)
                accessibilityPermissionCard
            }
            .entrance(2, appeared: appeared)

            VStack(spacing: 10) {
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
            .entrance(3, appeared: appeared)
        }
        .onAppear {
            checkmarkPop = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
                    checkmarkPop = true
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
        appeared = false
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            step = nextStep
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.9)) {
                appeared = true
            }
        }
    }

    private func floatingNote(_ systemName: String, x: CGFloat, y: CGFloat, duration: Double) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white.opacity(0.25))
            .offset(x: x, y: y + (noteFloat ? -11 : 11))
            .animation(.easeInOut(duration: duration).repeatForever(autoreverses: true), value: noteFloat)
    }

    private func badgeIcon(_ systemName: String, color: Color) -> some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.45), lineWidth: 2)
                .frame(width: 92, height: 92)
                .scaleEffect(pulseIcon ? 1.14 : 0.98)
                .opacity(pulseIcon ? 0.12 : 0.55)

            Circle()
                .fill(color.opacity(0.16))
                .frame(width: 72, height: 72)
                .shadow(color: color.opacity(0.22), radius: 10)

            Image(systemName: systemName)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(color)
        }
        .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: pulseIcon)
    }

    private func featureCard(id: Int, icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.16))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(desc)
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineSpacing(1)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(SongletonTheme.card.opacity(hoveredCard == id ? 0.92 : 0.68))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(hoveredCard == id ? color.opacity(0.4) : Color.white.opacity(0.07), lineWidth: 1)
        )
        .shadow(color: hoveredCard == id ? color.opacity(0.12) : .clear, radius: 8, y: 3)
        .scaleEffect(hoveredCard == id ? 1.02 : 1)
        .onHover { isHovered in
            withAnimation(.easeInOut(duration: 0.2)) {
                hoveredCard = isHovered ? id : nil
            }
        }
    }

    private func gestureItem(icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.14))
                    .frame(width: 34, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(color)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(color.opacity(0.28), lineWidth: 0.8)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(desc)
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineSpacing(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(SongletonTheme.card.opacity(0.65), in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color.white.opacity(0.06), lineWidth: 1))
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
            .frame(width: 80, alignment: .leading)

            Text(desc)
                .font(.system(size: 11.5, weight: .medium, design: .rounded))
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
                        colors: [Color(white: 0.26), Color(white: 0.13)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.45), .white.opacity(0.10)],
                                startPoint: .top, endPoint: .bottom
                            ),
                            lineWidth: 0.8
                        )
                )
                .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
        )
    }

    private func playerPermissionCard(appName: String, bundleID: String, iconName: String, color: Color) -> some View {
        let status = model.permissionStatus(for: bundleID)
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
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
                    .scaleEffect(checkmarkPop ? 1 : 0.5)
                    .opacity(checkmarkPop ? 1 : 0)
                    .shadow(color: .green.opacity(0.45), radius: checkmarkPop ? 6 : 0)
            } else {
                Button(action: {
                    model.requestPermissionFor(bundleID: bundleID)
                }) {
                    Text(localization.string("permission.grant"))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(
                                colors: [color.opacity(0.9), color.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: Capsule()
                        )
                        .foregroundStyle(.black.opacity(0.85))
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
                    .frame(width: 36, height: 36)
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
                    .scaleEffect(checkmarkPop ? 1 : 0.5)
                    .opacity(checkmarkPop ? 1 : 0)
                    .shadow(color: .green.opacity(0.45), radius: checkmarkPop ? 6 : 0)
            } else {
                Button(action: requestAccessibilityPermission) {
                    Text(localization.string("permission.open_accessibility"))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(
                                colors: [SongletonTheme.violet, SongletonTheme.violet.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: Capsule()
                        )
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
                .shadow(color: color.opacity(0.28), radius: 8, y: 4)
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

// MARK: - Entrance & Glow Helpers

private struct EntranceModifier: ViewModifier {
    let index: Int
    let appeared: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .scaleEffect(appeared ? 1 : 0.97, anchor: .center)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.85)
                    .delay(delay + Double(index) * 0.07),
                value: appeared
            )
    }
}

private struct GlowPulse: ViewModifier {
    let pulse: Bool

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(SongletonTheme.cyan.opacity(pulse ? 0.55 : 0.15), lineWidth: 1.5)
                    .scaleEffect(pulse ? 1.03 : 0.99)
                    .blur(radius: 1)
            )
            .shadow(color: SongletonTheme.cyan.opacity(pulse ? 0.4 : 0.15), radius: pulse ? 12 : 6, y: 0)
            .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: pulse)
    }
}

private extension View {
    func entrance(_ index: Int, appeared: Bool, delay: Double = 0.04) -> some View {
        modifier(EntranceModifier(index: index, appeared: appeared, delay: delay))
    }
}
