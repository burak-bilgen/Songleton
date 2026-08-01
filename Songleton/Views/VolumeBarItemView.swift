import AppKit
import SwiftUI

struct VolumePercentTextView: View {
    @ObservedObject var model: NowPlayingModel = .shared

    private var currentVolume: Int {
        guard case .loaded(let info, _) = model.state else { return 0 }
        return info.volume
    }

    var body: some View {
        VolumeNumberAnimatedView(volume: currentVolume)
            .frame(width: 34, height: 22)
            .clipped()
            .allowsHitTesting(false)
    }
}

private struct VolumeNumberAnimatedView: View {
    let volume: Int
    @State private var prevVolume: Int = 50
    @State private var isUp: Bool = true

    var body: some View {
        ZStack {
            Text("\(volume)%")
                .id(volume)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary.opacity(0.88))
                .transition(.asymmetric(
                    insertion: .move(edge: isUp ? .bottom : .top).combined(with: .opacity),
                    removal: .move(edge: isUp ? .top : .bottom).combined(with: .opacity)
                ))
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.78), value: volume)
        .onChange(of: volume) { oldVal, newVal in
            if newVal != oldVal {
                isUp = newVal > oldVal
                prevVolume = newVal
            }
        }
        .onAppear {
            prevVolume = volume
        }
    }
}
