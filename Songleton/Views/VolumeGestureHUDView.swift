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
            .padding(.vertical, 12)
            .padding(.horizontal, 13)
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
