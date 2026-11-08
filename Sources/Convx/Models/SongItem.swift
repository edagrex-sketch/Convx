import Foundation

public struct Artist: Codable, Hashable, Sendable {
    public let name: String
    public let id: String?

    public init(name: String, id: String? = nil) {
        self.name = name
        self.id = id
    }
}

public struct ArtistItem: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let thumbnail: String?

    public init(id: String, name: String, thumbnail: String? = nil) {
        self.id = id
        self.name = name
        self.thumbnail = thumbnail
    }
}

public struct Album: Codable, Hashable, Sendable {
    public let name: String
    public let id: String

    public init(name: String, id: String) {
        self.name = name
        self.id = id
    }
}

public struct AlbumItem: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let playlistId: String?
    public let title: String
    public let artistName: String?
    public let year: String?
    public let thumbnail: String?

    public init(
        id: String,
        playlistId: String? = nil,
        title: String,
        artistName: String? = nil,
        year: String? = nil,
        thumbnail: String? = nil
    ) {
        self.id = id
        self.playlistId = playlistId
        self.title = title
        self.artistName = artistName
        self.year = year
        self.thumbnail = thumbnail
    }
}

public struct ArtistDetail: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let bannerThumbnail: String?
    public let avatarThumbnail: String?
    public let description: String?
    public let topSongs: [SongItem]
    public let albums: [AlbumItem]
    public let singles: [AlbumItem]

    public init(
        id: String,
        name: String,
        bannerThumbnail: String? = nil,
        avatarThumbnail: String? = nil,
        description: String? = nil,
        topSongs: [SongItem] = [],
        albums: [AlbumItem] = [],
        singles: [AlbumItem] = []
    ) {
        self.id = id
        self.name = name
        self.bannerThumbnail = bannerThumbnail
        self.avatarThumbnail = avatarThumbnail
        self.description = description
        self.topSongs = topSongs
        self.albums = albums
        self.singles = singles
    }
}

public struct AlbumDetail: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let artistName: String?
    public let year: String?
    public let thumbnail: String?
    public let tracks: [SongItem]

    public init(
        id: String,
        title: String,
        artistName: String? = nil,
        year: String? = nil,
        thumbnail: String? = nil,
        tracks: [SongItem] = []
    ) {
        self.id = id
        self.title = title
        self.artistName = artistName
        self.year = year
        self.thumbnail = thumbnail
        self.tracks = tracks
    }
}

public struct SongItem: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let artists: [Artist]
    public let album: Album?
    public var duration: Int? // seconds
    public let thumbnail: String?
    public let explicit: Bool

    public var artistNames: String {
        if artists.isEmpty { return "Unknown Artist" }
        return artists.map { $0.name }.joined(separator: ", ")
    }

    public var formattedDuration: String {
        guard let duration = duration, duration > 0 else { return "--:--" }
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    public init(
        id: String,
        title: String,
        artists: [Artist],
        album: Album? = nil,
        duration: Int? = nil,
        thumbnail: String? = nil,
        explicit: Bool = false
    ) {
        self.id = id
        self.title = title
        self.artists = artists
        self.album = album
        self.duration = duration
        self.thumbnail = thumbnail
        self.explicit = explicit
    }
}


public struct PlaylistItem: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let author: String?
    public let songCountText: String?
    public let thumbnail: String?

    public init(
        id: String,
        title: String,
        author: String? = nil,
        songCountText: String? = nil,
        thumbnail: String? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.songCountText = songCountText
        self.thumbnail = thumbnail
    }
}

public struct LyricWord: Codable, Hashable, Sendable {
    public let startMs: Int64
    public let endMs: Int64
    public let text: String

    public init(startMs: Int64, endMs: Int64, text: String) {
        self.startMs = startMs
        self.endMs = endMs
        self.text = text
    }
}

public struct LyricLine: Identifiable, Codable, Hashable, Sendable {
    public var id: String { "\(timeMs)_\(text)" }
    public let timeMs: Int64
    public let text: String
    public let words: [LyricWord]

    public var isWordSynced: Bool { !words.isEmpty }

    public init(timeMs: Int64, text: String, words: [LyricWord] = []) {
        self.timeMs = timeMs
        self.text = text
        self.words = words
    }
}

public struct HomeSection: Identifiable, Sendable {
    public var id: String { title }
    public let title: String
    public let subtitle: String?
    public let items: [SongItem]

    public init(title: String, subtitle: String? = nil, items: [SongItem]) {
        self.title = title
        self.subtitle = subtitle
        self.items = items
    }
}
