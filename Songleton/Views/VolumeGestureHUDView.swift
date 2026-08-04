import SwiftUI

struct VolumeGestureHUDView: View {
    @ObservedObject var manager: MouseGestureManager

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height - 24
            let progress = CGFloat(manager.gestureVolume) / 100

            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 12, height: height)

                Capsule()
                    .fill(Color.white)
                    .frame(width: 12, height: max(10, height * progress))

                Circle()
                    .fill(Color.white)
                    .frame(width: 26, height: 26)
                    .shadow(color: .white.opacity(0.45), radius: 10)
                    .offset(y: -progress * (height - 26))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeOut(duration: 0.06), value: manager.gestureVolume)
        }
        .frame(width: 46, height: 220)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct CursorGestureOverlayView: View {
    @ObservedObject var manager: MouseGestureManager
    let zone: MouseGestureManager.EdgeZone

    private let amoledAccent = Color.white
    private let burstAccent = SongletonTheme.cyan
    private let cancelAccent = Color(red: 0.98, green: 0.28, blue: 0.31)
    @State private var isBursting = false
    @State private var burstScale: CGFloat = 0.5
    @State private var burstOpacity: Double = 0.0
    @State private var isCancelling = false
    @State private var cancelShrink = false

    private let particleOffsets: [CGSize] = [
        CGSize(width: 0, height: -18),
        CGSize(width: 13, height: -13),
        CGSize(width: 18, height: 0),
        CGSize(width: 13, height: 13),
        CGSize(width: 0, height: 18),
        CGSize(width: -13, height: 13),
        CGSize(width: -18, height: 0),
        CGSize(width: -13, height: -13)
    ]

    private var iconName: String {
        switch zone {
        case .previous: return "chevron.left"
        case .playPause: return "playpause.fill"
        case .next: return "chevron.right"
        }
    }

    var body: some View {
        ZStack {
            // Expanding Shockwave Burst Ring
            Circle()
                .stroke(burstAccent, lineWidth: 3.5)
                .scaleEffect(burstScale)
                .opacity(burstOpacity)
                .shadow(color: burstAccent.opacity(0.8), radius: 12)

            // Expanding Particles Shockwave
            ForEach(Array(particleOffsets.enumerated()), id: \.offset) { _, offset in
                Circle()
                    .fill(burstAccent)
                    .frame(width: 5, height: 5)
                    .offset(
                        x: isBursting ? offset.width : 0,
                        y: isBursting ? offset.height : 0
                    )
                    .scaleEffect(isBursting ? 1.4 : 0.2)
                    .opacity(burstOpacity * 0.9)
                    .shadow(color: burstAccent, radius: 6)
            }

            // Central Dark Card Circle
            Circle()
                .fill(Color.black.opacity(isCancelling ? 0.82 : 0.86))
                .overlay(
                    Circle()
                        .fill((isCancelling ? cancelAccent : burstAccent).opacity(isCancelling ? 0.38 : (isBursting ? 0.6 : 0.14)))
                        .blur(radius: 7)
                )

            Circle()
                .stroke(
                    isCancelling ? cancelAccent.opacity(0.8) : Color.white.opacity(0.16),
                    lineWidth: 3
                )

            // Progress Ring
            Circle()
                .trim(from: 0, to: manager.edgeGestureProgress)
                .stroke(
                    isCancelling ? cancelAccent : burstAccent,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .opacity(isBursting || isCancelling ? 0 : 1)

            // Icon
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(isCancelling ? cancelAccent : .white)
                .shadow(color: isCancelling ? cancelAccent : burstAccent, radius: 8)
                .scaleEffect(isBursting ? 1.45 : (isCancelling ? 0.4 : 1))

            // Central Glowing Blob Burst
            Circle()
                .fill(burstAccent)
                .frame(width: 24, height: 24)
                .scaleEffect(burstScale * 0.85)
                .opacity(burstOpacity * 0.75)
                .shadow(color: burstAccent, radius: 10)
        }
        .frame(width: 44, height: 44)
        .frame(width: 112, height: 112)
        .scaleEffect(cancelShrink ? 0.1 : 1)
        .opacity(cancelShrink ? 0 : 1)
        .onChange(of: manager.edgeGestureProgress) { _, newProgress in
            if newProgress == 0 {
                isBursting = false
                burstScale = 0.5
                burstOpacity = 0.0
                isCancelling = false
                cancelShrink = false
            }
        }
        .onChange(of: manager.edgeGestureBurst) { _, _ in
            isBursting = true
            burstScale = 0.5
            burstOpacity = 1.0
            withAnimation(.easeOut(duration: 0.35)) {
                burstScale = 1.25
                burstOpacity = 0.0
            }
        }
        .onChange(of: manager.edgeGestureCancelBurst) { _, _ in
            guard !isBursting else { return }
            isCancelling = true
            withAnimation(.easeIn(duration: 0.16)) {
                cancelShrink = true
            }
        }
    }
}
