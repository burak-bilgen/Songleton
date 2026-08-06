import SwiftUI

enum SongletonTheme {
    static let background = Color.black
    static let panelTop = Color(red: 0.045, green: 0.05, blue: 0.065)
    static let panelBottom = Color.black
    static let card = Color(red: 0.055, green: 0.06, blue: 0.075)
    static let cyan = Color(red: 0.28, green: 0.82, blue: 0.82)
    static let violet = Color(red: 0.52, green: 0.39, blue: 0.92)
    static let pink = Color(red: 0.94, green: 0.32, blue: 0.62)
    static let spotifyGreen = Color(red: 29/255, green: 185/255, blue: 84/255)
    static let secondaryText = Color.white.opacity(0.58)

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
