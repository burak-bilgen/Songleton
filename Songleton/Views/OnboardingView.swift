import SwiftUI

// MARK: - OnboardingView

struct OnboardingView: View {
    @ObservedObject var model: NowPlayingModel
    let onFinish: () -> Void

    @State private var step: Step = .welcome

    enum Step { case welcome, permission, ready }

    var body: some View {
        ZStack {
            // Subtle gradient background
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), Color(nsColor: .controlBackgroundColor)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Step indicator
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        Capsule()
                            .fill(stepIndex >= i ? Color.accentColor : Color.secondary.opacity(0.25))
                            .frame(width: stepIndex == i ? 24 : 8, height: 4)
                            .animation(.spring(duration: 0.4), value: stepIndex)
                    }
                }
                .padding(.top, 24)

                Spacer()

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

                Spacer()
            }
            .padding(.horizontal, 32)
        }
        .frame(width: 420, height: 540)
        .onAppear { model.checkAutomationPermission(askUser: false) }
    }

    private var stepIndex: Int {
        switch step {
        case .welcome: 0
        case .permission: 1
        case .ready: 2
        }
    }

    // MARK: - Welcome Step

    private var welcomeView: some View {
        VStack(spacing: 20) {
            if let icon = NSImage(named: NSImage.applicationIconName) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 88, height: 88)
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            }

            VStack(spacing: 8) {
                Text("Songleton'a Hoş Geldiniz")
                    .font(.system(size: 22, weight: .bold))
                    .multilineTextAlignment(.center)
                Text("Menü çubuğunuzda şu an çalan şarkıyı gösterir.\nSpotify ve Apple Music'i doğrudan kontrol edin.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            VStack(alignment: .leading, spacing: 12) {
                featureRow(icon: "music.note", color: .pink, title: "Şu An Çalıyor", desc: "Şarkı, sanatçı ve albüm bilgisi")
                featureRow(icon: "playpause.fill", color: .blue, title: "Tam Kontrol", desc: "Oynat, durdur, ileri/geri, ses ayarı")
                featureRow(icon: "chart.bar.fill", color: .purple, title: "İlerleme Çubuğu", desc: "Şarkı konumunu görün ve değiştirin")
            }
            .padding(.vertical, 8)

            Button(action: { withAnimation(.spring(duration: 0.5)) { step = .permission } }) {
                Text("Devam Et")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
        }
    }

    // MARK: - Permission Step

    private var permissionView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(automationStatusColor.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: automationStatusIcon)
                    .font(.system(size: 34, weight: .thin))
                    .foregroundStyle(automationStatusColor)
                    .animation(.spring, value: model.automationStatus)
            }

            VStack(spacing: 8) {
                Text("Otomasyon İzni")
                    .font(.system(size: 20, weight: .bold))
                Text(automationStatusDescription)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            // Permission status card
            GroupBox {
                VStack(spacing: 10) {
                    permissionRow(app: "Spotify", bundleID: "com.spotify.client")
                    Divider()
                    permissionRow(app: "Apple Music", bundleID: "com.apple.Music")
                }
                .padding(4)
            }

            VStack(spacing: 8) {
                if model.automationStatus != .granted {
                    Button(action: {
                        // requestPermissionByScript actually sends an AppleEvent
                        // which triggers the macOS "Songleton wants to control X" dialog
                        model.requestPermissionByScript()
                    }) {
                        HStack {
                            Image(systemName: "hand.raised")
                            Text("İzin Ver")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }

                if model.automationStatus == .denied {
                    Button(action: { openAutomationSettings() }) {
                        HStack {
                            Image(systemName: "gear")
                            Text("Sistem Ayarlarını Aç")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.orange)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: { withAnimation(.spring(duration: 0.5)) { step = .ready } }) {
                    Text(model.automationStatus == .granted ? "Harika! Devam Et →" : "Sonra Ayarla")
                        .font(.system(size: 13, weight: model.automationStatus == .granted ? .semibold : .regular))
                        .foregroundStyle(model.automationStatus == .granted ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
            }
        }
        // Auto-advance to "ready" step when permission is granted
        .onChange(of: model.automationStatus) { _, newStatus in
            if newStatus == .granted, step == .permission {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.spring(duration: 0.5)) { step = .ready }
                }
            }
        }
    }

    private func permissionRow(app: String, bundleID: String) -> some View {
        HStack {
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
               let icon = NSWorkspace.shared.icon(forFile: appURL.path) as NSImage? {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "music.note")
                    .frame(width: 24, height: 24)
            }
            Text(app)
                .font(.system(size: 13, weight: .medium))
            Spacer()
            Image(systemName: model.automationStatus == .granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(model.automationStatus == .granted ? .green : .secondary)
        }
    }

    // MARK: - Ready Step

    private var readyView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(.green.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.green)
            }

            VStack(spacing: 8) {
                Text("Hazır!")
                    .font(.system(size: 22, weight: .bold))
                Text("Songleton menü çubuğunda çalışmaya başladı.\nMüzik çalarken çalan parçayı menü çubuğunda göreceksiniz.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            VStack(alignment: .leading, spacing: 12) {
                tipRow(icon: "menubar.rectangle", title: "Menü çubuğuna tıklayın", desc: "Oynatıcı panelini açın")
                tipRow(icon: "cursorarrow.click", title: "Albüm kapağına tıklayın", desc: "Uygulamayı ön plana alın")
                tipRow(icon: "gear", title: "Ayarlardan özelleştirin", desc: "Font, genişlik ve daha fazlası")
            }
            .padding(.vertical, 8)

            Button(action: onFinish) {
                Text("Başla")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
        }
    }

    // MARK: - Helpers

    private var automationStatusIcon: String {
        switch model.automationStatus {
        case .granted: "checkmark.shield.fill"
        case .denied: "xmark.shield.fill"
        case .unknown: "shield.lefthalf.filled"
        }
    }

    private var automationStatusColor: Color {
        switch model.automationStatus {
        case .granted: .green
        case .denied: .red
        case .unknown: .orange
        }
    }

    private var automationStatusDescription: String {
        switch model.automationStatus {
        case .granted: "İzin verildi! Spotify ve Apple Music'e erişilebilir."
        case .denied: "İzin reddedildi. Sistem Ayarları → Gizlilik ve Güvenlik → Otomasyon bölümünden Songleton'a izin verin."
        case .unknown: "Songleton, çalan şarkıyı göstermek için Spotify ve Apple Music'e erişmesi gerekiyor."
        }
    }

    private func featureRow(icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(desc).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func tipRow(icon: String, title: String, desc: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(desc).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
}
