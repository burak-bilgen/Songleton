import SwiftUI

struct VolumeGestureHUDView: View {
    @ObservedObject var manager: MouseGestureManager
    var visualMaximum: CGFloat = 100

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height - 24
            let progress = min(1, CGFloat(manager.gestureVolume) / max(1, visualMaximum))

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

    private let burstAccent = SongletonTheme.cyan
    private let cancelAccent = Color(red: 0.98, green: 0.28, blue: 0.31)
    @State private var isBursting = false
    @State private var burstScale: CGFloat = 0.5
    @State private var burstOpacity: Double = 0.0
    @State private var successMarkScale: CGFloat = 0.35
    @State private var successMarkOpacity: Double = 0.0
    @State private var isCancelling = false
    @State private var cancelShrink = false

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

            // Central Dark Card Circle
            Circle()
                .fill(Color.black.opacity(isCancelling ? 0.82 : 0.86))
                .overlay(
                    Circle()
                        .fill((isCancelling ? cancelAccent : burstAccent).opacity(isCancelling ? 0.38 : (isBursting ? 0.6 : 0.14)))
                        .blur(radius: 7)
                )
                .scaleEffect(isBursting ? 1.10 : 1)

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
                .scaleEffect(isBursting ? 0.35 : (isCancelling ? 0.4 : 1))
                .opacity(isBursting ? 0 : 1)

            // Pop-style success blob and checkmark.
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white, burstAccent, burstAccent.opacity(0.2)],
                            center: .center,
                            startRadius: 1,
                            endRadius: 22
                        )
                    )
                    .frame(width: 34, height: 34)
                    .scaleEffect(successMarkScale)
                    .opacity(successMarkOpacity)
                    .shadow(color: burstAccent, radius: 14)

                Image(systemName: "checkmark")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(.white)
                    .scaleEffect(successMarkScale)
                    .opacity(successMarkOpacity)
                    .shadow(color: .black.opacity(0.35), radius: 2)
            }
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
                successMarkScale = 0.35
                successMarkOpacity = 0.0
                isCancelling = false
                cancelShrink = false
            } else {
                // A new hold has started. Clear any leftover cancel visuals so
                // the progress ring is visible again on the next attempt.
                isCancelling = false
                cancelShrink = false
            }
        }
        .onChange(of: manager.edgeGestureBurst) { _, _ in
            isBursting = true
            burstScale = 0.5
            burstOpacity = 1.0
            successMarkScale = 0.35
            successMarkOpacity = 0.0

            withAnimation(.spring(response: 0.26, dampingFraction: 0.58)) {
                burstScale = 0.95
                successMarkScale = 1.0
                successMarkOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.34).delay(0.10)) {
                burstScale = 1.55
                burstOpacity = 0.0
                successMarkScale = 1.18
                successMarkOpacity = 0.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.58) {
                isBursting = false
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
