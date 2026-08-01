import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsModel
    @ObservedObject private var model = NowPlayingModel.shared

    var body: some View {
        Form {
            // MARK: General
            Section("Genel") {
                Toggle("Oturum açıldığında başlat", isOn: $settings.launchAtLogin)
                Button("Tanıtımı tekrar göster") {
                    (NSApp.delegate as? AppDelegate)?.reopenOnboarding()
                }
            }

            // MARK: Appearance
            Section("Görünüm") {
                Picker("Panel stili", selection: $settings.panelStyle) {
                    ForEach(SettingsModel.PanelStyle.allCases, id: \.self) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                Toggle("Dinamik renk teması", isOn: $settings.useDynamicColor)
                Toggle("İlerleme çubuğu göster", isOn: $settings.showProgressBar)
            }

            // MARK: Menu Bar
            Section("Menü Çubuğu") {
                Picker("Yazı tipi", selection: $settings.menuBarFont) {
                    Text("Sistem").tag(SettingsModel.MenuBarFont.system)
                    Text("Audiowide").tag(SettingsModel.MenuBarFont.audiowide)
                }
                Toggle("Sanatçı adını göster", isOn: $settings.showArtistInMenuBar)
                LabeledContent("Genişlik") {
                    HStack {
                        Slider(value: $settings.menuBarWidth, in: 80...300, step: 10)
                        Text("\(Int(settings.menuBarWidth))")
                            .monospacedDigit()
                            .frame(width: 36, alignment: .trailing)
                    }
                    .frame(width: 200)
                }
            }

            // MARK: Permissions
            Section("İzinler") {
                LabeledContent("Otomasyon İzni") {
                    automationStatusView
                }
                .help("Spotify ve Apple Music'e erişmek için Otomasyon iznine ihtiyaç vardır.")

                Button("İzinleri Kontrol Et") {
                    model.checkAutomationPermission(askUser: true)
                }
                Button("Gizlilik Ayarlarını Aç") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .onAppear {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            model.checkAutomationPermission(askUser: false)
        }
        .onDisappear {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    @ViewBuilder
    private var automationStatusView: some View {
        switch model.automationStatus {
        case .granted:
            Label("Verildi", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .denied:
            Label("Reddedildi", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
        case .unknown:
            Label("Bilinmiyor", systemImage: "questionmark.circle")
                .foregroundStyle(.secondary)
        }
    }
}
