import Foundation
import UIKit
import Combine

public struct ActiveDownload: Identifiable, Sendable {
    public let id: String
    public let song: SongItem
    public var progress: Double // 0.0 ... 1.0

    public var percentageString: String {
        String(format: "%.0f%%", progress * 100)
    }
}

// Thread-safe task mapping helper for URLSession callbacks
final class TaskTracker: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.convx.tasktracker", qos: .userInitiated)
    private var tasks: [Int: SongItem] = [:]

    func setSong(_ song: SongItem, for taskId: Int) {
        queue.sync {
            tasks[taskId] = song
        }
    }

    func getSong(for taskId: Int) -> SongItem? {
        queue.sync {
            tasks[taskId]
        }
    }

    func removeSong(for taskId: Int) {
        queue.sync {
            _ = tasks.removeValue(forKey: taskId)
        }
    }
}

@MainActor
public final class DownloadService: NSObject, ObservableObject {
    public static let shared = DownloadService()

    // Thread-safe static directory URL for delegate callbacks
    public nonisolated static let downloadsDirectoryURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("ConvxDownloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableDir = dir
        try? mutableDir.setResourceValues(values)
        return dir
    }()

    public var downloadsDirectory: URL {
        Self.downloadsDirectoryURL
    }

    // MARK: - Published State
    @Published public private(set) var downloadedSongs: [DownloadedSong] = []
    @Published public private(set) var activeDownloads: [ActiveDownload] = []
    @Published public private(set) var downloadStates: [String: DownloadState] = [:]
    @Published public private(set) var totalStorageBytes: Int64 = 0
    @Published public private(set) var batchProgressMap: [String: Double] = [:]
    @Published public private(set) var isBatchDownloadingMap: [String: Bool] = [:]

    // MARK: - Internal Tasks & Storage
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private var batchCollections: [String: [SongItem]] = [:]
    private var batchTasks: [String: Task<Void, Never>] = [:]
    private nonisolated let taskTracker = TaskTracker()
    private var urlSession: URLSession!

    private let metadataFileURL: URL

