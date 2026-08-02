import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsModel
    @ObservedObject private var model = NowPlayingModel.shared

    @State private var appearScale: CGFloat = 0.95
    @State private var appearOpacity: Double = 0.0
    @State private var hoveredSection: String? = nil

    // Neutral monochrome accent — no platform colors
    private let accent = Color.white.opacity(0.85)
    private let subtleAccent = Color.white.opacity(0.12)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    headerSection
                    generalSection
                    appearanceSection
                    menuBarSection
                    lyricsSection
                    permissionsSection
                    footerSection
                }
                .padding(28)
            }
        }
        .frame(width: 480, height: 620)
        .scaleEffect(appearScale)
        .opacity(appearOpacity)
        .onAppear {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            model.checkAutomationPermission(askUser: false)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                appearScale = 1.0
                appearOpacity = 1.0
            }
        }
        .onDisappear {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 52, height: 52)

                Image(systemName: "music.note.list")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Songleton")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(NSLocalizedString("Menü Çubuğu Müzik Kontrolcüsü", comment: "App subtitle"))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer()
        }
        .padding(.bottom, 4)
    }

    // MARK: - General Section

    private var generalSection: some View {
        settingsCard(title: NSLocalizedString("Genel", comment: "General"), icon: "gearshape.fill", sectionID: "general") {
            settingsToggleRow(
                icon: "power",
                title: NSLocalizedString("Oturum açıldığında başlat", comment: "Launch at login"),
                subtitle: NSLocalizedString("Mac başladığında otomatik çalışır", comment: "Launch at login description"),
                isOn: $settings.launchAtLogin
            )
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        settingsCard(title: NSLocalizedString("Görünüm", comment: "Appearance"), icon: "paintbrush.fill", sectionID: "appearance") {
            VStack(spacing: 0) {
                settingsToggleRow(
                    icon: "sparkles",
                    title: NSLocalizedString("Dinamik renk teması", comment: "Dynamic color theme"),
                    subtitle: NSLocalizedString("Platforma göre renk değişir", comment: "Dynamic color description"),
                    isOn: $settings.useDynamicColor
                )

                sectionDivider

                settingsToggleRow(
                    icon: "chart.bar.fill",
                    title: NSLocalizedString("İlerleme çubuğu", comment: "Progress bar"),
                    subtitle: NSLocalizedString("Şarkı ilerleme barını göster", comment: "Progress bar description"),
                    isOn: $settings.showProgressBar
                )
            }
        }
    }

    // MARK: - Menu Bar Section

    private var menuBarSection: some View {
        settingsCard(title: NSLocalizedString("Menü Çubuğu", comment: "Menu Bar"), icon: "menubar.rectangle", sectionID: "menubar") {
            VStack(spacing: 0) {
                settingsToggleRow(
                    icon: "person.fill",
                    title: NSLocalizedString("Sanatçı adını göster", comment: "Show artist name"),
                    subtitle: NSLocalizedString("Menü çubuğunda sanatçı adı", comment: "Show artist description"),
                    isOn: $settings.showArtistInMenuBar
                )

                sectionDivider

                // Font Picker Row
                settingsPickerRow(icon: "textformat",
                    title: NSLocalizedString("Yazı tipi", comment: "Font"),
                    subtitle: NSLocalizedString("Menü çubuğu fontu", comment: "Font description")
                ) {
                    Picker("", selection: $settings.menuBarFont) {
                        Text(NSLocalizedString("Sistem", comment: "System font")).tag(SettingsModel.MenuBarFont.system)
                        Text("Audiowide").tag(SettingsModel.MenuBarFont.audiowide)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }

                sectionDivider

                // Width Slider Row
                settingsPickerRow(icon: "arrow.left.and.right",
                    title: NSLocalizedString("Genişlik", comment: "Width"),
                    subtitle: NSLocalizedString("Metin alanı genişliği", comment: "Width description")
                ) {
                    Slider(value: $settings.menuBarWidth, in: 80...300, step: 10)
                        .tint(.white.opacity(0.5))
                        .frame(width: 110)

                    Text("\(Int(settings.menuBarWidth))")
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
        settingsCard(title: NSLocalizedString("Şarkı Sözleri", comment: "Lyrics"), icon: "quote.bubble.fill", sectionID: "lyrics") {
            settingsPickerRow(icon: "timer",
                title: NSLocalizedString("Gecikme Düzeltme", comment: "Lyrics offset"),
                subtitle: NSLocalizedString("Sözler geride kalıyorsa (+), önde gidiyorsa (-)", comment: "Offset description"),
                subtitleSize: 10
            ) {
                Slider(value: $settings.lyricsOffset, in: -3.0...3.0, step: 0.1)
                    .tint(.white.opacity(0.5))
                    .frame(width: 100)

                Text(String(format: "%+.1fs", settings.lyricsOffset))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(width: 44, alignment: .trailing)
            }
        }
    }

    // MARK: - Permissions Section

    private var permissionsSection: some View {
        settingsCard(title: NSLocalizedString("İzinler", comment: "Permissions"), icon: "lock.shield.fill", sectionID: "permissions") {
            VStack(spacing: 0) {
                // Automation Status Row
                HStack(spacing: 12) {
                    iconBadge(systemName: automationStatusIcon, color: automationStatusColor)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(NSLocalizedString("Otomasyon İzni", comment: "Automation permission"))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(automationStatusText)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(automationStatusColor)
                    }

                    Spacer()

                    Button {
                        model.checkAutomationPermission(askUser: true)
                    } label: {
                        Text(NSLocalizedString("Kontrol Et", comment: "Check"))
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

                        Text(NSLocalizedString("Gizlilik Ayarlarını Aç", comment: "Open privacy settings"))
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
            }
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            Text("v1.0")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.2))

            Spacer()

            Text(NSLocalizedString("Sevgiyle yapıldı ♥", comment: "Made with love"))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.2))
        }
        .padding(.top, 4)
    }

    // MARK: - Reusable Components

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 1)
            .padding(.horizontal, 16)
    }

    private func iconBadge(systemName: String, color: Color = .white.opacity(0.7)) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.opacity(0.12))
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
                    .foregroundStyle(.white.opacity(0.4))
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
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        hoveredSection == sectionID
                            ? Color.white.opacity(0.12)
                            : Color.white.opacity(0.06),
                        lineWidth: 1
                    )
            )
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
                .tint(.white.opacity(0.6))
                .labelsHidden()
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

    // MARK: - Permission Helpers

    private var automationStatusColor: Color {
        switch model.automationStatus {
        case .granted: return Color(hue: 0.35, saturation: 0.5, brightness: 0.7)  // muted sage
        case .denied: return Color(hue: 0.0, saturation: 0.45, brightness: 0.7)   // muted coral
        case .unknown: return .white.opacity(0.45)
        }
    }

    private var automationStatusIcon: String {
        switch model.automationStatus {
        case .granted: return "checkmark.shield.fill"
        case .denied: return "xmark.shield.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    private var automationStatusText: String {
        switch model.automationStatus {
        case .granted: return NSLocalizedString("İzin Verildi", comment: "Permission granted")
        case .denied: return NSLocalizedString("Reddedildi", comment: "Permission denied")
        case .unknown: return NSLocalizedString("Bilinmiyor", comment: "Permission unknown")
        }
    }
}
