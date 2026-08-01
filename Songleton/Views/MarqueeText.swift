import SwiftUI

// MARK: - MarqueeText

struct MarqueeText: View {
    let text: String
    var font: Font
    var maxWidth: CGFloat

    @State private var textWidth: CGFloat = 0
    @State private var startDate = Date()
    @State private var isPaused = true  // Start paused, scroll after delay

    private let speed: Double = 36      // pts/sec
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
            }
        }
        .onChange(of: text) {
            startDate = Date()
            isPaused = true
            // Restart scroll after pause
            DispatchQueue.main.asyncAfter(deadline: .now() + pauseDuration) {
                isPaused = false
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + pauseDuration) {
                isPaused = false
            }
        }
    }

    private var measuredLabel: some View {
        Text(text)
            .font(font)
            .fixedSize()
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
                .frame(width: needsScroll ? 16 : 0)
            Color.black
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 16)
        }
    }
}

// MARK: - MenuBarLabelView

struct MenuBarLabelView: View {
    @ObservedObject var model: NowPlayingModel
    @ObservedObject var settings: SettingsModel

    var body: some View {
        MarqueeText(
            text: model.menuBarTitle ?? "Songleton",
            font: settings.menuBarFont.font(size: 14),
            maxWidth: settings.menuBarWidth
        )
    }
}
