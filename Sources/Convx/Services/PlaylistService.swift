import Foundation
import Combine

@MainActor
public final class PlaylistService: ObservableObject {
    public static let shared = PlaylistService()

    @Published public private(set) var playlists: [UserPlaylist] = []

    private let storageURL: URL

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.storageURL = docs.appendingPathComponent("user_playlists_v1.json")
        loadPlaylists()
    }

    @discardableResult
    public func createPlaylist(title: String, description: String? = nil) -> UserPlaylist {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = cleanTitle.isEmpty ? "Mi Playlist #\(playlists.count + 1)" : cleanTitle
        let newPlaylist = UserPlaylist(title: finalTitle, descriptionText: description)
        playlists.insert(newPlaylist, at: 0)
        savePlaylists()
        print("[PlaylistService] Created playlist: '\(finalTitle)' (\(newPlaylist.id))")
        return newPlaylist
    }

    public func addSong(_ song: SongItem, to playlistId: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else { return }
        // Prevent duplicate songs in playlist
        if !playlists[index].songs.contains(where: { $0.id == song.id }) {
            playlists[index].songs.append(song)
            savePlaylists()
            print("[PlaylistService] Added '\(song.title)' to '\(playlists[index].title)'")
        }
    }

    public func removeSong(songId: String, from playlistId: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else { return }
        playlists[index].songs.removeAll { $0.id == songId }
        savePlaylists()
        print("[PlaylistService] Removed '\(songId)' from '\(playlists[index].title)'")
    }

    public func deletePlaylist(playlistId: UUID) {
        playlists.removeAll { $0.id == playlistId }
        savePlaylists()
        print("[PlaylistService] Deleted playlist: \(playlistId)")
    }

    public func isSongInPlaylist(songId: String, playlistId: UUID) -> Bool {
        guard let playlist = playlists.first(where: { $0.id == playlistId }) else { return false }
        return playlist.songs.contains { $0.id == songId }
    }

    private func savePlaylists() {
        do {
            let data = try JSONEncoder().encode(playlists)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            print("[PlaylistService] Failed to save playlists: \(error)")
        }
    }

    private func loadPlaylists() {
        guard FileManager.default.fileExists(atPath: storageURL.path),
              let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([UserPlaylist].self, from: data) else {
            return
        }
        self.playlists = decoded
    }
}
