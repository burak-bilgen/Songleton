import AppKit
import SwiftUI

struct VolumePercentTextView: View {
    @ObservedObject var model: NowPlayingModel = .shared
    @State private var previousVolume: Int = 50
    @State private var isIncreasing = true

    private var currentVolume: Int {
        guard case .loaded(let info, _) = model.state else { return 0 }
        return info.volume
    }

    var body: some View {
        ZStack {
            Text("\(currentVolume)%")
                .id(currentVolume)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary.opacity(0.88))
                .transition(.asymmetric(
                    insertion: .move(edge: isIncreasing ? .bottom : .top).combined(with: .opacity),
                    removal: .move(edge: isIncreasing ? .top : .bottom).combined(with: .opacity)
                ))
        }
        .frame(width: 34, height: 22)
        .clipped()
        .allowsHitTesting(false)
        .animation(.spring(response: 0.28, dampingFraction: 0.75), value: currentVolume)
        .onChange(of: currentVolume) { oldVal, newVal in
            if newVal != oldVal {
                isIncreasing = newVal > oldVal
                previousVolume = newVal
            }
        }
        .onAppear {
            previousVolume = currentVolume
        }
    }
}
