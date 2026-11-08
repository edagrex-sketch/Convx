import Foundation

public final class SongDurationStore: @unchecked Sendable {
    public static let shared = SongDurationStore()

    private let userDefaultsKey = "convx_song_durations_v1"
    private let lock = NSLock()
    private var cache: [String: Double] = [:]

    private init() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let dict = try? JSONDecoder().decode([String: Double].self, from: data) {
            self.cache = dict
        }
    }

    public func get(for songId: String) -> Double? {
        lock.lock()
        defer { lock.unlock() }
        return cache[songId]
    }

    public func set(duration: Double, for songId: String) {
        guard duration > 0, duration.isFinite else { return }
        lock.lock()
        defer { lock.unlock() }
        // Keep authoritative duration within reasonable range (max 30 mins)
        guard duration < 1800.0 else { return }
        cache[songId] = duration
        if let data = try? JSONEncoder().encode(cache) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}
