import AppKit
import Combine

final class MenuBarControls: NSObject {
    private let model: NowPlayingModel
    private var items: [NSStatusItem] = []
    private var playPauseItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()

    init(model: NowPlayingModel) {
        self.model = model
        super.init()

        // Listen to settings changes to show/hide controls
        SettingsModel.shared.$showMenuBarControls
            .receive(on: DispatchQueue.main)
            .sink { [weak self] show in self?.rebuildItems(show: show) }
            .store(in: &cancellables)

        model.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.updatePlayPause(state: state) }
            .store(in: &cancellables)
    }

    private func rebuildItems(show: Bool) {
        for item in items {
            NSStatusBar.system.removeStatusItem(item)
        }
        items.removeAll()
        playPauseItem = nil

        guard show else { return }

        let fwd = makeItem(image: "forward.fill", action: #selector(nextTapped))
        let pp  = makeItem(image: "play.fill",    action: #selector(toggleTapped))
        let bwd = makeItem(image: "backward.fill", action: #selector(previousTapped))

        items = [fwd, pp, bwd]
        playPauseItem = pp
        updatePlayPause(state: model.state)
    }

    private func updatePlayPause(state: NowPlayingModel.State) {
        let isPlaying: Bool
        if case .loaded(let info, _) = state { isPlaying = info.isPlaying } else { isPlaying = false }
        playPauseItem?.button?.image = NSImage(
            systemSymbolName: isPlaying ? "pause.fill" : "play.fill",
            accessibilityDescription: nil
        )
    }

    @discardableResult
    private func makeItem(image: String, action: Selector) -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: image, accessibilityDescription: nil)
        item.button?.target = self
        item.button?.action = action
        return item
    }

    @objc private func nextTapped()     { model.nextTrack() }
    @objc private func toggleTapped()  { model.togglePlayPause() }
    @objc private func previousTapped(){ model.previousTrack() }
}
