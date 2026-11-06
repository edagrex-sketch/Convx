import SwiftUI

public struct BatchDownloadButton: View {
    @ObservedObject private var downloadService = DownloadService.shared
    let collectionId: String
    let title: String
    let songs: [SongItem]
    @State private var showingActionSheet = false

    public init(collectionId: String, title: String = "Descargar", songs: [SongItem]) {
        self.collectionId = collectionId
        self.title = title
        self.songs = songs
    }

    private var isDownloading: Bool {
        downloadService.isCollectionDownloading(id: collectionId)
    }

    private var isAllDownloaded: Bool {
        downloadService.isAllDownloaded(songs: songs)
    }

    private var progress: Double {
        downloadService.batchProgress(for: collectionId)
    }

    public var body: some View {
        Button(action: handleAction) {
            HStack(spacing: 8) {
                if isDownloading {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 2)
                        Circle()
                            .trim(from: 0, to: CGFloat(max(0.05, progress)))
                            .stroke(Color.cyan, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.2), value: progress)
                        Image(systemName: "stop.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.cyan)
                    }
                    .frame(width: 16, height: 16)

                    Text(String(format: "%.0f%%", progress * 100))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.cyan)
                } else if isAllDownloaded {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.cyan)

                    Text("Descargado")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.cyan)
                } else {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))

                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isAllDownloaded ? Color.cyan.opacity(0.15) : (isDownloading ? Color.cyan.opacity(0.1) : Color.white.opacity(0.08)))
            )
            .overlay(
                Capsule()
                    .stroke(
                        isAllDownloaded ? Color.cyan.opacity(0.4) : (isDownloading ? Color.cyan.opacity(0.3) : Color.white.opacity(0.12)),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .confirmationDialog("Descargas", isPresented: $showingActionSheet, titleVisibility: .visible) {
            Button("Eliminar descargas del álbum", role: .destructive) {
                downloadService.deleteCollection(songs: songs)
            }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private func handleAction() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if isDownloading {
            downloadService.cancelCollectionDownload(id: collectionId)
        } else if isAllDownloaded {
            showingActionSheet = true
        } else {
            HUDService.shared.show(icon: "arrow.down.circle.fill", iconColor: .cyan, title: "Descargando colección", subtitle: "\(songs.count) canciones")
            downloadService.downloadCollection(id: collectionId, songs: songs)
        }
    }
}
