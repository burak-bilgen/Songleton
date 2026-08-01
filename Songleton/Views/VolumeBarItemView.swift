import AppKit
import SwiftUI

struct VolumeBarItemView: View {
    let barIndex: Int
    @ObservedObject var model: NowPlayingModel = .shared

    private var currentVolume: Int {
        guard case .loaded(let info, _) = model.state else { return 0 }
        return info.volume
    }

    private var isActive: Bool { currentVolume >= barIndex * 20 - 5 }

    var body: some View {
        Capsule()
            .fill(isActive ? Color.primary.opacity(0.88) : Color.primary.opacity(0.18))
            .frame(width: 4, height: 12)
            .animation(.easeOut(duration: 0.1), value: isActive)
            .allowsHitTesting(false)
    }
}
