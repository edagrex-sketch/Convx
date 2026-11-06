import SwiftUI

public struct ArtistDetailView: View {
    let artistId: String
    let initialName: String
    let initialThumbnail: String?

    @ObservedObject private var player = AudioPlayerService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var artistDetail: ArtistDetail?
    @State private var isLoading = true
    @State private var selectedSongForPlaylist: SongItem?
    @State private var selectedAlbum: AlbumItem?
    @State private var showFullBio = false

    public init(artistId: String, initialName: String, initialThumbnail: String? = nil) {
        self.artistId = artistId
        self.initialName = initialName
        self.initialThumbnail = initialThumbnail
    }

    private var displayName: String {
        artistDetail?.name ?? initialName
    }

    private var heroThumbnail: String? {
        artistDetail?.bannerThumbnail ?? artistDetail?.avatarThumbnail ?? initialThumbnail
    }

    private var topSongs: [SongItem] {
        artistDetail?.topSongs ?? []
    }

    public var body: some View {
        ZStack {
            MeshGradientBackground()
                .allowsHitTesting(false)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Hero Header
                    ZStack(alignment: .bottomLeading) {
                        if let hero = heroThumbnail, !hero.isEmpty {
                            AsyncImage(url: URL(string: hero)) { phase in
                                switch phase {
                                case .success(let img):
                                    img
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(height: 280)
                                        .clipped()
                                case .failure, .empty:
                                    LinearGradient(
                                        colors: [Color.cyan.opacity(0.3), Color.black],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    .frame(height: 280)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        } else {
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.25), Color.black],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 280)
                        }

                        // Gradient fade out
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.3),
                                .init(color: .black.opacity(0.7), location: 0.75),
                                .init(color: .black, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 280)

                        // Top Back Button Overlay
                        VStack {
                            HStack {
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    dismiss()
                                }) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 36, height: 36)
                                        .background(Color.black.opacity(0.45))
                                        .clipShape(Circle())
                                }
                                .padding(.leading, 16)
                                .padding(.top, 16)

                                Spacer()
                            }
                            Spacer()
                        }

                        // Artist Name on Hero
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Text(displayName)
                                    .font(.system(size: 32, weight: .heavy))
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 4)

                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.cyan)
                            }

                            Text("Artista oficial")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.75))
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }

                    // Play, Shuffle & Radio Controls
                    VStack(spacing: 20) {
                        HStack(spacing: 12) {
                            Button(action: { playTopSongs(shuffled: false) }) {
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

                            Button(action: { playTopSongs(shuffled: true) }) {
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

                            if !topSongs.isEmpty {
                                BatchDownloadButton(
                                    collectionId: artistId,
                                    title: "Guardar",
                                    songs: topSongs
                                )
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 16)

                        // Top Songs Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Canciones Populares")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 18)

                            if isLoading {
                                HStack {
                                    Spacer()
                                    ProgressView().tint(.cyan)
                                    Spacer()
                                }
                                .padding(.vertical, 24)
                            } else if topSongs.isEmpty {
                                Text("No hay pistas disponibles.")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.45))
                                    .padding(.horizontal, 18)
                            } else {
                                LazyVStack(spacing: 8) {
                                    ForEach(Array(topSongs.prefix(15).enumerated()), id: \.element.id) { index, song in
                                        let isPlaying = player.currentTrack?.id == song.id

                                        SwipeableSongRow(song: song, onPlayNext: {
                                            player.playNext(song)
                                        }) {
                                            Button(action: {
                                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                player.playTrack(song, inQueue: topSongs)
                                            }) {
                                                HStack(spacing: 12) {
                                                    Text("\(index + 1)")
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundColor(isPlaying ? .cyan : .white.opacity(0.4))
                                                        .frame(width: 22)

                                                    ArtworkImageView(urlString: song.thumbnail, size: 48, cornerRadius: 8)

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

                                                    if isPlaying {
                                                        Image(systemName: "waveform")
                                                            .font(.system(size: 14, weight: .bold))
                                                            .foregroundColor(.cyan)
                                                            .padding(.trailing, 4)
                                                    }

                                                    DownloadButton(song: song, size: 20)

                                                    Text(song.formattedDuration)
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.white.opacity(0.4))
                                                }
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
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
                        }

                        // Albums Section
                        if let albums = artistDetail?.albums, !albums.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Álbumes")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 18)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: 14) {
                                        ForEach(albums) { album in
                                            Button(action: {
                                                selectedAlbum = album
                                            }) {
                                                VStack(alignment: .leading, spacing: 6) {
                                                    ArtworkImageView(urlString: album.thumbnail, size: 130, cornerRadius: 14)
                                                        .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)

                                                    Text(album.title)
                                                        .font(.system(size: 13, weight: .semibold))
                                                        .foregroundColor(.white)
                                                        .lineLimit(2)
                                                        .frame(width: 130, alignment: .leading)

                                                    if let year = album.year {
                                                        Text(year)
                                                            .font(.system(size: 11))
                                                            .foregroundColor(.white.opacity(0.5))
                                                    }
                                                }
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 18)
                                }
                            }
                        }

                        // Singles & EPs Section
                        if let singles = artistDetail?.singles, !singles.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Sencillos y EP")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 18)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: 14) {
                                        ForEach(singles) { single in
                                            Button(action: {
                                                selectedAlbum = single
                                            }) {
                                                VStack(alignment: .leading, spacing: 6) {
                                                    ArtworkImageView(urlString: single.thumbnail, size: 130, cornerRadius: 14)
                                                        .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)

                                                    Text(single.title)
                                                        .font(.system(size: 13, weight: .semibold))
                                                        .foregroundColor(.white)
                                                        .lineLimit(2)
                                                        .frame(width: 130, alignment: .leading)

                                                    if let year = single.year {
                                                        Text(year)
                                                            .font(.system(size: 11))
                                                            .foregroundColor(.white.opacity(0.5))
                                                    }
                                                }
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 18)
                                }
                            }
                        }

                        // Biography
                        if let bio = artistDetail?.description, !bio.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Acerca de \(displayName)")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)

                                Text(bio)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.7))
                                    .lineLimit(showFullBio ? nil : 4)

                                Button(action: {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        showFullBio.toggle()
                                    }
                                }) {
                                    Text(showFullBio ? "Mostrar menos" : "Leer más")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.cyan)
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.top, 10)
                        }

                        Spacer().frame(height: 120)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .sheet(item: $selectedSongForPlaylist) { song in
            AddToPlaylistSheet(song: song)
        }
        .sheet(item: $selectedAlbum) { album in
            AlbumDetailView(
                albumId: album.id,
                initialTitle: album.title,
                initialArtist: album.artistName ?? displayName,
                initialThumbnail: album.thumbnail
            )
        }
        .task {
            await loadArtist()
        }
    }

    private func loadArtist() async {
        if let detail = await InnerTubeService.shared.fetchArtistDetails(artistBrowseId: artistId) {
            self.artistDetail = detail
        } else {
            let hits = await InnerTubeService.shared.fetchArtistTopHits(artistBrowseId: artistId)
            self.artistDetail = ArtistDetail(id: artistId, name: initialName, bannerThumbnail: initialThumbnail, topSongs: hits)
        }
        self.isLoading = false
    }

    private func playTopSongs(shuffled: Bool) {
        guard !topSongs.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        var queue = topSongs
        if shuffled { queue.shuffle() }
        player.playTrack(queue[0], inQueue: queue)
    }
}
