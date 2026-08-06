import AppKit
import SwiftUI

// MARK: - OnboardingView

struct OnboardingView: View {
    @ObservedObject var model: NowPlayingModel
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var mouseGestureManager = MouseGestureManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onFinish: () -> Void
    let onAbort: () -> Void

    @State private var step: Step = .welcome
    @State private var appeared = false
    @State private var pulseIcon = false
    @State private var rotateRing = false
    @State private var noteFloat = false
    @State private var auroraDrift = false
    @State private var windowReveal = false
    @State private var hoveredCard: Int? = nil
    @State private var transitionDirection: Edge = .trailing
    @State private var checkmarkPop = false
    @State private var orbitSpin = false
    @State private var orbitReverseSpin = false
    @State private var readyGlow = false

    enum Step: Int, CaseIterable {
        case welcome = 0
        case permissions = 1
    }

    var body: some View {
        ZStack {
            backgroundView

            VStack(spacing: 0) {
                headerView
                    .padding(.top, 10)
                    .padding(.horizontal, 26)

                Spacer(minLength: 10)

                ZStack {
                    switch step {
                    case .welcome:
                        welcomeStepView
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
        .frame(width: 590, height: 740)
        .onAppear {
            model.checkAutomationPermission()
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    pulseIcon = true
                }
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                    noteFloat = true
                }
                withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                    auroraDrift = true
                }
                orbitSpin = true
                orbitReverseSpin = true
            }
            DispatchQueue.main.async {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.7)) {
                    rotateRing = true
                }
                withAnimation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.85)) {
                    appeared = true
                }
                withAnimation(reduceMotion ? nil : .spring(response: 0.65, dampingFraction: 0.82)) {
                    windowReveal = true
                }
            }
        }
        .scaleEffect(windowReveal ? 1 : 0.92)
        .opacity(windowReveal ? 1 : 0)
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
        HStack {
            Spacer()

            Menu {
                Section(localization.string("onboarding.language_picker_title")) {
                    languageMenuOption(.system, title: localization.string("language.system"))
                    languageMenuOption(.english, title: localization.string("language.english"))
                    languageMenuOption(.turkish, title: localization.string("language.turkish"))
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "globe")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(SongletonTheme.cyan)

                    Text(selectedLanguageTitle)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.58))
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
            }
            .menuStyle(.borderlessButton)
            .accessibilityLabel(localization.string("onboarding.language_picker_title"))
        }
    }

    private var selectedLanguageTitle: String {
        switch localization.language {
        case .system:
            return "\(localization.string("language.system")): \(systemLanguageTitle)"
        case .english:
            return localization.string("language.english")
        case .turkish:
            return localization.string("language.turkish")
        }
    }

    private var systemLanguageTitle: String {
        switch localization.resolvedLanguageCode {
        case "tr": return localization.string("language.turkish")
        default: return localization.string("language.english")
        }
    }

    private func languageMenuOption(_ language: LocalizationManager.Language, title: String) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                localization.language = language
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: language == .system ? "desktopcomputer" : "textformat")
                    .foregroundStyle(language == localization.language ? SongletonTheme.cyan : .secondary)
                Text(title)
                Spacer()
                if language == localization.language {
                    Image(systemName: "checkmark")
                }
            }
        }
    }

    // MARK: - Step 1: Welcome

    private var welcomeStepView: some View {
        VStack(spacing: 16) {
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
                    .strokeBorder(Color.white.opacity(0.22), style: StrokeStyle(lineWidth: 1.2, dash: [2.5, 10]))
                    .frame(width: 156, height: 156)
                    .rotationEffect(.degrees(orbitSpin ? 360 : 0))
                    .shadow(color: SongletonTheme.cyan.opacity(0.35), radius: 8)
                    .animation(.linear(duration: 22).repeatForever(autoreverses: false), value: orbitSpin)

                Circle()
                    .strokeBorder(Color.white.opacity(0.13), style: StrokeStyle(lineWidth: 1, dash: [1.5, 14]))
                    .frame(width: 172, height: 172)
                    .rotationEffect(.degrees(orbitReverseSpin ? -360 : 0))
                    .opacity(orbitReverseSpin ? 1 : 0)
                    .animation(.linear(duration: 30).repeatForever(autoreverses: false), value: orbitReverseSpin)

                Circle()
                    .fill(SongletonTheme.card)
                    .frame(width: 96, height: 96)
                    .shadow(color: .black.opacity(0.6), radius: 14, y: 4)

                SongletonBrandMark(size: 82)
                    .scaleEffect(pulseIcon ? 1.04 : 0.97)

                floatingNote("music.note", x: -66, y: -14, duration: 2.3)
                floatingNote("music.quarternote.3", x: 64, y: 10, duration: 3.1)
            }
            .frame(height: 158)
            .entrance(0, appeared: appeared)

            VStack(spacing: 8) {
                Text(localization.string("onboarding.screen1_title"))
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, SongletonTheme.cyan.opacity(0.95), SongletonTheme.violet.opacity(0.95)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text(localization.string("onboarding.screen1_subtitle"))
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
                    icon: "hand.point.up.left.fill",
                    color: SongletonTheme.cyan,
                    title: localization.string("onboarding.feature_gestures_title"),
                    desc: localization.string("onboarding.feature_gestures_desc")
                )
                .entrance(2, appeared: appeared)

                featureCard(
                    id: 2,
                    icon: "menubar.rectangle",
                    color: SongletonTheme.violet,
                    title: localization.string("onboarding.feature_menubar_title"),
                    desc: localization.string("onboarding.feature_menubar_desc")
                )
                .entrance(3, appeared: appeared)

                featureCard(
                    id: 3,
                    icon: "sparkles.tv.fill",
                    color: SongletonTheme.pink,
                    title: localization.string("onboarding.feature_ambient_title"),
                    desc: localization.string("onboarding.feature_ambient_desc")
                )
                .entrance(4, appeared: appeared)
            }

            actionButton(title: localization.string("common.continue"), color: SongletonTheme.cyan) {
                move(to: .permissions)
            }
            .entrance(5, appeared: appeared)
            .modifier(GlowPulse(pulse: pulseIcon))
        }
    }

    // MARK: - Step 2: Permissions & Launch

    private var permissionsStepView: some View {
        // Compute the installed set once per render instead of re-running
        // LaunchServices lookups for every subview.
        let installed = model.installedControllers
        let ungrantedCount = installed.filter { model.permissionStatus(for: $0.bundleID) != .granted }.count
        return VStack(spacing: 20) {
            badgeIcon(automationStatusIcon, color: automationStatusColor)
                .entrance(0, appeared: appeared)

            VStack(spacing: 6) {
                Text(localization.string("onboarding.screen2_title"))
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(localization.string("onboarding.screen2_subtitle"))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .entrance(1, appeared: appeared)

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 8) {
                        accessibilityPermissionCard
                        if installed.isEmpty {
                            noSupportedPlayersCard
                        } else {
                            ForEach(installed, id: \.bundleID) { controller in
                                playerPermissionCard(
                                    appName: controller.displayName,
                                    bundleID: controller.bundleID,
                                    color: playerColor(for: controller.bundleID)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                    .id("permissionListTop")
                }
                .frame(maxHeight: 310)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        withAnimation(nil) {
                            proxy.scrollTo("permissionListTop", anchor: .top)
                        }
                    }
                }
            }
            .entranceFade(2, appeared: appeared)

            VStack(spacing: 10) {
                if ungrantedCount > 0 {
                    // Shown once for the whole list, not repeated per player card.
                    Text(localization.string("onboarding.permission_automation_hint"))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    grantAllButton(ungrantedCount: ungrantedCount)
                }

                let isGranted = model.automationStatus == .granted
                actionButton(
                    title: localization.string("common.start"),
                    color: isGranted ? SongletonTheme.cyan : .gray,
                    action: onFinish
                )
                .disabled(!isGranted)
                .opacity(isGranted ? 1.0 : 0.45)
                .modifier(GlowPulse(pulse: isGranted && readyGlow, color: .green))

                if !isGranted {
                    Button(action: onAbort) {
                        Text(localization.string("onboarding.skip"))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.48))
                    }
                    .buttonStyle(.plain)
                }
            }
            .entrance(3, appeared: appeared)
        }
        .onAppear {
            checkmarkPop = false
            if model.automationStatus == .granted {
                readyGlow = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
                    checkmarkPop = true
                }
            }
        }
        .onChange(of: model.automationStatus) { _, status in
            guard status == .granted else { return }
            withAnimation(.easeInOut(duration: 0.7)) {
                readyGlow = true
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
        withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85)) {
            step = nextStep
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
            withAnimation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.9)) {
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

    private func playerPermissionCard(appName: String, bundleID: String, color: Color) -> some View {
        let status = model.permissionStatus(for: bundleID)
        return HStack(spacing: 12) {
            PlatformLogoView(bundleID: bundleID, size: 36)

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
                let isRequesting = model.permissionRequestsInFlight.contains(bundleID)
                Button(action: {
                    model.requestPermissionFor(bundleID: bundleID)
                }) {
                    Group {
                        if isRequesting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text(localization.string("onboarding.connect"))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                    }
                    .frame(minWidth: 52)
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
                .disabled(isRequesting)
            }
        }
        .padding(12)
        .background(SongletonTheme.card.opacity(0.68), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    private func grantAllButton(ungrantedCount: Int) -> some View {
        Button {
            model.requestPermissionsForAllInstalled()
        } label: {
            HStack(spacing: 8) {
                if model.isGrantAllInProgress {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 12, weight: .bold))
                }
                Text(localization.string("onboarding.grant_all"))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                if !model.isGrantAllInProgress, ungrantedCount > 1 {
                    Text(verbatim: "\(ungrantedCount)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.25), in: Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(
                LinearGradient(
                    colors: [SongletonTheme.violet, SongletonTheme.cyan.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            )
            .foregroundStyle(.white)
            .shadow(color: SongletonTheme.violet.opacity(0.30), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(model.isGrantAllInProgress)
        .opacity(model.isGrantAllInProgress ? 0.75 : 1)
    }

    private var noSupportedPlayersCard: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: "music.note.list")
                    .font(.system(size: 15))
                    .foregroundStyle(.orange)
            }

            Text(localization.string("onboarding.no_players_found"))
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))

            Spacer()
        }
        .padding(12)
        .background(SongletonTheme.card.opacity(0.68), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.3), lineWidth: 1))
    }

    private func playerColor(for bundleID: String) -> Color {
        switch bundleID {
        case "com.spotify.client": .green
        case "com.apple.Music": .pink
        case "com.tidal.desktop": .cyan
        case "com.deezer.deezer-desktop": .orange
        case "com.amazon.music": .blue
        case "com.github.th-ch.youtube-music": .red
        case "com.soundcloud.desktop": .orange
        case "com.qobuz.QobuzDesktop": .purple
        default: SongletonTheme.cyan
        }
    }

    private var accessibilityPermissionCard: some View {
        let isGranted = mouseGestureManager.isAccessibilityTrusted
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
                if !isGranted {
                    Text(localization.string("onboarding.permission_accessibility_hint"))
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
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
                    Text(localization.string("onboarding.open_settings"))
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
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.50), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )

                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.88))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .shadow(color: color.opacity(0.35), radius: 10, y: 5)
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

// Offset-based entrances make ScrollViews drift from the top, so scrollable
// content fades in without moving instead.
private struct EntranceFadeModifier: ViewModifier {
    let index: Int
    let appeared: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .animation(
                .easeOut(duration: 0.45)
                    .delay(delay + Double(index) * 0.07),
                value: appeared
            )
    }
}

private struct GlowPulse: ViewModifier {
    let pulse: Bool
    var color: Color = SongletonTheme.cyan

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color)
                    .blur(radius: pulse ? 18 : 6)
                    .opacity(pulse ? 0.50 : 0.15)
                    .scaleEffect(pulse ? 1.02 : 0.98)
            )
            .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: pulse)
    }
}

private extension View {
    func entrance(_ index: Int, appeared: Bool, delay: Double = 0.04) -> some View {
        modifier(EntranceModifier(index: index, appeared: appeared, delay: delay))
    }

    func entranceFade(_ index: Int, appeared: Bool, delay: Double = 0.04) -> some View {
        modifier(EntranceFadeModifier(index: index, appeared: appeared, delay: delay))
    }
}
