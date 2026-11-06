import SwiftUI

public struct QueueView: View {
    @ObservedObject var player = AudioPlayerService.shared
    @ObservedObject var theme = ThemeManager.shared
    @State private var isEditing = false

    public init() {}

    private var upcomingTracks: [SongItem] {
        let baseOffset = player.queueIndex + 1
        guard baseOffset < player.queue.count else { return [] }
        return Array(player.queue[baseOffset..<player.queue.count])
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header: Grabber + Controls
            HStack {
                Text("Cola de Reproducción")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                if !upcomingTracks.isEmpty {
                    Button(action: {
                        player.reorderQueueForHarmonicFlow()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .bold))
                            Text("Armonizar")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(theme.activeAccentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(theme.activeAccentColor.opacity(0.16))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        player.clearUpcoming()
                    }) {
                        Text("Limpiar")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Now Playing Card
            if let current = player.currentTrack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("SONANDO AHORA")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.45))
                        .padding(.horizontal, 20)

                    HStack(spacing: 12) {
                        ArtworkImageView(urlString: current.thumbnail, songId: current.id, size: 48, cornerRadius: 10)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(current.title)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text(current.artistNames)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.65))
                                .lineLimit(1)
                        }
                        Spacer()
                        DownloadButton(song: current, size: 22)
                            .padding(.trailing, 4)
                        ConvxMiniEqualizerView(isPlaying: player.isPlaying, accentColor: theme.activeAccentColor)
                    }
                    .padding(12)
                    .liquidGlass(cornerRadius: 16, opacity: 0.70)
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 14)
            }

            // Up Next Section Header
            HStack {
                Text("A CONTINUACIÓN (\(upcomingTracks.count))")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.45))

                Spacer()

                Text("Arrastra para reordenar")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 6)

            // Upcoming Reorderable List
            if upcomingTracks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 32))
                        .foregroundColor(theme.activeAccentColor.opacity(0.6))
                    Text("AutoMix Radio agregará más canciones similares automáticamente")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 40)
            } else {
                List {
                    ForEach(Array(upcomingTracks.enumerated()), id: \.element.id) { index, track in
                        HStack(spacing: 12) {
                            ArtworkImageView(urlString: track.thumbnail, songId: track.id, size: 42, cornerRadius: 8)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(track.artistNames)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.6))
                                    .lineLimit(1)
                            }

                            Spacer()

                            DownloadButton(song: track, size: 20)

                            Text(track.formattedDuration)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.45))
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            let targetIndex = player.queueIndex + 1 + index
                            player.queueIndex = targetIndex
                            player.playTrack(track)
                        }
                        .contextMenu {
                            Button(action: { player.playNext(track) }) {
                                Label("Reproducir a continuación", systemImage: "text.line.first.and.arrowtriangle.forward")
                            }
                            Button(action: { player.addToQueue(track) }) {
                                Label("Mover al final de la cola", systemImage: "text.badge.plus")
                            }
                            Button(role: .destructive, action: {
                                player.removeUpcoming(at: IndexSet(integer: index))
                            }) {
                                Label("Eliminar de la cola", systemImage: "trash")
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                    }
                    .onMove { source, destination in
                        player.moveUpcoming(from: source, to: destination)
                    }
                    .onDelete { offsets in
                        player.removeUpcoming(at: offsets)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.editMode, .constant(.active))
            }
        }
    }
}
