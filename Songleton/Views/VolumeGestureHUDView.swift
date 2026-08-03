import SwiftUI

struct VolumeGestureHUDView: View {
    @ObservedObject var manager: MouseGestureManager

    var body: some View {
        let progress = CGFloat(manager.gestureVolume) / 100

        VStack(spacing: 6) {
            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 6, height: 120)

                Capsule()
                    .fill(Color.white)
                    .frame(width: 6, height: max(6, 120 * progress))
            }
            .animation(.easeOut(duration: 0.06), value: manager.gestureVolume)

            Text("\(manager.gestureVolume)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
    }
}
