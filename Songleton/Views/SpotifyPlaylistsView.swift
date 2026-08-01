import SwiftUI

// MARK: - SpotifyPlaylistsView

struct SpotifyPlaylistsView: View {
    @StateObject private var model = SpotifyPlaylistModel.shared

    @State private var showAddSheet = false
    @State private var newName = ""
    @State private var newUrl = ""
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(red: 0.11, green: 0.73, blue: 0.33))

                    Text("Spotify Çalma Listeleri")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }

                Spacer()

                // Add Custom Button
                Button {
                    showAddSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("Playlist Ekle")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(red: 0.11, green: 0.73, blue: 0.33).opacity(0.15))
                    .foregroundStyle(Color(red: 0.11, green: 0.73, blue: 0.33))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Spotify Bağlantısı ile Playlist Ekle")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Playlist Grid / List
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(model.playlists) { playlist in
                        PlaylistRowView(playlist: playlist) {
                            model.play(playlist: playlist)
                        } onDelete: {
                            model.removePlaylist(at: playlist.id)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            VStack(spacing: 16) {
                Text("Spotify Playlist Ekle")
                    .font(.system(size: 15, weight: .bold, design: .rounded))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Playlist Adı")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    TextField("Örn: Favori Şarkılarım", text: $newName)
                        .textFieldStyle(.roundedBorder)

                    Text("Spotify Bağlantısı veya URI")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    TextField("https://open.spotify.com/playlist/...", text: $newUrl)
                        .textFieldStyle(.roundedBorder)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.red)
                }

                HStack(spacing: 12) {
                    Button("İptal") {
                        showAddSheet = false
                        errorMessage = nil
                    }
                    .buttonStyle(.bordered)

                    Button("Ekle") {
                        if model.addPlaylist(name: newName, urlOrUri: newUrl) {
                            newName = ""
                            newUrl = ""
                            errorMessage = nil
                            showAddSheet = false
                        } else {
                            errorMessage = "Geçersiz Spotify playlist bağlantısı."
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.11, green: 0.73, blue: 0.33))
                }
            }
            .padding(20)
            .frame(width: 280)
        }
    }
}

// MARK: - PlaylistRowView

struct PlaylistRowView: View {
    let playlist: SpotifyPlaylist
    let onPlay: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.11, green: 0.73, blue: 0.33).opacity(0.85),
                                Color(red: 0.08, green: 0.55, blue: 0.25).opacity(0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)

                Image(systemName: playlist.iconName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(playlist.description)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Play Button
            Button(action: onPlay) {
                Image(systemName: "play.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color(red: 0.11, green: 0.73, blue: 0.33))
                    .clipShape(Circle())
                    .shadow(color: Color(red: 0.11, green: 0.73, blue: 0.33).opacity(0.4), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            if playlist.isUserAdded {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isHovered ? Color.primary.opacity(0.06) : Color.primary.opacity(0.03))
        )
        .onHover { isHovered = $0 }
    }
}
