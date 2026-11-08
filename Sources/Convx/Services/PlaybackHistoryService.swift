import Foundation

public struct PlayHistoryItem: Codable, Hashable, Sendable {
    public let songId: String
    public let title: String
    public let artistNames: String
    public let thumbnail: String?
    public var playCount: Int
    public var lastPlayedDate: Date
    public var durationListened: Double
    public var song: SongItem?

    public init(song: SongItem, durationListened: Double = 0.0) {
        self.songId = song.id
        self.title = song.title
        self.artistNames = song.artistNames
        self.thumbnail = song.thumbnail
        self.playCount = 1
        self.lastPlayedDate = Date()
        self.durationListened = durationListened
        self.song = song
    }

    public func toSongItem() -> SongItem {
        let dur = song?.duration ?? SongDurationStore.shared.get(for: songId).map { Int($0) }
        if var s = song {
            if s.duration == nil, let d = dur {
                s.duration = d
            }
            return s
        }
        return SongItem(
            id: songId,
            title: title,
            artists: [Artist(name: artistNames)],
            duration: dur,
            thumbnail: thumbnail
        )
    }
}

public final class PlaybackHistoryService: @unchecked Sendable {
    public static let shared = PlaybackHistoryService()

    private let lock = NSLock()
    private let userDefaultsKey = "convx_playback_history_v1"
    private var historyMap: [String: PlayHistoryItem] = [:]
    private var recentSongIds: [String] = [] // Queue of recently played IDs (max 40)
    private var artistPlayCounts: [String: Int] = [:]

    private init() {
        loadHistory()
    }

    public func recordPlay(song: SongItem, duration: Double = 30.0) {
        lock.lock()
        defer { lock.unlock() }

        var resolvedSong = song
        if resolvedSong.duration == nil, let known = SongDurationStore.shared.get(for: song.id) {
            resolvedSong.duration = Int(known)
        }

        // 1. Update Song Record
        if var existing = historyMap[resolvedSong.id] {
            existing.playCount += 1
            existing.lastPlayedDate = Date()
            existing.durationListened += duration
            existing.song = resolvedSong
            historyMap[resolvedSong.id] = existing
        } else {
            let item = PlayHistoryItem(song: resolvedSong, durationListened: duration)
            historyMap[resolvedSong.id] = item
        }

        // 2. Update Recent List (FIFO, max 40)
        recentSongIds.removeAll { $0 == song.id }
        recentSongIds.insert(song.id, at: 0)
        if recentSongIds.count > 40 {
            recentSongIds.removeLast()
        }

        // 3. Update Artist Affinity
        for artist in song.artists {
            let name = artist.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                artistPlayCounts[name, default: 0] += 1
            }
        }

        saveHistory()
        print("[PlaybackHistoryService] Recorded play for '\(song.title)' by \(song.artistNames). Total plays: \(historyMap[song.id]?.playCount ?? 1)")
    }

    public func getArtistAffinity(for artistName: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        let clean = artistName.trimmingCharacters(in: .whitespacesAndNewlines)
        return artistPlayCounts[clean] ?? 0
    }

    public func getTopArtists(limit: Int = 5) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return artistPlayCounts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
    }

    public func getRecentlyPlayedIds() -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return Set(recentSongIds)
    }

    public func getPlayCount(for songId: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return historyMap[songId]?.playCount ?? 0
    }

    public func getRepeatedSongs(minPlayCount: Int = 2, limit: Int = 20) -> [SongItem] {
        lock.lock()
        defer { lock.unlock() }
        return historyMap.values
            .filter { $0.playCount >= minPlayCount }
            .sorted { $0.playCount > $1.playCount }
            .prefix(limit)
            .map { $0.toSongItem() }
    }

    public func getHistoryItems() -> [PlayHistoryItem] {
        lock.lock()
        defer { lock.unlock() }
        return historyMap.values.sorted { $0.lastPlayedDate > $1.lastPlayedDate }
    }

    // MARK: - Persistence
    private func saveHistory() {
        if let data = try? JSONEncoder().encode(historyMap) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
        UserDefaults.standard.set(recentSongIds, forKey: "\(userDefaultsKey)_recents")
        UserDefaults.standard.set(artistPlayCounts, forKey: "\(userDefaultsKey)_artists")
    }

    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([String: PlayHistoryItem].self, from: data) {
            self.historyMap = decoded
        }
        if let recents = UserDefaults.standard.stringArray(forKey: "\(userDefaultsKey)_recents") {
            self.recentSongIds = recents
        }
        if let artists = UserDefaults.standard.dictionary(forKey: "\(userDefaultsKey)_artists") as? [String: Int] {
            self.artistPlayCounts = artists
        }
    }
}
