import SwiftUI

public struct UserPlaylistDetailView: View {
    @ObservedObject private var playlistService = PlaylistService.shared
    @ObservedObject private var player = AudioPlayerService.shared
    let playlistId: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false

    public init(playlistId: UUID) {
        self.playlistId = playlistId
    }

    private var playlist: UserPlaylist? {
        playlistService.playlists.first(where: { $0.id == playlistId })
    }

    public var body: some View {
        ZStack {
            MeshGradientBackground()
                .allowsHitTesting(false)

            if let currentPlaylist = playlist {
                VStack(spacing: 0) {
                    // Navigation Header
                    HStack {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                        }

                        Spacer()

                        Text("Playlist")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)

                        Spacer()

                        Menu {
                            Button(role: .destructive, action: {
                                showingDeleteAlert = true
                            }) {
                                Label("Eliminar Playlist", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 20) {
                            // Cover Artwork
                            if let thumb = currentPlaylist.thumbnail {
                                ArtworkImageView(urlString: thumb, size: 200, cornerRadius: 20)
                                    .shadow(color: .black.opacity(0.5), radius: 16, x: 0, y: 8)
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.white.opacity(0.1))
                                        .frame(width: 200, height: 200)
                                    Image(systemName: "music.note.list")
                                        .font(.system(size: 60))
                                        .foregroundColor(.white.opacity(0.3))
                                }
                            }

                            // Title & Info
                            VStack(spacing: 4) {
                                Text(currentPlaylist.title)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)

                                Text(currentPlaylist.formattedSongCount)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.6))
                            }

                            // Play All & Shuffle Buttons
                            if !currentPlaylist.songs.isEmpty {
                                VStack(spacing: 12) {
                                    HStack(spacing: 12) {
                                        Button(action: { playAll(shuffled: false) }) {
                                            HStack(spacing: 8) {
                                                Image(systemName: "play.fill")
                                                    .font(.system(size: 14))
                                                Text("Reproducir")
                                                    .font(.system(size: 15, weight: .semibold))
                                            }
                                            .foregroundColor(.black)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 44)
                                            .background(Color.white)
                                            .cornerRadius(12)
                                        }
                                        .buttonStyle(.plain)

                                        Button(action: { playAll(shuffled: true) }) {
                                            HStack(spacing: 8) {
                                                Image(systemName: "shuffle")
                                                    .font(.system(size: 14))
                                                Text("Aleatorio")
                                                    .font(.system(size: 15, weight: .semibold))
                                            }
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 44)
                                            .background(Color.white.opacity(0.12))
                                            .cornerRadius(12)
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    BatchDownloadButton(
                                        collectionId: currentPlaylist.id.uuidString,
                                        title: "Descargar Playlist",
                                        songs: currentPlaylist.songs
                                    )
                                }
                                .padding(.horizontal, 24)
                            }

                            // Songs List
                            if currentPlaylist.songs.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "music.note.list")
                                        .font(.system(size: 44))
                                        .foregroundColor(.white.opacity(0.2))
                                    Text("Esta playlist está vacía")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.5))
                                    Text("Agrega canciones usando el menú en cualquier canción.")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.35))
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.top, 40)
                                .padding(.horizontal, 30)
                            } else {
                                LazyVStack(spacing: 10) {
                                    ForEach(currentPlaylist.songs) { song in
                                        let isPlaying = player.currentTrack?.id == song.id

                                        Button(action: {
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                            player.playTrack(song, inQueue: currentPlaylist.songs)
                                        }) {
                                            HStack(spacing: 12) {
                                                ArtworkImageView(urlString: song.thumbnail, size: 50, cornerRadius: 10)

                                                VStack(alignment: .leading, spacing: 3) {
                                                    Text(song.title)
                                                        .font(.system(size: 15, weight: .semibold))
                                                        .foregroundColor(isPlaying ? .cyan : .white)
                                                        .lineLimit(1)

                                                    Text(song.artistNames)
                                                        .font(.system(size: 13))
                                                        .foregroundColor(.white.opacity(0.6))
                                                        .lineLimit(1)
                                                }

                                                Spacer()

                                                if isPlaying {
                                                    Image(systemName: "waveform")
                                                        .font(.system(size: 16, weight: .bold))
                                                        .foregroundColor(.cyan)
                                                        .padding(.trailing, 2)
                                                }

                                                DownloadButton(song: song, size: 20)
                                                    .padding(.trailing, 2)

                                                Button(action: {
                                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                                    playlistService.removeSong(songId: song.id, from: playlistId)
                                                }) {
                                                    Image(systemName: "minus.circle")
                                                        .font(.system(size: 18))
                                                        .foregroundColor(.white.opacity(0.35))
                                                        .frame(width: 36, height: 36)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(Color.white.opacity(0.04))
                                            .cornerRadius(14)
                                        }
                                        .buttonStyle(.plain)
                                        .contextMenu {
                                            Button {
                                                player.playNext(song)
                                            } label: {
                                                Label("Reproducir a continuación", systemImage: "text.line.first.and.arrowtriangle.forward")
                                            }

                                            Button {
                                                player.addToQueue(song)
                                            } label: {
                                                Label("Agregar a la cola", systemImage: "text.append")
                                            }
                                        }
                                        .padding(.horizontal, 18)
                                    }
                                }
                            }

                            Spacer().frame(height: 120)
                        }
                        .padding(.top, 10)
                    }
                }
            } else {
                Text("Playlist no encontrada")
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .navigationBarBackButtonHidden(true)
        .confirmationDialog(
            "¿Eliminar playlist?",
            isPresented: $showingDeleteAlert,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                playlistService.deletePlaylist(playlistId: playlistId)
                dismiss()
            }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private func playAll(shuffled: Bool) {
        guard let list = playlist?.songs, !list.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        var queue = list
        if shuffled { queue.shuffle() }
        player.playTrack(queue[0], inQueue: queue)
    }
}
