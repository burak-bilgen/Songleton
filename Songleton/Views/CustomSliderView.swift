import SwiftUI

struct CustomSliderView: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let onEditingChanged: (Bool) -> Void
    var barColor: Color = .primary

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = max(geometry.size.width, 1)
            let safeRange = max(range.upperBound - range.lowerBound, 0.001)
            let percent = max(0, min(1, (value - range.lowerBound) / safeRange))
            let activeWidth = totalWidth * CGFloat(percent)

            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12)).frame(height: 4)
                Capsule()
                    .fill(LinearGradient(colors: [barColor, barColor.opacity(0.75)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(4, activeWidth), height: 4)
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 0.5))
                    .frame(width: 12, height: 12)
                    .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1.5)
                    .offset(x: max(0, min(totalWidth - 12, activeWidth - 6)))
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        onEditingChanged(true)
                        value = range.lowerBound + Double(max(0, min(1, g.location.x / totalWidth))) * safeRange
                    }
                    .onEnded { _ in onEditingChanged(false) }
            )
        }
        .frame(height: 16)
    }
}
