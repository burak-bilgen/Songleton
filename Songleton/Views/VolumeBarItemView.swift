import SwiftUI

struct VolumeBarItemView: View {
    let barIndex: Int
    @ObservedObject var model: NowPlayingModel = .shared

    private var currentVolume: Int {
        guard case .loaded(let info, _) = model.state else { return 0 }
        return info.volume
    }

    private var isActive: Bool { currentVolume >= barIndex * 20 }
    private var barHeight: CGFloat { 4 + CGFloat(barIndex) * 2.8 }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            Capsule()
                .fill(isActive ? Color.primary.opacity(0.88) : Color.primary.opacity(0.13))
                .frame(width: 3, height: barHeight)
        }
        .frame(width: 10, height: 22)
        .animation(.easeOut(duration: 0.12), value: isActive)
        .allowsHitTesting(false)
    }
}
