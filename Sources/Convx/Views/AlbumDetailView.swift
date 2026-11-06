import SwiftUI

public struct AlbumDetailView: View {
    let albumId: String
    let initialTitle: String?
    let initialArtist: String?
    let initialThumbnail: String?

    @ObservedObject private var player = AudioPlayerService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var albumDetail: AlbumDetail?
    @State private var isLoading = true
    @State private var selectedSongForPlaylist: SongItem?

    public init(
        albumId: String,
        initialTitle: String? = nil,
        initialArtist: String? = nil,
        initialThumbnail: String? = nil
    ) {
        self.albumId = albumId
        self.initialTitle = initialTitle
        self.initialArtist = initialArtist
        self.initialThumbnail = initialThumbnail
    }

    private var displayTitle: String {
        albumDetail?.title ?? initialTitle ?? "Álbum"
    }

    private var displayArtist: String {
        albumDetail?.artistName ?? initialArtist ?? ""
    }

    private var displayThumbnail: String? {
        albumDetail?.thumbnail ?? initialThumbnail
    }

    private var tracks: [SongItem] {
        albumDetail?.tracks ?? []
    }

    public var body: some View {
        ZStack {
            MeshGradientBackground()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                // Top Bar
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

                    Text("Álbum")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    Spacer().frame(width: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Album Artwork
                        ArtworkImageView(urlString: displayThumbnail, size: 210, cornerRadius: 22)
                            .shadow(color: .black.opacity(0.6), radius: 20, x: 0, y: 10)

                        // Title & Metadata
                        VStack(spacing: 6) {
                            Text(displayTitle)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)

                            if !displayArtist.isEmpty {
                                Text(displayArtist)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.cyan)
                            }

                            HStack(spacing: 6) {
                                if let year = albumDetail?.year {
                                    Text(year)
                                    Text("•")
                                }
                                Text("\(tracks.count) canciones")
                            }
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.45))
                        }

                        // Play, Shuffle & Batch Download Row
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

                                BatchDownloadButton(collectionId: albumId, title: "Descargar Álbum", songs: tracks)
                            }
                            .padding(.horizontal, 24)
                        }

                        // Tracklist
                        if isLoading {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .tint(.cyan)
                                    .scaleEffect(1.2)
                                Text("Cargando pistas del álbum...")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .padding(.top, 40)
                        } else if tracks.isEmpty {
                            Text("No se encontraron canciones en este álbum.")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.top, 40)
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, song in
                                    let isPlaying = player.currentTrack?.id == song.id

                                    SwipeableSongRow(song: song, onPlayNext: {
                                        player.playNext(song)
                                    }) {
                                        Button(action: {
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                            player.playTrack(song, inQueue: tracks)
                                        }) {
                                            HStack(spacing: 14) {
                                                // Index or Waveform
                                                ZStack {
                                                    if isPlaying {
                                                        Image(systemName: "waveform")
                                                            .font(.system(size: 15, weight: .bold))
                                                            .foregroundColor(.cyan)
                                                    } else {
                                                        Text("\(index + 1)")
                                                            .font(.system(size: 14, weight: .semibold))
                                                            .foregroundColor(.white.opacity(0.4))
                                                    }
                                                }
                                                .frame(width: 24)

                                                VStack(alignment: .leading, spacing: 3) {
                                                    Text(song.title)
                                                        .font(.system(size: 15, weight: .semibold))
                                                        .foregroundColor(isPlaying ? .cyan : .white)
                                                        .lineLimit(1)

                                                    Text(song.artistNames)
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.white.opacity(0.55))
                                                        .lineLimit(1)
                                                }

                                                Spacer()

                                                DownloadButton(song: song, size: 20)

                                                if let dur = song.duration, dur > 0 {
                                                    Text(song.formattedDuration)
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.white.opacity(0.4))
                                                }
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(Color.white.opacity(0.04))
                                            .cornerRadius(12)
                                        }
                                        .buttonStyle(.plain)
                                    }
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
            await loadAlbum()
        }
    }

    private func loadAlbum() async {
        if let detail = await InnerTubeService.shared.fetchAlbumDetails(browseId: albumId) {
            self.albumDetail = detail
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
