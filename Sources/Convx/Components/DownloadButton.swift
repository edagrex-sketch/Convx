import SwiftUI

public struct DownloadButton: View {
    @ObservedObject private var downloadService = DownloadService.shared
    let song: SongItem
    let size: CGFloat
    @State private var showingActionSheet = false

    public init(song: SongItem, size: CGFloat = 22) {
        self.song = song
        self.size = size
    }

    public var body: some View {
        let state = downloadService.downloadState(for: song.id)

        Button(action: handleAction) {
            ZStack {
                switch state {
                case .notDownloaded:
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: size, weight: .regular))
                        .foregroundColor(.white.opacity(0.65))

                case .resolving, .queued:
                    ProgressView()
                        .tint(.cyan)
                        .scaleEffect(size / 24.0)

                case .downloading(let progress):
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 2.2)
                        Circle()
                            .trim(from: 0, to: CGFloat(progress))
                            .stroke(Color.cyan, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.15), value: progress)
                        Image(systemName: "stop.fill")
                            .font(.system(size: size * 0.35, weight: .bold))
                            .foregroundColor(.cyan)
                    }
                    .frame(width: size, height: size)

                case .downloaded:
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: size, weight: .semibold))
                        .foregroundColor(.cyan)

                case .failed:
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: size, weight: .semibold))
                        .foregroundColor(.orange)
                }
            }
            .frame(width: size + 10, height: size + 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .confirmationDialog(song.title, isPresented: $showingActionSheet, titleVisibility: .visible) {
            Button("Eliminar descarga", role: .destructive) {
                downloadService.deleteDownload(for: song.id)
            }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private func handleAction() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let state = downloadService.downloadState(for: song.id)
        switch state {
        case .notDownloaded, .failed:
            downloadService.startDownload(for: song)
        case .resolving, .queued, .downloading:
            downloadService.cancelDownload(for: song.id)
        case .downloaded:
            showingActionSheet = true
        }
    }
}
