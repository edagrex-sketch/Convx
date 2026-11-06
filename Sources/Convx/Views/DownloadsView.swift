import SwiftUI

public struct DownloadsView: View {
    @ObservedObject private var downloadService = DownloadService.shared
    @ObservedObject private var player = AudioPlayerService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAllAlert = false
    @State private var filterQuery = ""

    public init() {}

    private var filteredSongs: [DownloadedSong] {
        let clean = filterQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return downloadService.downloadedSongs }
        return downloadService.downloadedSongs.filter {
            $0.title.lowercased().contains(clean) ||
            $0.artistNames.lowercased().contains(clean) ||
            ($0.album?.name.lowercased().contains(clean) ?? false)
        }
    }

    public var body: some View {
        ZStack {
            MeshGradientBackground()
                .allowsHitTesting(false)

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

                    Text("Descargas")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    if !downloadService.downloadedSongs.isEmpty {
                        Button(action: { showingDeleteAllAlert = true }) {
                            Image(systemName: "trash")
                                .font(.system(size: 16))
                                .foregroundColor(.red.opacity(0.85))
                                .frame(width: 40, height: 40)
                        }
                    } else {
                        Spacer().frame(width: 40)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                if downloadService.downloadedSongs.isEmpty && downloadService.activeDownloads.isEmpty {
                    emptyStateView
                } else {
                    downloadsContentView
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .confirmationDialog(
            "¿Eliminar todas las descargas?",
            isPresented: $showingDeleteAllAlert,
            titleVisibility: .visible
        ) {
            Button("Eliminar todo", role: .destructive) {
                downloadService.deleteAllDownloads()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se liberarán \(downloadService.formattedTotalStorage) de tu dispositivo.")
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 64))
                .foregroundColor(.white.opacity(0.3))

            Text("Sin canciones descargadas")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            Text("Toca el icono de descarga en cualquier canción para escucharla sin conexión a internet.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
    }

    private var downloadsContentView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 18) {
                // Active Downloads In Progress Section
                if !downloadService.activeDownloads.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            ProgressView()
                                .tint(.cyan)
                                .scaleEffect(0.85)
                            Text("DESCARGANDO (\(downloadService.activeDownloads.count))")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.cyan)
                        }
                        .padding(.horizontal, 20)

                        VStack(spacing: 8) {
                            ForEach(downloadService.activeDownloads) { active in
                                HStack(spacing: 12) {
                                    ArtworkImageView(urlString: active.song.thumbnail, size: 48, cornerRadius: 8)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(active.song.title)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white)
                                            .lineLimit(1)

                                        Text(active.song.artistNames)
                                            .font(.system(size: 12))
                                            .foregroundColor(.white.opacity(0.6))
                                            .lineLimit(1)

                                        // Progress Bar
                                        GeometryReader { geo in
                                            ZStack(alignment: .leading) {
                                                Capsule()
                                                    .fill(Color.white.opacity(0.15))
                                                    .frame(height: 4)
                                                Capsule()
                                                    .fill(Color.cyan)
                                                    .frame(width: max(0, geo.size.width * CGFloat(active.progress)), height: 4)
                                                    .animation(.linear(duration: 0.2), value: active.progress)
                                            }
                                        }
                                        .frame(height: 4)
                                    }

                                    Spacer()

                                    Text(active.percentageString)
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundColor(.cyan)

                                    Button(action: {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        downloadService.cancelDownload(for: active.id)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(.white.opacity(0.4))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(12)
                                .liquidGlass(cornerRadius: 14, opacity: 0.6)
                                .padding(.horizontal, 18)
                            }
                        }
                    }
                    .padding(.top, 4)
                }

                // Storage and Quick Action Bar
                if !downloadService.downloadedSongs.isEmpty {
                    VStack(spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(downloadService.downloadedSongs.count) canciones")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("Espacio utilizado: \(downloadService.formattedTotalStorage)")
                                    .font(.system(size: 13))
                                    .foregroundColor(.cyan)
                            }
                            Spacer()
                        }

                        // Play All & Shuffle Buttons
                        HStack(spacing: 12) {
                            Button(action: {
                                playAll(shuffled: false)
                            }) {
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

                            Button(action: {
                                playAll(shuffled: true)
                            }) {
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
                    }
                    .padding(16)
                    .liquidGlass(cornerRadius: 18, opacity: 0.7)
                    .padding(.horizontal, 18)
                }

                // Quick Offline Search & Filter Bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.45))

                    TextField("Buscar en canciones descargadas...", text: $filterQuery)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .tint(.cyan)
                        .autocorrectionDisabled()

                    if !filterQuery.isEmpty {
                        Button(action: {
                            filterQuery = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))
                .padding(.horizontal, 18)

                // Songs List
                LazyVStack(spacing: 10) {
                    ForEach(filteredSongs) { downloadedSong in
                        let songItem = downloadedSong.toSongItem()
                        let isCurrentlyPlaying = player.currentTrack?.id == downloadedSong.id

                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            let allSongs = filteredSongs.map { $0.toSongItem() }
                            player.playTrack(songItem, inQueue: allSongs)
                        }) {
                            HStack(spacing: 12) {
                                // Fast in-memory cached artwork
                                ArtworkImageView(
                                    urlString: downloadedSong.thumbnail,
                                    songId: downloadedSong.id,
                                    size: 52,
                                    cornerRadius: 10
                                )

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(downloadedSong.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(isCurrentlyPlaying ? .cyan : .white)
                                        .lineLimit(1)

                                    Text(downloadedSong.artistNames)
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.6))
                                        .lineLimit(1)

                                    HStack(spacing: 6) {
                                        Text(downloadedSong.formattedFileSize)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.cyan.opacity(0.8))

                                        Text("•")
                                            .font(.system(size: 10))
                                            .foregroundColor(.white.opacity(0.3))

                                        Text(downloadedSong.formattedDuration)
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.4))
                                    }
                                }

                                Spacer()

                                if isCurrentlyPlaying {
                                    Image(systemName: "waveform")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.cyan)
                                        .padding(.trailing, 4)
                                }

                                // Delete single download button
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    downloadService.deleteDownload(for: downloadedSong.id)
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14))
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
                        .padding(.horizontal, 18)
                    }
                }

                Spacer().frame(height: 165)
            }
            .padding(.top, 12)
        }
    }

    private func playAll(shuffled: Bool) {
        guard !downloadService.downloadedSongs.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        var list = downloadService.downloadedSongs.map { $0.toSongItem() }
        if shuffled {
            list.shuffle()
        }
        player.playTrack(list[0], inQueue: list)
    }
}