    override private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.metadataFileURL = docs.appendingPathComponent("downloaded_songs_v1.json")
        super.init()

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 45
        config.timeoutIntervalForResource = 360
        config.httpMaximumConnectionsPerHost = 4
        self.urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)

        loadMetadata()
        recalculateStorage()
    }

    // MARK: - Status Queries
    public func isDownloaded(_ songId: String) -> Bool {
        if downloadedSongs.contains(where: { $0.id == songId }) {
            return true
        }
        let directAudio = downloadsDirectory.appendingPathComponent("\(songId).m4a")
        if FileManager.default.fileExists(atPath: directAudio.path),
           let attrs = try? FileManager.default.attributesOfItem(atPath: directAudio.path),
           let size = attrs[.size] as? Int64, size > 100_000 {
            return true
        }
        return false
    }

    public func downloadState(for songId: String) -> DownloadState {
        if let state = downloadStates[songId] {
            return state
        }
        return isDownloaded(songId) ? .downloaded : .notDownloaded
    }

    public func localFileURL(for songId: String) -> URL? {
        let directAudio = downloadsDirectory.appendingPathComponent("\(songId).m4a")
        if FileManager.default.fileExists(atPath: directAudio.path),
           let attrs = try? FileManager.default.attributesOfItem(atPath: directAudio.path),
           let size = attrs[.size] as? Int64, size > 100_000 {
            return directAudio
        }

        guard let song = downloadedSongs.first(where: { $0.id == songId }) else { return nil }
        let url = downloadsDirectory.appendingPathComponent(song.localAudioFileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    public func localArtworkURL(for songId: String) -> URL? {
        let directArt = downloadsDirectory.appendingPathComponent("\(songId)_art.jpg")
        if FileManager.default.fileExists(atPath: directArt.path) {
            return directArt
        }

        guard let song = downloadedSongs.first(where: { $0.id == songId }),
              let artName = song.localArtworkFileName else { return nil }
        let url = downloadsDirectory.appendingPathComponent(artName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    public var formattedTotalStorage: String {
        let mb = Double(totalStorageBytes) / (1024.0 * 1024.0)
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024.0)
        }
        return String(format: "%.0f MB", mb)
    }

    // MARK: - Batch Downloads (Albums & Playlists)
    public func isAllDownloaded(songs: [SongItem]) -> Bool {
        guard !songs.isEmpty else { return false }
        return songs.allSatisfy { isDownloaded($0.id) }
    }

    public func isCollectionDownloading(id: String) -> Bool {
        return isBatchDownloadingMap[id] ?? false
    }

    public func batchProgress(for id: String) -> Double {
        return batchProgressMap[id] ?? 0.0
    }

    public func downloadCollection(id: String, songs: [SongItem]) {
        guard !songs.isEmpty else { return }

        if isCollectionDownloading(id: id) {
            cancelCollectionDownload(id: id)
            return
        }

        if isAllDownloaded(songs: songs) {
            return
        }

        isBatchDownloadingMap[id] = true
        batchProgressMap[id] = 0.0
        batchCollections[id] = songs

        let task = Task { [weak self] in
            guard let self = self else { return }
            let total = Double(songs.count)

            for song in songs {
                if Task.isCancelled { break }

                if !self.isDownloaded(song.id) {
                    self.startDownload(for: song)

                    var attempts = 0
                    while !self.isDownloaded(song.id) && !Task.isCancelled && attempts < 100 {
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        attempts += 1
                        if case .failed = self.downloadState(for: song.id) {
                            break
                        }
                    }
                }

                await MainActor.run {
                    let doneCount = songs.filter { self.isDownloaded($0.id) }.count
                    self.batchProgressMap[id] = Double(doneCount) / max(total, 1.0)
                }
            }

            await MainActor.run {
                self.isBatchDownloadingMap[id] = false
                self.batchProgressMap[id] = self.isAllDownloaded(songs: songs) ? 1.0 : 0.0
                self.batchTasks.removeValue(forKey: id)
            }
        }

        batchTasks[id] = task
    }

    public func cancelCollectionDownload(id: String) {
        batchTasks[id]?.cancel()
        batchTasks.removeValue(forKey: id)
        isBatchDownloadingMap[id] = false

        if let songs = batchCollections[id] {
            for song in songs {
                if case .downloading = downloadState(for: song.id) {
                    cancelDownload(for: song.id)
                }
            }
        }
    }

    public func deleteCollection(songs: [SongItem]) {
        for song in songs {
            deleteDownload(for: song.id)
        }
    }

    // MARK: - Download Execution
    public func startDownload(for song: SongItem) {
        guard !isDownloaded(song.id) else {
            downloadStates[song.id] = .downloaded
            return
        }

        if case .downloading = downloadState(for: song.id) { return }

        // FAST PATH: If this song was already cached by AudioPlayerService during playback (> 1MB),
        // we can instantly copy it to permanent downloads without re-downloading over the network!
        let cachedPath = AudioPlayerService.audioCacheDirectory.appendingPathComponent("\(song.id).m4a")
        if FileManager.default.fileExists(atPath: cachedPath.path),
           let attrs = try? FileManager.default.attributesOfItem(atPath: cachedPath.path),
           let size = attrs[.size] as? Int64, size > 1_000_000 {
            print("[DownloadService] FAST PATH: Promoting playback cached file '\(song.title)' (\(size) bytes) to permanent downloads!")
            let audioFileName = "\(song.id).m4a"
            let destURL = downloadsDirectory.appendingPathComponent(audioFileName)
            try? FileManager.default.removeItem(at: destURL)
            do {
                try FileManager.default.copyItem(at: cachedPath, to: destURL)
                Task {
                    await self.finishDownload(song: song, audioFileName: audioFileName, fileSize: size)
                }
                return
            } catch {
                print("[DownloadService] Fast path copy error: \(error), falling back to URLSession task...")
            }
        }

        downloadStates[song.id] = .resolving
        activeDownloads.removeAll { $0.id == song.id }
        activeDownloads.append(ActiveDownload(id: song.id, song: song, progress: 0.0))

        Task {
            do {
                // 1. Resolve Stream URL
                let streamInfo = try await InnerTubeService.shared.getStreamInfo(
                    videoId: song.id,
                    title: song.title,
                    artist: song.artistNames
                )
                var directURL = streamInfo.url
                if let pot = PoTokenService.shared.streamingPoToken {
                    let sep = directURL.absoluteString.contains("?") ? "&" : "?"
                    if let potURL = URL(string: "\(directURL.absoluteString)\(sep)pot=\(pot)") {
                        directURL = potURL
                    }
                }

                // 2. Prepare URLSessionDownloadTask
                var request = URLRequest(url: directURL)
                request.setValue(
                    "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15",
                    forHTTPHeaderField: "User-Agent"
                )

                let task = self.urlSession.downloadTask(with: request)
                let taskId = task.taskIdentifier

                self.taskTracker.setSong(song, for: taskId)

                await MainActor.run {
                    self.downloadTasks[song.id] = task
                    self.downloadStates[song.id] = .downloading(progress: 0.0)
                    task.resume()
                }
            } catch {
                await MainActor.run {
                    print("[DownloadService] Stream resolution failed for \(song.title): \(error.localizedDescription)")
                    self.downloadStates[song.id] = .failed(error: error.localizedDescription)
                    self.activeDownloads.removeAll { $0.id == song.id }
                }
            }
        }
    }

    public func cancelDownload(for songId: String) {
        if let task = downloadTasks[songId] {
            let taskId = task.taskIdentifier
            task.cancel()
            downloadTasks.removeValue(forKey: songId)
            self.taskTracker.removeSong(for: taskId)
        }
        downloadStates.removeValue(forKey: songId)
        activeDownloads.removeAll { $0.id == songId }
    }

    // MARK: - Finalize Successful Download
    fileprivate func finishDownload(song: SongItem, audioFileName: String, fileSize: Int64) async {
        // Download and save offline Artwork
        var artworkFileName: String? = nil
        if let thumb = song.thumbnail, let thumbURL = URL(string: thumb) {
            if let (data, _) = try? await URLSession.shared.data(from: thumbURL) {
                let artName = "\(song.id)_art.jpg"
                let artDest = Self.downloadsDirectoryURL.appendingPathComponent(artName)
                if (try? data.write(to: artDest, options: .atomic)) != nil {
                    artworkFileName = artName
                }
            }
        }

        let downloadedSong = DownloadedSong(
            id: song.id,
            title: song.title,
            artists: song.artists,
            album: song.album,
            duration: song.duration,
            thumbnail: song.thumbnail,
            localAudioFileName: audioFileName,
            localArtworkFileName: artworkFileName,
            fileSizeBytes: fileSize,
            downloadedAt: Date()
        )

        self.downloadedSongs.removeAll { $0.id == song.id }
        self.downloadedSongs.insert(downloadedSong, at: 0)
        self.downloadStates[song.id] = .downloaded
        self.activeDownloads.removeAll { $0.id == song.id }
        self.downloadTasks.removeValue(forKey: song.id)

        self.saveMetadata()
        self.recalculateStorage()
        print("[DownloadService] SUCCESS: Downloaded, moved and indexed '\(song.title)' (\(downloadedSong.formattedFileSize))")
    }

    // MARK: - Delete & Manage
    public func deleteDownload(for songId: String) {
        cancelDownload(for: songId)

        let audioURL = downloadsDirectory.appendingPathComponent("\(songId).m4a")
        try? FileManager.default.removeItem(at: audioURL)

        let artURL = downloadsDirectory.appendingPathComponent("\(songId)_art.jpg")
        try? FileManager.default.removeItem(at: artURL)

        if let song = downloadedSongs.first(where: { $0.id == songId }) {
            let namedAudioURL = downloadsDirectory.appendingPathComponent(song.localAudioFileName)
            try? FileManager.default.removeItem(at: namedAudioURL)
            if let artName = song.localArtworkFileName {
                let namedArtURL = downloadsDirectory.appendingPathComponent(artName)
                try? FileManager.default.removeItem(at: namedArtURL)
            }
        }

        downloadedSongs.removeAll { $0.id == songId }
        downloadStates[songId] = .notDownloaded
        saveMetadata()
        recalculateStorage()
    }

    public func deleteAllDownloads() {
        for song in downloadedSongs {
            cancelDownload(for: song.id)
        }
        try? FileManager.default.removeItem(at: downloadsDirectory)
        try? FileManager.default.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
        downloadedSongs.removeAll()
        downloadStates.removeAll()
        saveMetadata()
        recalculateStorage()
    }

    // MARK: - Internal Metadata Persistence
    private func loadMetadata() {
        if FileManager.default.fileExists(atPath: metadataFileURL.path),
           let data = try? Data(contentsOf: metadataFileURL),
           let decoded = try? JSONDecoder().decode([DownloadedSong].self, from: data) {
            // Verify files actually exist on disk
            self.downloadedSongs = decoded.filter { song in
                let path = downloadsDirectory.appendingPathComponent(song.localAudioFileName).path
                return FileManager.default.fileExists(atPath: path)
            }
        } else {
            self.downloadedSongs = []
        }

        // Set state to downloaded for all verified items
        for song in self.downloadedSongs {
            self.downloadStates[song.id] = .downloaded
        }
    }

    private func saveMetadata() {
        do {
            let data = try JSONEncoder().encode(downloadedSongs)
            try data.write(to: metadataFileURL, options: .atomic)
        } catch {
            print("[DownloadService] Failed to save metadata: \(error)")
        }
    }

    private func recalculateStorage() {
        var total: Int64 = 0
        for song in downloadedSongs {
            total += song.fileSizeBytes
        }
        self.totalStorageBytes = total
    }
}

// MARK: - URLSessionDownloadDelegate
extension DownloadService: URLSessionDownloadDelegate {
    public nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let progress: Double
        if totalBytesExpectedToWrite > 0 {
            progress = max(0.0, min(1.0, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)))
        } else {
            // Fallback estimation for chunked transfers (assume avg 4MB song)
            progress = max(0.0, min(0.95, Double(totalBytesWritten) / 4_000_000.0))
        }

        let taskId = downloadTask.taskIdentifier
        guard let song = self.taskTracker.getSong(for: taskId) else { return }

        Task { @MainActor in
            self.downloadStates[song.id] = .downloading(progress: progress)
            if let idx = self.activeDownloads.firstIndex(where: { $0.id == song.id }) {
                self.activeDownloads[idx].progress = progress
            }
        }
    }

    public nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let taskId = downloadTask.taskIdentifier
        guard let song = self.taskTracker.getSong(for: taskId) else {
            print("[DownloadService] ERROR: No song found for taskId \(taskId)")
            return
        }

        let audioFileName = "\(song.id).m4a"
        let destURL = DownloadService.downloadsDirectoryURL.appendingPathComponent(audioFileName)

        // =========================================================================================
        // CRITICAL FIX: MUST MOVE THE TEMPORARY FILE SYNCHRONOUSLY BEFORE THIS METHOD RETURNS!
        // iOS URLSession strictly deletes `location` the moment didFinishDownloadingTo returns.
        // =========================================================================================
        var moveSucceeded = false
        var fileSize: Int64 = 0

        try? FileManager.default.removeItem(at: destURL)
        do {
            try FileManager.default.moveItem(at: location, to: destURL)
            if let attrs = try? FileManager.default.attributesOfItem(atPath: destURL.path),
               let size = attrs[.size] as? Int64, size > 100_000 {
                fileSize = size
                moveSucceeded = true
                print("[DownloadService] Synchronous file move SUCCESS: \(destURL.path) (\(size) bytes)")
            } else {
                print("[DownloadService] Synchronous file move resulted in file under 100KB (invalid audio stream).")
                try? FileManager.default.removeItem(at: destURL)
            }
        } catch {
            print("[DownloadService] Synchronous file move FAILED: \(error)")
        }

        Task { @MainActor in
            if moveSucceeded {
                await self.finishDownload(song: song, audioFileName: audioFileName, fileSize: fileSize)
            } else {
                self.downloadStates[song.id] = .failed(error: "La descarga falló o el archivo no es válido.")
                self.activeDownloads.removeAll { $0.id == song.id }
                self.downloadTasks.removeValue(forKey: song.id)
            }

            self.taskTracker.removeSong(for: taskId)
        }
    }

    public nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error else { return }
        let taskId = task.taskIdentifier
        let song = self.taskTracker.getSong(for: taskId)
        self.taskTracker.removeSong(for: taskId)

        guard let song = song else { return }
        Task { @MainActor in
            print("[DownloadService] Task completed with error for \(song.title): \(error.localizedDescription)")
            self.downloadStates[song.id] = .failed(error: error.localizedDescription)
            self.activeDownloads.removeAll { $0.id == song.id }
            self.downloadTasks.removeValue(forKey: song.id)
        }
    }
}
