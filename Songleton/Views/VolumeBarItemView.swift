import AppKit
import Combine
import SwiftUI

@MainActor
final class VolumeSegmentState: ObservableObject {
    static let shared = VolumeSegmentState()
    @Published var pendingVolume: Int? = nil
    private init() {}
}

@MainActor
final class VolumeSegmentedNSView: NSView {
    private let state = VolumeSegmentState.shared

    override init(frame: NSRect) {
        super.init(frame: frame)
        let hosting = NSHostingView(rootView: VolumeSegmentedView())
        hosting.frame = bounds
        hosting.autoresizingMask = [.width, .height]
        addSubview(hosting)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        let x = convert(event.locationInWindow, from: nil).x
        let stepWidth = bounds.width / 5.0
        let segmentIndex = min(5, max(1, Int(x / stepWidth) + 1))
        let targetVolume = segmentIndex * 20
        
        state.pendingVolume = targetVolume
        NowPlayingModel.shared.setVolume(targetVolume)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            if self?.state.pendingVolume == targetVolume {
                self?.state.pendingVolume = nil
            }
        }
    }

    override func scrollWheel(with event: NSEvent) {
        guard case .loaded(let info, _) = NowPlayingModel.shared.state else { return }
        let delta = event.deltaY
        if abs(delta) > 0.1 {
            let change = delta > 0 ? 5 : -5
            let newVol = max(0, min(100, info.volume + change))
            state.pendingVolume = newVol
            NowPlayingModel.shared.setVolume(newVol)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                if self?.state.pendingVolume == newVol {
                    self?.state.pendingVolume = nil
                }
            }
        }
    }
}

struct VolumeSegmentedView: View {
    @ObservedObject private var state = VolumeSegmentState.shared
    @ObservedObject private var model = NowPlayingModel.shared

    private var currentVolume: Int {
        if let p = state.pendingVolume { return p }
        guard case .loaded(let info, _) = model.state else { return 0 }
        return info.volume
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { index in
                let isActive = currentVolume >= (index * 20 - 10)
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(isActive ? Color.primary.opacity(0.88) : Color.primary.opacity(0.18))
                    .frame(width: 5, height: 12)
            }
        }
        .frame(width: 44, height: 22)
        .contentShape(Rectangle())
        .allowsHitTesting(false)
    }
}
