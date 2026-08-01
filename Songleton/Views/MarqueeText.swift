import SwiftUI

struct MarqueeText: View {
    let text: String
    var font: Font
    var maxWidth: CGFloat
    var alignment: Alignment = .center

    @State private var textWidth: CGFloat = 0
    @State private var startDate = Date()
    @State private var isPaused = true

    private let speed: Double = 36
    private let gap: CGFloat = 48
    private let pauseDuration: Double = 2.0

    private var needsScroll: Bool { textWidth > maxWidth }

    var body: some View {
        Group {
            if needsScroll {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: isPaused)) { context in
                    let elapsed = max(0, context.date.timeIntervalSince(startDate) - pauseDuration)
                    let cycle = textWidth + gap
                    let offset = -CGFloat(elapsed * speed).truncatingRemainder(dividingBy: cycle)
                    HStack(spacing: gap) {
                        measuredLabel
                        measuredLabel
                    }
                    .offset(x: offset)
                }
                .frame(width: maxWidth, alignment: .leading)
                .clipped()
                .mask(fadeMask)
            } else {
                measuredLabel
                    .frame(width: maxWidth, alignment: alignment)
                    .clipped()
            }
        }
        .frame(width: maxWidth, alignment: alignment)
        .clipped()
        .task(id: text) {
            startDate = Date()
            isPaused = true
            try? await Task.sleep(for: .seconds(pauseDuration))
            if !Task.isCancelled { isPaused = false }
        }
    }

    private var measuredLabel: some View {
        Text(text)
            .font(font)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { textWidth = proxy.size.width }
                        .onChange(of: proxy.size.width) { _, v in textWidth = v }
                }
            )
    }

    private var fadeMask: some View {
        HStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                .frame(width: needsScroll ? 12 : 0)
            Color.black
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 12)
        }
    }
}
