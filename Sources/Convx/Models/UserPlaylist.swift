import Foundation

public struct UserPlaylist: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var descriptionText: String?
    public var songs: [SongItem]
    public let createdAt: Date

    public var thumbnail: String? {
        songs.first?.thumbnail
    }

    public var formattedSongCount: String {
        songs.count == 1 ? "1 canción" : "\(songs.count) canciones"
    }

    public init(
        id: UUID = UUID(),
        title: String,
        descriptionText: String? = nil,
        songs: [SongItem] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.descriptionText = descriptionText
        self.songs = songs
        self.createdAt = createdAt
    }
}
