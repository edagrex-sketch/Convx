import Foundation
import Combine

public final class LikedSongsService: ObservableObject, @unchecked Sendable {
    public static let shared = LikedSongsService()

    private let lock = NSLock()
    private let userDefaultsKey = "convx_liked_songs_v1"

    @Published public private(set) var likedSongs: [SongItem] = []
    private var likedSongsMap: [String: SongItem] = [:]

    private init() {
        loadLikedSongs()
    }

    public func isLiked(_ songId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return likedSongsMap[songId] != nil
    }

    public func toggleLike(song: SongItem) {
        lock.lock()
        if likedSongsMap[song.id] != nil {
            likedSongsMap.removeValue(forKey: song.id)
            print("[LikedSongsService] Unliked '\(song.title)'")
        } else {
            likedSongsMap[song.id] = song
            print("[LikedSongsService] Liked '\(song.title)'")
        }
        let updated = Array(likedSongsMap.values)
        saveLikedSongs()
        lock.unlock()

        DispatchQueue.main.async {
            self.likedSongs = updated
        }
    }

    public func getLikedSongs() -> [SongItem] {
        lock.lock()
        defer { lock.unlock() }
        return Array(likedSongsMap.values)
    }

    public func getLikedSongIds() -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return Set(likedSongsMap.keys)
    }

    public func getLikedArtists() -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        var set = Set<String>()
        for song in likedSongsMap.values {
            for artist in song.artists {
                let trimmed = artist.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if !trimmed.isEmpty { set.insert(trimmed) }
            }
        }
        return set
    }

    private func saveLikedSongs() {
        if let data = try? JSONEncoder().encode(likedSongsMap) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    private func loadLikedSongs() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([String: SongItem].self, from: data) else {
            return
        }
        self.likedSongsMap = decoded
        self.likedSongs = Array(decoded.values)
    }
}
