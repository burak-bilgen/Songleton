import AppKit
import SwiftUI

/// The kind of playback action the user just triggered. Each maps to a
/// big fading icon so the outcome of an edge gesture or menu bar click is
/// obvious even without looking at the now-playing app.
enum GestureOutcomeKind {
    case next
    case previous
    case pause
    case resume
    case cancel

    var iconName: String {
        switch self {
        case .next: return "forward.fill"
        case .previous: return "backward.fill"
        case .pause: return "pause.fill"
        case .resume: return "play.fill"
        case .cancel: return "xmark"
        }
    }

    var accent: Color {
        switch self {
        case .cancel: return Color(red: 0.98, green: 0.28, blue: 0.31)
        case .pause: return SongletonTheme.violet
        default: return SongletonTheme.cyan
        }
    }
}

/// A large icon that appears at full size and fades out while shrinking to
/// a fraction of its size. Used both in the real app (floating panel) and
/// inside the tutorial (embedded in the demo canvas).
struct GestureOutcomeFeedbackView: View {
    let kind: GestureOutcomeKind
    var onComplete: () -> Void = {}

    @State private var appeared = false
    @State private var dismissed = false

    private let iconSize: CGFloat = 176

    var body: some View {
        ZStack {
            Circle()
                .fill(kind.accent.opacity(appeared ? 0 : 0.22))
                .frame(width: iconSize * 1.65, height: iconSize * 1.65)
                .blur(radius: 26)
                .scaleEffect(appeared ? 1.25 : 1.15)

            Circle()
                .stroke(kind.accent.opacity(0.5), lineWidth: 3)
                .frame(width: iconSize * 1.25, height: iconSize * 1.25)
                .scaleEffect(appeared ? 1.8 : 1.05)
                .opacity(appeared ? 0 : 0.9)

            Image(systemName: kind.iconName)
                .font(.system(size: iconSize, weight: .heavy))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.white, kind.accent],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: kind.accent.opacity(0.55), radius: 34)
                .scaleEffect(appeared ? 0.5 : 1.28)
                .opacity(appeared ? 0 : 1)
        }
        .frame(width: iconSize * 2, height: iconSize * 2)
        .onAppear {
            guard !appeared else { return }
            withAnimation(.easeOut(duration: 0.85)) {
                appeared = true
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(900))
                guard !dismissed else { return }
                dismissed = true
                onComplete()
            }
        }
    }
}

/// Presents the outcome feedback as a borderless, non-interactive panel
/// centered on the screen that currently holds the mouse pointer.
@MainActor
final class GestureOutcomeFeedback {
    static let shared = GestureOutcomeFeedback()

    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?

    private init() {}

    func show(_ kind: GestureOutcomeKind) {
        dismissTask?.cancel()

        let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        let panelSize = CGSize(width: 420, height: 420)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        let origin = CGPoint(
            x: screen.map { $0.frame.midX - panelSize.width / 2 } ?? 0,
            y: screen.map { $0.frame.midY - panelSize.height / 2 } ?? 0
        )
        panel.setFrame(NSRect(origin: origin, size: panelSize), display: true)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = GestureOutcomeFeedbackView(kind: kind) { [weak self] in
            self?.dismiss()
        }
        panel.contentView = NSHostingView(rootView: view)
        panel.orderFrontRegardless()

        self.panel?.close()
        self.panel = panel
    }

    private func dismiss() {
        panel?.close()
        panel = nil
    }
}
