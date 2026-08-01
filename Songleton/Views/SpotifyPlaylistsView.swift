import SwiftUI

private let spotifyGreen = Color(red: 0.11, green: 0.73, blue: 0.33)

struct SpotifyPlaylistsView: View {
    @StateObject private var model = SpotifyPlaylistModel.shared

    @State private var showAddSheet = false
    @State private var newName = ""
    @State private var newUrl = ""
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(spotifyGreen)
                    Text(NSLocalizedString("Spotify Listeleri", comment: "Spotify Playlists heading"))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }

                Spacer()

                Button {
                    showAddSheet = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                        Text(NSLocalizedString("Ekle", comment: "Add playlist button"))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(spotifyGreen.opacity(0.12), in: Capsule())
                    .foregroundStyle(spotifyGreen)
                }
                .buttonStyle(.plain)
                .help(NSLocalizedString("Spotify bağlantısı ile playlist ekle", comment: "Add playlist tooltip"))
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 5) {
                    ForEach(model.playlists) { playlist in
                        PlaylistRowView(playlist: playlist) {
                            model.play(playlist: playlist)
                        } onDelete: {
                            model.removePlaylist(at: playlist.id)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            addPlaylistSheet
        }
    }

    private var addPlaylistSheet: some View {
        VStack(spacing: 16) {
            Text(NSLocalizedString("Playlist Ekle", comment: "Add Playlist sheet title"))
                .font(.system(size: 15, weight: .bold, design: .rounded))

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel(NSLocalizedString("Playlist Adı", comment: "Playlist name label"))
                TextField(NSLocalizedString("Örn: Favori Şarkılarım", comment: "Playlist name placeholder"), text: $newName)
                    .textFieldStyle(.roundedBorder)

                fieldLabel(NSLocalizedString("Spotify Bağlantısı veya URI", comment: "Spotify URL label"))
                TextField("https://open.spotify.com/playlist/…", text: $newUrl)
                    .textFieldStyle(.roundedBorder)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.red)
            }

            HStack(spacing: 12) {
                Button(NSLocalizedString("İptal", comment: "Cancel")) {
                    showAddSheet = false
                    errorMessage = nil
                }
                .buttonStyle(.bordered)

                Button(NSLocalizedString("Ekle", comment: "Add")) {
                    if model.addPlaylist(name: newName, urlOrUri: newUrl) {
                        newName = ""; newUrl = ""; errorMessage = nil
                        showAddSheet = false
                    } else {
                        errorMessage = NSLocalizedString("Geçersiz Spotify playlist bağlantısı.", comment: "Invalid URL error")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(spotifyGreen)
            }
        }
        .padding(20)
        .frame(width: 280)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
    }
}

struct PlaylistRowView: View {
    let playlist: SpotifyPlaylist
    let onPlay: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(
                        colors: [spotifyGreen.opacity(0.9), Color(red: 0.08, green: 0.55, blue: 0.25).opacity(0.9)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 38, height: 38)
                Image(systemName: playlist.iconName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text(playlist.description)
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onPlay) {
                Image(systemName: "play.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(spotifyGreen, in: Circle())
                    .shadow(color: spotifyGreen.opacity(0.35), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            if playlist.isUserAdded {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(isHovered ? Color.primary.opacity(0.06) : Color.primary.opacity(0.03))
        )
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
    }
}
