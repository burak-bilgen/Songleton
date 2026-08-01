import SwiftUI

// MARK: - MenuBarVolumeBarView (Draggable Mini Volume Slider)

struct MenuBarVolumeBarView: View {
    @ObservedObject var model: NowPlayingModel = .shared

    private var currentVolume: Int {
        if case .loaded(let info, _) = model.state {
            return info.volume
        }
        return 50
    }

    private var volumeIcon: String {
        let vol = currentVolume
        if vol <= 0 { return "speaker.slash.fill" }
        if vol <= 33 { return "speaker.wave.1.fill" }
        if vol <= 66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    private var platformGradient: LinearGradient {
        guard let bundleID = model.activeBundleID?.lowercased() else {
            return LinearGradient(
                colors: [Color.white.opacity(0.14), Color.white.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        if bundleID.contains("spotify") {
            return LinearGradient(
                colors: [Color(red: 0.11, green: 0.73, blue: 0.33), Color(red: 0.09, green: 0.60, blue: 0.27)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if bundleID.contains("apple") || bundleID.contains("music") {
            return LinearGradient(
                colors: [Color(red: 0.98, green: 0.14, blue: 0.24), Color(red: 0.88, green: 0.08, blue: 0.32)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color.white.opacity(0.14), Color.white.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: volumeIcon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)

            // Sürüklenebilir Ses Çubuğu (Mini Track)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.3))

                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(0, geo.size.width * CGFloat(currentVolume) / 100.0))
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let percent = max(0, min(1.0, value.location.x / geo.size.width))
                            let targetVol = Int(percent * 100)
                            model.setVolume(targetVol)
                        }
                )
            }
            .frame(width: 32, height: 5)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3.5)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(platformGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
        )
        .animation(.easeInOut(duration: 0.3), value: model.activeBundleID)
        .help("Ses: %\(currentVolume) (Sürükle veya Tıkla)")
    }
}
