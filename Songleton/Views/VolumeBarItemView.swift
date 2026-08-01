import AppKit
import Combine
import SwiftUI

// Shared observable state between NSView (event handler) and SwiftUI (display)
@MainActor
final class VolumeSliderState: ObservableObject {
    static let shared = VolumeSliderState()
    @Published var isDragging = false
    @Published var pendingVolume: Double? = nil
    private init() {}
}

// NSView subclass — captures mouseDown / mouseDragged / mouseUp directly
@MainActor
final class VolumeStatusNSView: NSView {
    private let state = VolumeSliderState.shared

    override init(frame: NSRect) {
        super.init(frame: frame)
        let hosting = NSHostingView(rootView: VolumeMiniSliderView())
        hosting.frame = bounds
        hosting.autoresizingMask = [.width, .height]
        addSubview(hosting)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent)    { handle(event, commit: false) }
    override func mouseDragged(with event: NSEvent) { handle(event, commit: false) }
    override func mouseUp(with event: NSEvent)      { handle(event, commit: true) }

    private func handle(_ event: NSEvent, commit: Bool) {
        let x = convert(event.locationInWindow, from: nil).x
        let percent = max(0, min(1, Double(x - 6) / Double(bounds.width - 12)))
        let vol = percent * 100
        state.isDragging = !commit
        if commit {
            state.pendingVolume = nil
            NowPlayingModel.shared.setVolume(Int(vol))
        } else {
            state.pendingVolume = vol
        }
    }
}

// SwiftUI view — display only, no gestures (NSView handles everything)
struct VolumeMiniSliderView: View {
    @ObservedObject private var state = VolumeSliderState.shared
    @ObservedObject private var model = NowPlayingModel.shared

    private var displayVolume: Double {
        if let p = state.pendingVolume { return p }
        guard case .loaded(let info, _) = model.state else { return 0 }
        return Double(info.volume)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let percent = CGFloat(displayVolume / 100.0)
            let fillWidth = (w - 12) * percent
            let thumbX = 6 + fillWidth

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.13))
                    .frame(height: 3)
                    .padding(.horizontal, 6)

                Capsule()
                    .fill(Color.primary.opacity(state.isDragging ? 0.8 : 0.55))
                    .frame(width: max(6, fillWidth), height: 3)
                    .padding(.leading, 6)
                    .animation(.easeOut(duration: 0.06), value: displayVolume)

                Circle()
                    .fill(Color.white)
                    .frame(
                        width: state.isDragging ? 12 : 10,
                        height: state.isDragging ? 12 : 10
                    )
                    .shadow(color: .black.opacity(0.28), radius: state.isDragging ? 4 : 2, x: 0, y: 1)
                    .offset(x: thumbX - (state.isDragging ? 6 : 5))
                    .animation(.spring(response: 0.18, dampingFraction: 0.65), value: state.isDragging)
                    .animation(.easeOut(duration: 0.06), value: displayVolume)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(width: 56, height: 22)
        .allowsHitTesting(false)
    }
}
