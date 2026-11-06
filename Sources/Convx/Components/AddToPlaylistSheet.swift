import SwiftUI

public struct AddToPlaylistSheet: View {
    @ObservedObject private var playlistService = PlaylistService.shared
    let song: SongItem
    @Environment(\.dismiss) private var dismiss

    @State private var showingCreateAlert = false
    @State private var newPlaylistName = ""

    public init(song: SongItem) {
        self.song = song
    }

    public var body: some View {
        ZStack {
            MeshGradientBackground()
                .allowsHitTesting(false)

            VStack(spacing: 20) {
                // Top Grabber & Header
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 36, height: 5)
                    .padding(.top, 12)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Agregar a Playlist")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        Text(song.title)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                    Spacer()

                    Button("Listo") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.cyan)
                }
                .padding(.horizontal, 24)

                // New Playlist Button
                Button(action: {
                    showingCreateAlert = true
                }) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.cyan.opacity(0.2))
                                .frame(width: 48, height: 48)
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.cyan)
                        }

                        Text("Nueva Playlist...")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .liquidGlass(cornerRadius: 16, opacity: 0.6)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)

                // Playlists List
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(playlistService.playlists) { playlist in
                            let isInPlaylist = playlistService.isSongInPlaylist(songId: song.id, playlistId: playlist.id)

                            Button(action: {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                if isInPlaylist {
                                    playlistService.removeSong(songId: song.id, from: playlist.id)
                                } else {
                                    playlistService.addSong(song, to: playlist.id)
                                }
                            }) {
                                HStack(spacing: 14) {
                                    if let thumb = playlist.thumbnail {
                                        ArtworkImageView(urlString: thumb, size: 48, cornerRadius: 10)
                                    } else {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color.white.opacity(0.1))
                                                .frame(width: 48, height: 48)
                                            Image(systemName: "music.note.list")
                                                .font(.system(size: 20))
                                                .foregroundColor(.white.opacity(0.4))
                                        }
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(playlist.title)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.white)
                                            .lineLimit(1)

                                        Text(playlist.formattedSongCount)
                                            .font(.system(size: 13))
                                            .foregroundColor(.white.opacity(0.5))
                                    }

                                    Spacer()

                                    Image(systemName: isInPlaylist ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 22))
                                        .foregroundColor(isInPlaylist ? .cyan : .white.opacity(0.3))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.04))
                                .cornerRadius(14)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .alert("Nueva Playlist", isPresented: $showingCreateAlert) {
            TextField("Nombre de la playlist", text: $newPlaylistName)
            Button("Crear") {
                if !newPlaylistName.trimmingCharacters(in: .whitespaces).isEmpty {
                    let created = playlistService.createPlaylist(title: newPlaylistName)
                    playlistService.addSong(song, to: created.id)
                    newPlaylistName = ""
                }
            }
            Button("Cancelar", role: .cancel) {
                newPlaylistName = ""
            }
        } message: {
            Text("Ingresa un nombre para tu nueva lista de reproducción.")
        }
    }
}
