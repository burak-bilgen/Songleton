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
    private let cancelAccent = Color(red: 0.98, green: 0.28, blue: 0.31)
    @State private var isBursting = false
    @State private var isCancelling = false
    @State private var cancelShrink = false
    private let particleOffsets: [CGSize] = [
        CGSize(width: 0, height: -24),
        CGSize(width: 17, height: -17),
        CGSize(width: 24, height: 0),
        CGSize(width: 17, height: 17),
        CGSize(width: 0, height: 24),
        CGSize(width: -17, height: 17),
        CGSize(width: -24, height: 0),
        CGSize(width: -17, height: -17)
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
            Circle()
                .stroke(
                    (isCancelling ? cancelAccent : amoledAccent)
                        .opacity(isBursting || isCancelling ? 0 : 0.8),
                    lineWidth: 2.5
                )
                .scaleEffect(isBursting ? 2.35 : 0.62)

            ForEach(Array(particleOffsets.enumerated()), id: \.offset) { _, offset in
                Circle()
                    .fill(amoledAccent)
                    .frame(width: 3, height: 3)
                    .offset(
                        x: isBursting ? offset.width : 0,
                        y: isBursting ? offset.height : 0
                    )
                    .scaleEffect(isBursting ? 1 : 0.1)
                    .opacity(isBursting ? 0 : 0.95)
            }

            Circle()
                .fill(Color.black.opacity(isCancelling ? 0.82 : 0.86))
                .overlay(
                    Circle()
                        .fill((isCancelling ? cancelAccent : amoledAccent).opacity(isCancelling ? 0.38 : 0.14))
                        .blur(radius: 7)
                )

            Circle()
                .stroke(
                    isCancelling ? cancelAccent.opacity(0.8) : Color.white.opacity(0.16),
                    lineWidth: 3
                )

            Circle()
                .trim(from: 0, to: manager.edgeGestureProgress)
                .stroke(
                    isCancelling ? cancelAccent : amoledAccent,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .opacity(isBursting || isCancelling ? 0 : 1)

            Image(systemName: iconName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(isCancelling ? cancelAccent : .white)
                .shadow(color: isCancelling ? cancelAccent : amoledAccent, radius: 8)
                .scaleEffect(isBursting ? 1.45 : (isCancelling ? 0.4 : 1))
                .opacity(isBursting || isCancelling ? 0 : 1)

            Circle()
                .fill(amoledAccent)
                .frame(width: 28, height: 28)
                .scaleEffect(isBursting ? 1.8 : 0.18)
                .opacity(isBursting || isCancelling ? 0 : 0.18)
        }
        .frame(width: 44, height: 44)
        .frame(width: 112, height: 112)
        .scaleEffect(cancelShrink ? 0.1 : 1)
        .opacity(cancelShrink ? 0 : 1)
        .animation(.easeOut(duration: 0.08), value: manager.edgeGestureProgress)
        .animation(.easeOut(duration: 0.24), value: isBursting)
        .animation(.easeIn(duration: 0.16), value: cancelShrink)
        .onChange(of: manager.edgeGestureBurst) { _, _ in
            isBursting = true
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
