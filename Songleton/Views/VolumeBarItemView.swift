import SwiftUI

struct VolumeMiniSliderView: View {
    @ObservedObject var model: NowPlayingModel = .shared
    @State private var isDragging = false
    @State private var pendingVolume: Double? = nil

    private var currentVolume: Double {
        guard case .loaded(let info, _) = model.state else { return 0 }
        return Double(info.volume)
    }

    private var displayVolume: Double {
        pendingVolume ?? currentVolume
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let percent = displayVolume / 100.0
            let thumbX = 6 + (w - 12) * CGFloat(percent)

            ZStack(alignment: .leading) {
                // Track background
                Capsule()
                    .fill(Color.primary.opacity(0.14))
                    .frame(height: 3)
                    .padding(.horizontal, 6)

                // Track fill
                Capsule()
                    .fill(Color.primary.opacity(isDragging ? 0.75 : 0.55))
                    .frame(width: max(6, thumbX - 3), height: 3)
                    .padding(.leading, 6)
                    .animation(.easeOut(duration: 0.08), value: displayVolume)

                // Thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: isDragging ? 11 : 9, height: isDragging ? 11 : 9)
                    .shadow(color: .black.opacity(0.3), radius: isDragging ? 3 : 2, x: 0, y: 1)
                    .offset(x: thumbX - (isDragging ? 5.5 : 4.5))
                    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isDragging)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let raw = (value.location.x - 6) / (w - 12)
                        let clamped = max(0, min(1, raw))
                        pendingVolume = clamped * 100
                    }
                    .onEnded { value in
                        isDragging = false
                        let raw = (value.location.x - 6) / (w - 12)
                        let clamped = max(0, min(1, raw))
                        let vol = Int(clamped * 100)
                        pendingVolume = nil
                        model.setVolume(vol)
                    }
            )
        }
        .frame(width: 56, height: 22)
    }
}
