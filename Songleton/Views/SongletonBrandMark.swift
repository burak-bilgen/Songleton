import AppKit
import SwiftUI

/// Uses the actual application icon everywhere Songleton introduces itself.
/// Keeping this tied to AppIcon prevents the onboarding and recovery surfaces
/// from quietly drifting into an older logo.
struct SongletonBrandMark: View {
    var size: CGFloat
    var glow: Bool = true

    var body: some View {
        Group {
            if let appIcon = NSImage(named: NSImage.applicationIconName) {
                Image(nsImage: appIcon)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
                    .shadow(
                        color: glow ? SongletonTheme.cyan.opacity(0.34) : .clear,
                        radius: glow ? size * 0.14 : 0,
                        y: glow ? size * 0.05 : 0
                    )
            } else {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(SongletonTheme.cyan)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
