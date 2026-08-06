import SwiftUI

// MARK: - PlatformLogoView

struct PlatformLogoView: View {
    let bundleID: String
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            switch bundleID {
            case "com.spotify.client":
                Circle()
                    .fill(Color(red: 30/255, green: 215/255, blue: 96/255))
                    .frame(width: size, height: size)
                    .shadow(color: Color(red: 30/255, green: 215/255, blue: 96/255).opacity(0.3), radius: 4)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: size * 0.45, weight: .bold))
                            .foregroundStyle(.black)
                    )

            case "com.apple.Music":
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 250/255, green: 36/255, blue: 60/255), Color(red: 255/255, green: 70/255, blue: 110/255)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .shadow(color: Color(red: 250/255, green: 36/255, blue: 60/255).opacity(0.35), radius: 4)
                    .overlay(
                        Image(systemName: "apple.logo")
                            .font(.system(size: size * 0.45, weight: .semibold))
                            .foregroundStyle(.white)
                    )

            case "com.tidal.desktop":
                Circle()
                    .fill(Color.black)
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .stroke(Color.cyan, lineWidth: 1.5)
                    )
                    .overlay(
                        HStack(spacing: 2) {
                            Rectangle().fill(Color.cyan).frame(width: size * 0.12, height: size * 0.4)
                            Rectangle().fill(Color.cyan).frame(width: size * 0.12, height: size * 0.5)
                            Rectangle().fill(Color.cyan).frame(width: size * 0.12, height: size * 0.3)
                        }
                    )

            case "com.deezer.deezer-desktop":
                // Official Deezer Equalizer Block Logo
                Circle()
                    .fill(Color(red: 18/255, green: 18/255, blue: 24/255))
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .stroke(Color.orange.opacity(0.4), lineWidth: 1)
                    )
                    .overlay(
                        HStack(alignment: .bottom, spacing: 2) {
                            VStack(spacing: 1.5) {
                                RoundedRectangle(cornerRadius: 1).fill(Color(red: 255/255, green: 0/255, blue: 128/255)).frame(width: 3.5, height: 3.5)
                                RoundedRectangle(cornerRadius: 1).fill(Color(red: 255/255, green: 102/255, blue: 0/255)).frame(width: 3.5, height: 3.5)
                            }
                            VStack(spacing: 1.5) {
                                RoundedRectangle(cornerRadius: 1).fill(Color(red: 0/255, green: 199/255, blue: 255/255)).frame(width: 3.5, height: 3.5)
                                RoundedRectangle(cornerRadius: 1).fill(Color(red: 255/255, green: 224/255, blue: 0/255)).frame(width: 3.5, height: 3.5)
                                RoundedRectangle(cornerRadius: 1).fill(Color(red: 255/255, green: 0/255, blue: 128/255)).frame(width: 3.5, height: 3.5)
                            }
                            VStack(spacing: 1.5) {
                                RoundedRectangle(cornerRadius: 1).fill(Color(red: 161/255, green: 0/255, blue: 255/255)).frame(width: 3.5, height: 3.5)
                                RoundedRectangle(cornerRadius: 1).fill(Color(red: 0/255, green: 199/255, blue: 255/255)).frame(width: 3.5, height: 3.5)
                                RoundedRectangle(cornerRadius: 1).fill(Color(red: 255/255, green: 224/255, blue: 0/255)).frame(width: 3.5, height: 3.5)
                                RoundedRectangle(cornerRadius: 1).fill(Color(red: 255/255, green: 0/255, blue: 128/255)).frame(width: 3.5, height: 3.5)
                            }
                        }
                    )

            case "com.amazon.music":
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0/255, green: 168/255, blue: 225/255), Color(red: 0/255, green: 120/255, blue: 210/255)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: size * 0.45, weight: .heavy))
                            .foregroundStyle(.white)
                    )

            case "com.github.th-ch.youtube-music":
                Circle()
                    .fill(Color(red: 255/255, green: 0/255, blue: 0/255))
                    .frame(width: size, height: size)
                    .shadow(color: Color.red.opacity(0.4), radius: 4)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: size * 0.55, height: size * 0.55)
                            .overlay(
                                Image(systemName: "play.fill")
                                    .font(.system(size: size * 0.25, weight: .bold))
                                    .foregroundStyle(.white)
                                    .offset(x: 1)
                            )
                    )

            case "com.soundcloud.desktop":
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 255/255, green: 85/255, blue: 0/255), Color(red: 255/255, green: 51/255, blue: 0/255)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size, height: size)
                    .shadow(color: Color.orange.opacity(0.35), radius: 4)
                    .overlay(
                        Image(systemName: "cloud.fill")
                            .font(.system(size: size * 0.45, weight: .bold))
                            .foregroundStyle(.white)
                    )

            case "com.qobuz.QobuzDesktop":
                Circle()
                    .fill(Color(red: 20/255, green: 20/255, blue: 28/255))
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .stroke(LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                            .frame(width: size * 0.68, height: size * 0.68)
                    )
                    .overlay(
                        Text(verbatim: "Q")
                            .font(.system(size: size * 0.42, weight: .black, design: .serif))
                            .foregroundStyle(.white)
                    )

            default:
                Circle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundStyle(.white)
                    )
            }
        }
    }
}
