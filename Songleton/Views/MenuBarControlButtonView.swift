import SwiftUI

// MARK: - MenuBarControlButtonView

struct MenuBarControlButtonView: View {
    let systemName: String
    let toolTip: String
    let action: () -> Void

    @ObservedObject var model: NowPlayingModel = .shared

    private var platformGradient: LinearGradient {
        guard let bundleID = model.activeBundleID?.lowercased() else {
            return LinearGradient(
                colors: [Color.white.opacity(0.14), Color.white.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        if bundleID.contains("spotify") {
            return LinearGradient(
                colors: [Color(red: 0.11, green: 0.73, blue: 0.33), Color(red: 0.09, green: 0.60, blue: 0.27)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if bundleID.contains("apple") || bundleID.contains("music") {
            return LinearGradient(
                colors: [Color(red: 0.98, green: 0.14, blue: 0.24), Color(red: 0.88, green: 0.08, blue: 0.32)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color.white.opacity(0.14), Color.white.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 14, height: 14)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 7)
        .padding(.vertical, 3.5)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(platformGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
        )
        .animation(.easeInOut(duration: 0.3), value: model.activeBundleID)
        .help(toolTip)
    }
}
