import AppKit
import SwiftUI

struct VolumePercentTextView: View {
    @ObservedObject var model: NowPlayingModel = .shared

    private var currentVolume: Int {
        guard case .loaded(let info, _) = model.state else { return 0 }
        return info.volume
    }

    var body: some View {
        Text("\(currentVolume)%")
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.primary.opacity(0.85))
            .frame(height: 22)
            .allowsHitTesting(false)
    }
}
