import Foundation

public enum DownloadState: Equatable, Sendable {
    case notDownloaded
    case resolving
    case queued
    case downloading(progress: Double) // 0.0 ... 1.0
    case downloaded
    case failed(error: String)
}

public struct DownloadedSong: Identifiable, Codable, Hashable, Sendable {
    public let id: String                 // videoId / songId
    public let title: String
    public let artists: [Artist]
    public let album: Album?
    public let duration: Int?             // seconds
    public let thumbnail: String?         // remote URL fallback
    public let localAudioFileName: String // e.g. "<id>.m4a"
    public let localArtworkFileName: String? // e.g. "<id>_art.jpg"
    public let fileSizeBytes: Int64
    public let downloadedAt: Date

    public var artistNames: String {
        if artists.isEmpty { return "Unknown Artist" }
        return artists.map { $0.name }.joined(separator: ", ")
    }

    public var fileSizeMB: Double {
        Double(fileSizeBytes) / (1024.0 * 1024.0)
    }

    public var formattedFileSize: String {
        String(format: "%.1f MB", fileSizeMB)
    }

    public var formattedDuration: String {
        guard let duration = duration, duration > 0 else { return "--:--" }
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    public func toSongItem() -> SongItem {
        SongItem(
            id: id,
            title: title,
            artists: artists,
            album: album,
            duration: duration,
            thumbnail: thumbnail
        )
    }
}
