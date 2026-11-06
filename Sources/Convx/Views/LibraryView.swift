import SwiftUI

public struct LibraryView: View {
    @ObservedObject var player = AudioPlayerService.shared
    @ObservedObject var downloadService = DownloadService.shared
    @ObservedObject var likedSongsService = LikedSongsService.shared
    @ObservedObject var playlistService = PlaylistService.shared

    let categories = [
        ("Playlists", "music.note.list"),
        ("Artists", "music.mic"),
        ("Albums", "square.stack"),
        ("Songs", "music.note"),
        ("Downloaded", "arrow.down.circle.fill"),
        ("Liked Songs", "heart.fill")
    ]

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.clear

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        // Title
                        Text("Library")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)

                        // Categories List (Apple Music style rows)
                        VStack(spacing: 0) {
                            ForEach(categories, id: \.0) { item in
                                if item.0 == "Downloaded" {
                                    NavigationLink(destination: DownloadsView()) {
                                        HStack(spacing: 16) {
                                            Image(systemName: item.1)
                                                .font(.system(size: 20))
                                                .foregroundColor(.cyan)
                                                .frame(width: 28)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Descargas")
                                                    .font(.system(size: 17, weight: .regular))
                                                    .foregroundColor(.white)
                                                if !downloadService.downloadedSongs.isEmpty {
                                                    Text("\(downloadService.downloadedSongs.count) canciones • \(downloadService.formattedTotalStorage)")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.white.opacity(0.5))
                                                }
                                            }

                                            Spacer()

                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.white.opacity(0.3))
                                        }
                                        .padding(.vertical, 14)
                                        .padding(.horizontal, 16)
                                    }
                                    .buttonStyle(.plain)
                                } else if item.0 == "Liked Songs" {
                                    NavigationLink(destination: LikedSongsView()) {
                                        HStack(spacing: 16) {
                                            Image(systemName: item.1)
                                                .font(.system(size: 20))
                                                .foregroundColor(.red)
                                                .frame(width: 28)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Canciones que te gustan")
                                                    .font(.system(size: 17, weight: .regular))
                                                    .foregroundColor(.white)
                                                if !likedSongsService.likedSongs.isEmpty {
                                                    Text("\(likedSongsService.likedSongs.count) canciones")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.white.opacity(0.5))
                                                }
                                            }

                                            Spacer()

                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.white.opacity(0.3))
                                        }
                                        .padding(.vertical, 14)
                                        .padding(.horizontal, 16)
                                    }
                                    .buttonStyle(.plain)
                                } else if item.0 == "Playlists" {
                                    NavigationLink(destination: UserPlaylistsView()) {
                                        HStack(spacing: 16) {
                                            Image(systemName: item.1)
                                                .font(.system(size: 20))
                                                .foregroundColor(.cyan)
                                                .frame(width: 28)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Playlists")
                                                    .font(.system(size: 17, weight: .regular))
                                                    .foregroundColor(.white)
                                                if !playlistService.playlists.isEmpty {
                                                    Text("\(playlistService.playlists.count) listas")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.white.opacity(0.5))
                                                }
                                            }

                                            Spacer()

                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.white.opacity(0.3))
                                        }
                                        .padding(.vertical, 14)
                                        .padding(.horizontal, 16)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    Button(action: {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }) {
                                        HStack(spacing: 16) {
                                            Image(systemName: item.1)
                                                .font(.system(size: 20))
                                                .foregroundColor(.cyan)
                                                .frame(width: 28)

                                            Text(item.0)
                                                .font(.system(size: 17, weight: .regular))
                                                .foregroundColor(.white)

                                            Spacer()

                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.white.opacity(0.3))
                                        }
                                        .padding(.vertical, 14)
                                        .padding(.horizontal, 16)
                                    }
                                    .buttonStyle(.plain)
                                }

                                if item.0 != categories.last?.0 {
                                    Divider()
                                        .background(Color.white.opacity(0.12))
                                        .padding(.leading, 60)
                                }
                            }
                        }
                        .liquidGlass(cornerRadius: 18, opacity: 0.65)
                        .padding(.horizontal, 20)

                        // Recently Added Section
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Recently Added")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)

                            if player.queue.isEmpty {
                                HStack {
                                    Spacer()
                                    VStack(spacing: 10) {
                                        Image(systemName: "music.quarternote.3")
                                            .font(.system(size: 36))
                                            .foregroundColor(.white.opacity(0.3))
                                        Text("Play music to build your history")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                    .padding(.vertical, 30)
                                    Spacer()
                                }
                            } else {
                                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 16) {
                                    ForEach(player.queue.prefix(6)) { item in
                                        Button(action: {
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                            player.playTrack(item)
                                        }) {
                                            VStack(alignment: .leading, spacing: 8) {
                                                ArtworkImageView(urlString: item.thumbnail, size: 160, cornerRadius: 14)
                                                    .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 3)

                                                Text(item.title)
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)

                                                Text(item.artistNames)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.white.opacity(0.6))
                                                    .lineLimit(1)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }

                        Spacer().frame(height: 165)
                    }
                }
            }
        }
    }
}
