import SwiftUI

public struct PublicPlaylistDetailView: View {
    let playlist: PlaylistItem
    @ObservedObject private var player = AudioPlayerService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var tracks: [SongItem] = []
    @State private var detailedPlaylist: PlaylistItem?
    @State private var isLoading = true
    @State private var selectedSongForPlaylist: SongItem?

    public init(playlist: PlaylistItem) {
        self.playlist = playlist
    }

    private var activePlaylist: PlaylistItem {
        detailedPlaylist ?? playlist
    }

    public var body: some View {
        ZStack {
            MeshGradientBackground()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                // Header
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

                    Spacer().frame(width: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Artwork
                        ArtworkImageView(urlString: activePlaylist.thumbnail, size: 200, cornerRadius: 20)
                            .shadow(color: .black.opacity(0.55), radius: 16, x: 0, y: 8)

                        // Title & Metadata
                        VStack(spacing: 4) {
                            Text(activePlaylist.title)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)

                            if let author = activePlaylist.author {
                                Text(author)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }

                            if let count = activePlaylist.songCountText {
                                Text(count)
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.45))
                            }
                        }

                        // Play All & Shuffle Buttons
                        if !tracks.isEmpty {
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
                                    collectionId: activePlaylist.id,
                                    title: "Descargar Playlist",
                                    songs: tracks
                                )
                            }
                            .padding(.horizontal, 24)
                        }

                        // Tracks Loading or List
                        if isLoading {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(1.2)
                                Text("Cargando canciones...")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .padding(.top, 40)
                        } else if tracks.isEmpty {
                            Text("No se encontraron canciones en esta playlist.")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.top, 40)
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(tracks) { song in
                                    let isPlaying = player.currentTrack?.id == song.id

                                    Button(action: {
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        player.playTrack(song, inQueue: tracks)
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

                                            Text(song.formattedDuration)
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.4))
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

                                        Button {
                                            selectedSongForPlaylist = song
                                        } label: {
                                            Label("Agregar a playlist", systemImage: "plus")
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
        }
        .navigationBarBackButtonHidden(true)
        .sheet(item: $selectedSongForPlaylist) { song in
            AddToPlaylistSheet(song: song)
        }
        .task {
            await loadPlaylist()
        }
    }

    private func loadPlaylist() async {
        do {
            let result = try await InnerTubeService.shared.getPlaylist(playlistId: playlist.id)
            if let fetchedPlaylist = result.playlist {
                self.detailedPlaylist = fetchedPlaylist
            }
            self.tracks = result.tracks
        } catch {
            print("[PublicPlaylistDetailView] Error loading playlist: \(error)")
        }
        self.isLoading = false
    }

    private func playAll(shuffled: Bool) {
        guard !tracks.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        var queue = tracks
        if shuffled { queue.shuffle() }
        player.playTrack(queue[0], inQueue: queue)
    }
}
