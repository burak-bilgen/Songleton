import AppKit
import SwiftUI

// MARK: - MenuBarStackNSView

final class MenuBarStackNSView: NSView {
    private let model: NowPlayingModel
    private let settings: SettingsModel
    private let onTogglePanel: () -> Void

    private let bwdButton = NSButton()
    private let fwdButton = NSButton()
    private let panelButton = NSButton()
    private var centerHosting: NSHostingView<MenuBarCenterTitleView>?

    init(model: NowPlayingModel, settings: SettingsModel, onTogglePanel: @escaping () -> Void) {
        self.model = model
        self.settings = settings
        self.onTogglePanel = onTogglePanel
        super.init(frame: .zero)
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        // 1. Önceki Şarkı Butonu (Native NSButton)
        configureButton(bwdButton, imageName: "backward.fill", action: #selector(bwdTapped), tooltip: "Önceki Şarkı")
        
        // 2. Ortadaki Şarkı Adı (NSHostingView)
        let centerView = MenuBarCenterTitleView(
            model: model,
            settings: settings,
            onTapPlayPause: { [weak self] in
                self?.model.togglePlayPause()
            }
        )
        let centerHosting = NSHostingView(rootView: centerView)
        self.centerHosting = centerHosting
        addSubview(centerHosting)

        // 3. Sonraki Şarkı Butonu (Native NSButton)
        configureButton(fwdButton, imageName: "forward.fill", action: #selector(fwdTapped), tooltip: "Sonraki Şarkı")

        // 4. Panel Butonu (Native NSButton)
        configureButton(panelButton, imageName: "slider.horizontal.3", action: #selector(panelTapped), tooltip: "Oynatıcı Paneli")

        updateLayout()
    }

    private func configureButton(_ button: NSButton, imageName: String, action: Selector, tooltip: String) {
        button.isBordered = false
        button.setButtonType(.momentaryChange)
        button.bezelStyle = .inline
        button.imagePosition = .imageOnly
        button.image = NSImage(systemSymbolName: imageName, accessibilityDescription: tooltip)
        button.imageScaling = .scaleProportionallyDown
        button.target = self
        button.action = action
        button.toolTip = tooltip
        addSubview(button)
    }

    func updateLayout() {
        let buttonWidth: CGFloat = 20
        let buttonHeight: CGFloat = 22
        let textWidth: CGFloat = CGFloat(settings.menuBarWidth) + 30
        let totalWidth: CGFloat = (buttonWidth * 3) + textWidth + 12

        bwdButton.frame = NSRect(x: 0, y: 0, width: buttonWidth, height: buttonHeight)
        centerHosting?.frame = NSRect(x: buttonWidth + 2, y: 0, width: textWidth, height: buttonHeight)
        fwdButton.frame = NSRect(x: buttonWidth + textWidth + 4, y: 0, width: buttonWidth, height: buttonHeight)
        panelButton.frame = NSRect(x: buttonWidth * 2 + textWidth + 6, y: 0, width: buttonWidth, height: buttonHeight)

        self.frame = NSRect(x: 0, y: 0, width: totalWidth, height: buttonHeight)
    }

    @objc private func bwdTapped() {
        model.previousTrack()
    }

    @objc private func fwdTapped() {
        model.nextTrack()
    }

    @objc private func panelTapped() {
        onTogglePanel()
    }
}
