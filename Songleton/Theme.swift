import SwiftUI

enum SongletonTheme {
    static let background = Color(red: 0.018, green: 0.024, blue: 0.065)
    static let panelTop = Color(red: 0.065, green: 0.085, blue: 0.18)
    static let panelBottom = Color(red: 0.018, green: 0.022, blue: 0.065)
    static let card = Color(red: 0.075, green: 0.09, blue: 0.18)
    static let cyan = Color(red: 0.28, green: 0.82, blue: 0.82)
    static let violet = Color(red: 0.52, green: 0.39, blue: 0.92)
    static let pink = Color(red: 0.94, green: 0.32, blue: 0.62)
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.62)

    static let panelGradient = LinearGradient(
        colors: [panelTop, panelBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradient = LinearGradient(
        colors: [cyan, violet],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let borderGradient = LinearGradient(
        colors: [cyan.opacity(0.42), violet.opacity(0.22), Color.white.opacity(0.08)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
