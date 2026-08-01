import SwiftUI

// MARK: - OnboardingView

struct OnboardingView: View {
    @ObservedObject var model: NowPlayingModel
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
                    Color(nsColor: .windowBackgroundColor),
                    Color.accentColor.opacity(0.06),
                    Color(nsColor: .controlBackgroundColor)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

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
        .frame(width: 460, height: 600)
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
                            Text("Geri")
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
                        .fill(stepIndex >= i ? Color.accentColor : Color.primary.opacity(0.12))
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
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 96, height: 96)
                    .scaleEffect(animateIcon ? 1.06 : 0.96)

                if let icon = NSImage(named: NSImage.applicationIconName) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 80, height: 80)
                        .shadow(color: Color.accentColor.opacity(0.3), radius: 12, y: 6)
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }

            // Title & Description (No Overflow)
            VStack(spacing: 8) {
                Text("Songleton'a Hoş Geldiniz")
                    .font(.system(size: 22, weight: .bold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Menü çubuğunuzda çalan parçayı anlık görüntüleyin. Spotify ve Apple Music'i doğrudan kontrol edin.")
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
                    color: .pink,
                    title: "Menü Çubuğunda Canlı Bilgi",
                    desc: "Şarkı ve sanatçı adı menü çubuğunda yumuşak animasyonla akar."
                )
                featureCard(
                    id: 2,
                    icon: "playpause.circle.fill",
                    color: .blue,
                    title: "Hızlı Medya Kontrolleri",
                    desc: "Oynat, durdur, parça değiştir ve ses ayarını tek tıkla yapın."
                )
                featureCard(
                    id: 3,
                    icon: "sparkles",
                    color: .purple,
                    title: "Dinamik Tema & Akıllı Geçmiş",
                    desc: "Albüm kapağına göre değişen renkler ve son çalınan şarkı geçmişi."
                )
            }

            Spacer(minLength: 4)

            // Primary Button
            actionButton(title: "Devam Et →", color: .accentColor) {
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
                .fill(.primary.opacity(hoveredCard == id ? 0.07 : 0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.primary.opacity(hoveredCard == id ? 0.12 : 0.05), lineWidth: 1)
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
                Text("Otomasyon İzni")
                    .font(.system(size: 20, weight: .bold))

                Text("Songleton'ın çalan şarkıyı okuyabilmesi ve müzik çaları kontrol edebilmesi için macOS Otomasyon izni gereklidir.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
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
            if model.automationStatus == .denied {
                Button(action: { openAutomationSettings() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape.fill")
                        Text("Sistem Ayarları → Gizlilik ve Güvenlik → Otomasyon")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.orange.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 4)

            // Bottom Actions
            VStack(spacing: 8) {
                actionButton(
                    title: model.automationStatus == .granted ? "Devam Et →" : "Tüm İzinleri İste",
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
                        Text("Şimdilik Atla (Daha sonra ayarlayabilirsiniz)")
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
                    Text("İzin Ver")
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
        .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
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
                Text("Her Şey Hazır!")
                    .font(.system(size: 22, weight: .bold))

                Text("Songleton menü çubuğunuzda aktif hale geldi. Müzik başladığında menü çubuğundan anlık takip edebilirsiniz.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                tipItem(icon: "menubar.rectangle", title: "Menü Çubuğuna Tıklayın", desc: "Kontrol panelini ve ses ayarını açın.")
                tipItem(icon: "music.note", title: "Albüm Kapağına Tıklayın", desc: "Müzik uygulamasını ön plana getirin.")
                tipItem(icon: "doc.on.doc", title: "Şarkı Adına Tıklayın", desc: "Çalan parçayı panoya kopyalayın.")
            }
            .padding(14)
            .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))

            Spacer(minLength: 4)

            actionButton(title: "Başlat 🚀", color: .green) {
                onFinish()
            }
        }
    }

    private func tipItem(icon: String, title: String, desc: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.accentColor)
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
                .background(color, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
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

    private func statusText(for status: NowPlayingModel.AutomationStatus) -> String {
        switch status {
        case .granted: "İzin Verildi"
        case .denied: "İzin Reddedildi"
        case .unknown: "Henüz İzin Verilmedi"
        }
    }

    private func statusColor(for status: NowPlayingModel.AutomationStatus) -> Color {
        switch status {
        case .granted: .green
        case .denied: .red
        case .unknown: .secondary
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
