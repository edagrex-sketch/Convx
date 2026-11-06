import SwiftUI

public struct LikedSongsView: View {
    @ObservedObject private var likedSongsService = LikedSongsService.shared
    @ObservedObject private var player = AudioPlayerService.shared
    @Environment(\.dismiss) private var dismiss

    public init() {}

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

                    Text("Canciones que te gustan")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    Image(systemName: "heart.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.red)
                        .frame(width: 40, height: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                if likedSongsService.likedSongs.isEmpty {
                    emptyStateView
                } else {
                    likedContentView
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "heart.slash")
                .font(.system(size: 64))
                .foregroundColor(.white.opacity(0.3))

            Text("Sin canciones favoritas")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            Text("Toca el icono de corazón en cualquier canción que te encante para encontrarla aquí rápidamente.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
    }

    private var likedContentView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 18) {
                // Header Banner
                VStack(spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(likedSongsService.likedSongs.count) canciones")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Tus favoritas de siempre")
                                .font(.system(size: 13))
                                .foregroundColor(.red.opacity(0.85))
                        }
                        Spacer()
                    }

                    // Play All & Shuffle Buttons
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
                }
                .padding(16)
                .liquidGlass(cornerRadius: 18, opacity: 0.7)
                .padding(.horizontal, 18)

                // Songs List
                LazyVStack(spacing: 10) {
                    ForEach(likedSongsService.likedSongs) { song in
                        let isCurrentlyPlaying = player.currentTrack?.id == song.id

                        SwipeableSongRow(song: song, onPlayNext: {
                            player.playNext(song)
                        }) {
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                player.playTrack(song, inQueue: likedSongsService.likedSongs)
                            }) {
                                HStack(spacing: 12) {
                                    ArtworkImageView(urlString: song.thumbnail, size: 52, cornerRadius: 10)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(song.title)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(isCurrentlyPlaying ? .cyan : .white)
                                            .lineLimit(1)

                                        Text(song.artistNames)
                                            .font(.system(size: 13))
                                            .foregroundColor(.white.opacity(0.6))
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    if isCurrentlyPlaying {
                                        Image(systemName: "waveform")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.cyan)
                                            .padding(.trailing, 2)
                                    }

                                    DownloadButton(song: song, size: 20)
                                        .padding(.trailing, 4)

                                    Button(action: {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        likedSongsService.toggleLike(song: song)
                                    }) {
                                        Image(systemName: "heart.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(.red)
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
                        }
                        .padding(.horizontal, 18)
                    }
                }

                Spacer().frame(height: 120)
            }
            .padding(.top, 12)
        }
    }

    private func playAll(shuffled: Bool) {
        guard !likedSongsService.likedSongs.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        var list = likedSongsService.likedSongs
        if shuffled {
            list.shuffle()
        }
        player.playTrack(list[0], inQueue: list)
    }
}
