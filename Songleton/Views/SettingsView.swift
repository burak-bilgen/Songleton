import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsModel
    @ObservedObject private var model = NowPlayingModel.shared

    var body: some View {
        Form {
            Section(NSLocalizedString("Genel", comment: "General section")) {
                Toggle(NSLocalizedString("Oturum açıldığında başlat", comment: "Launch at login"), isOn: $settings.launchAtLogin)
                Button(NSLocalizedString("Tanıtımı tekrar göster", comment: "Reopen onboarding")) {
                    (NSApp.delegate as? AppDelegate)?.reopenOnboarding()
                }
            }

            Section(NSLocalizedString("Görünüm", comment: "Appearance section")) {
                Picker(NSLocalizedString("Panel stili", comment: "Panel style picker"), selection: $settings.panelStyle) {
                    ForEach(SettingsModel.PanelStyle.allCases, id: \.self) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                Toggle(NSLocalizedString("Dinamik renk teması", comment: "Dynamic color theme"), isOn: $settings.useDynamicColor)
                Toggle(NSLocalizedString("İlerleme çubuğu göster", comment: "Show progress bar"), isOn: $settings.showProgressBar)
            }

            Section(NSLocalizedString("Şarkı Sözleri", comment: "Lyrics section")) {
                LabeledContent(NSLocalizedString("Gecikme Düzeltme", comment: "Lyrics offset label")) {
                    HStack {
                        Slider(value: $settings.lyricsOffset, in: -3.0...3.0, step: 0.1)
                        Text(String(format: "%+.1fs", settings.lyricsOffset))
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                    .frame(width: 200)
                }
                .help(NSLocalizedString("Sözler şarkıdan geride kalıyorsa artırın (+), önde gidiyorsa azaltın (-).", comment: "Lyrics offset help"))
            }

            Section(NSLocalizedString("Menü Çubuğu", comment: "Menu Bar section")) {
                Picker(NSLocalizedString("Yazı tipi", comment: "Font picker"), selection: $settings.menuBarFont) {
                    Text(NSLocalizedString("Sistem", comment: "System font")).tag(SettingsModel.MenuBarFont.system)
                    Text("Audiowide").tag(SettingsModel.MenuBarFont.audiowide)
                }
                Toggle(NSLocalizedString("Sanatçı adını göster", comment: "Show artist name"), isOn: $settings.showArtistInMenuBar)
                LabeledContent(NSLocalizedString("Genişlik", comment: "Menu bar width label")) {
                    HStack {
                        Slider(value: $settings.menuBarWidth, in: 80...300, step: 10)
                        Text("\(Int(settings.menuBarWidth))")
                            .monospacedDigit()
                            .frame(width: 36, alignment: .trailing)
                    }
                    .frame(width: 200)
                }
            }

            Section(NSLocalizedString("İzinler", comment: "Permissions section")) {
                LabeledContent(NSLocalizedString("Otomasyon İzni", comment: "Automation permission label")) {
                    automationStatusView
                }
                .help(NSLocalizedString("Spotify ve Apple Music'e erişmek için Otomasyon iznine ihtiyaç vardır.", comment: "Permission help"))

                Button(NSLocalizedString("İzinleri Kontrol Et", comment: "Check permissions")) {
                    model.checkAutomationPermission(askUser: true)
                }
                Button(NSLocalizedString("Gizlilik Ayarlarını Aç", comment: "Open privacy settings")) {
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
            Label(NSLocalizedString("Verildi", comment: "Permission granted"), systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .denied:
            Label(NSLocalizedString("Reddedildi", comment: "Permission denied"), systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
        case .unknown:
            Label(NSLocalizedString("Bilinmiyor", comment: "Permission unknown"), systemImage: "questionmark.circle")
                .foregroundStyle(.secondary)
        }
    }
}
