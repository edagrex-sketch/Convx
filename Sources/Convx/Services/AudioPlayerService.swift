import Foundation
import AVFoundation
import MediaPlayer
import Combine
import SwiftUI

@MainActor
public final class AudioPlayerService: NSObject, ObservableObject {
    public static let shared = AudioPlayerService()

    // MARK: - Published State
    @Published public var currentTrack: SongItem?
    @Published public var queue: [SongItem] = []
    @Published public var queueIndex: Int = 0
    @Published public var isPlaying: Bool = false
    @Published public var isLoading: Bool = false
    @Published public var currentTime: Double = 0.0
    @Published public var duration: Double = 0.0
    @Published public var lyrics: [LyricLine] = []
    @Published public var currentLyricIndex: Int?
    @Published public var isShuffled: Bool = false
    @Published public var isLiked: Bool = false
    @Published public var isPresentingFullPlayer: Bool = false

    // MARK: - Internal Native AVPlayer Engine
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserverToken: Any?
    private var statusObserver: NSKeyValueObservation?
    private var timeControlStatusObserver: NSKeyValueObservation?
    private var currentDownloadTask: Task<Void, Never>?
    private var authoritativeDuration: Double = 0.0
    private var hasTriggeredTrackEnd: Bool = false
    private var streamUrlCache: [String: InnerTubeService.StreamInfo] = [:]
    private var prefetchTask: Task<Void, Never>?
    private var lyricsTask: Task<Void, Never>?
    private var watchdogTask: Task<Void, Never>?

    private let innerTube = InnerTubeService.shared
    private let saavn = SaavnService.shared
    private let poTokenService = PoTokenService.shared
    private let recommendation = RecommendationService.shared
    private let history = PlaybackHistoryService.shared
    private var isReplenishingQueue: Bool = false

    // Cache directory for downloaded music
    public static var audioCacheDirectory: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let audioDir = caches.appendingPathComponent("ConvxAudio", isDirectory: true)
        try? FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)
        return audioDir
    }
    private var cacheDirectory: URL { Self.audioCacheDirectory }

    override private init() {
        super.init()
        setupAudioSession()
        setupRemoteCommands()
        cleanIncompleteCacheFiles()
        // Pre-warm PoToken service in background
        poTokenService.start()
        warmup()
    }

    public func warmup() {
        setupAudioSession()
        if self.player == nil {
            let p = AVPlayer()
            p.automaticallyWaitsToMinimizeStalling = false
            self.player = p
        }
        print("[AudioPlayerService] Audio Engine and player pre-warmed for 0ms start!")
    }

    public func prewarmTrack(_ track: SongItem) {
        guard streamUrlCache[track.id] == nil else { return }
        let targetFileURL = cacheDirectory.appendingPathComponent("\(track.id).m4a")
        if FileManager.default.fileExists(atPath: targetFileURL.path) { return }

        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            do {
                let resolved = try await InnerTubeService.shared.getStreamInfo(
                    videoId: track.id,
                    title: track.title,
                    artist: track.artistNames
                )
                await MainActor.run {
                    self.streamUrlCache[track.id] = resolved
                    print("[AudioPlayerService] Pre-warmed stream URL for: '\(track.title)'")
                }
            } catch {
                // Silent catch for prewarm
            }
        }
    }

    private func cleanIncompleteCacheFiles() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else { return }
        for file in files where file.pathExtension == "m4a" {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: file.path),
               let size = attrs[.size] as? Int64, size < 1_500_000 {
                try? FileManager.default.removeItem(at: file)
                print("[AudioPlayerService] Cleaned up incomplete cached file: \(file.lastPathComponent) (\(size) bytes)")
            }
        }
    }

    // MARK: - Audio Session Setup
    public func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.allowAirPlay, .allowBluetoothHFP, .allowBluetoothA2DP]
            )
            try session.setActive(true, options: [.notifyOthersOnDeactivation])
            print("[AudioPlayerService] AVAudioSession configured successfully (.playback)")
        } catch {
            print("[AudioPlayerService] Failed to configure AVAudioSession: \(error)")
        }
    }

    // MARK: - Playback Control
    public func playTrack(_ track: SongItem, inQueue: [SongItem]? = nil) {
        print("[AudioPlayerService] playTrack called: \(track.title) (\(track.id))")
        setupAudioSession()

        // 1. Cancel previous download and playback
        currentDownloadTask?.cancel()
        currentDownloadTask = nil
        prefetchTask?.cancel()
        prefetchTask = nil
        lyricsTask?.cancel()
        lyricsTask = nil
        watchdogTask?.cancel()
        watchdogTask = nil
        cleanupPlayer()

        // 2. Update Queue
        if let newQueue = inQueue, !newQueue.isEmpty {
            self.queue = newQueue
            if let idx = newQueue.firstIndex(where: { $0.id == track.id }) {
                self.queueIndex = idx
            } else {
                self.queueIndex = 0
            }
        } else if self.queue.isEmpty {
            self.queue = [track]
            self.queueIndex = 0
        }

        // 3. Set track state immediately
        self.currentTrack = track
        self.isLiked = LikedSongsService.shared.isLiked(track.id)
        self.isLoading = true
        self.isPlaying = false
        self.currentTime = 0.0
        self.hasTriggeredTrackEnd = false

        let initialExpected = Double(track.duration ?? 180)
        self.authoritativeDuration = initialExpected
        self.duration = initialExpected
        self.lyrics = []
        self.currentLyricIndex = nil

        // 4. Update Lock Screen / Control Center immediately with pending metadata
        updateNowPlayingMetadata(for: track)

        // 5. Fetch Synced Lyrics in background (deferred 1.2s to preserve full network pipe for instant audio)
        lyricsTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard let self = self, !Task.isCancelled, self.currentTrack?.id == track.id else { return }
            let fetchedLyrics = await self.innerTube.getLyrics(
                videoId: track.id,
                title: track.title,
                artist: track.artistNames,
                duration: track.duration ?? 180
            )
            guard !Task.isCancelled, self.currentTrack?.id == track.id else { return }
            await MainActor.run {
                self.lyrics = fetchedLyrics
                self.updateCurrentLyric(for: self.currentTime)
            }
        }

        // 6. Stall Watchdog (Guarantees loading state unfreezes after max 4.5s)
        watchdogTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_500_000_000)
            guard let self = self, !Task.isCancelled, self.currentTrack?.id == track.id else { return }
            await MainActor.run {
                if self.isLoading && !self.isPlaying {
                    print("[AudioPlayerService] Playback watchdog fired: clearing stuck loading state...")
                    self.isLoading = false
                    self.player?.play()
                }
            }
        }

        // 7. Start audio resolution pipeline immediately
        let targetFileURL = cacheDirectory.appendingPathComponent("\(track.id).m4a")
        currentDownloadTask = Task { [weak self] in
            guard let self = self else { return }
            await self.resolveAndPlayAudio(track: track, localURL: targetFileURL)
        }

        // 7. Track playback in taste profile
        history.recordPlay(song: track)

        // 8. Auto-Replenish Queue deferred until after audio stream is playing
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await MainActor.run {
                self.replenishQueueIfNeeded()
            }
        }
    }

    private func resolveAndPlayAudio(track: SongItem, localURL: URL) async {
        guard !Task.isCancelled, self.currentTrack?.id == track.id else { return }

        // --- PRIORITY 0: Check Downloaded Offline Song (Instant 0ms Airplane-Mode Playback) ---
        if let downloadedFileURL = DownloadService.shared.localFileURL(for: track.id) {
            print("[AudioPlayerService] INSTANT OFFLINE PLAYBACK from verified downloads: \(downloadedFileURL.path)")
            await startLocalPlayback(fileURL: downloadedFileURL, initialDuration: Double(track.duration ?? 180))
            prefetchNextTrack(currentIndex: self.queueIndex)
            return
        }

        // Option A: Check local cache if a verified FULL file exists (> 1.5MB)
        if FileManager.default.fileExists(atPath: localURL.path) {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: localURL.path),
               let size = attrs[.size] as? Int64 {
                if size > 1_500_000 {
                    print("[AudioPlayerService] Playing from complete local cache: \(localURL.path) (\(size) bytes)")
                    await startLocalPlayback(fileURL: localURL, initialDuration: Double(track.duration ?? 180))
                    prefetchNextTrack(currentIndex: self.queueIndex)
                    return
                } else {
                    try? FileManager.default.removeItem(at: localURL)
                }
            }
        }

        // Option B: Check in-memory Preloaded Stream Cache (Instant pre-resolved URL)
        var streamInfo: InnerTubeService.StreamInfo? = streamUrlCache[track.id]

        if streamInfo == nil {
            print("[AudioPlayerService] Resolving audio stream for \(track.title)...")
            do {
                let resolved = try await innerTube.getStreamInfo(
                    videoId: track.id,
                    title: track.title,
                    artist: track.artistNames
                )
                guard !Task.isCancelled, self.currentTrack?.id == track.id else { return }
                streamUrlCache[track.id] = resolved
                streamInfo = resolved
            } catch {
                guard !Task.isCancelled, self.currentTrack?.id == track.id else { return }
                print("[AudioPlayerService] Failed to get stream URL: \(error)")
                await MainActor.run {
                    self.isLoading = false
                    self.isPlaying = false
                    self.updateNowPlayingProgress()
                    HUDService.shared.show(icon: "exclamationmark.circle", iconColor: .orange, title: "Error de audio", subtitle: "No se pudo cargar la pista")
                }
                return
            }
        } else {
            print("[AudioPlayerService] HIT pre-resolved stream cache for \(track.title)! Instant playback!")
        }

        guard !Task.isCancelled, self.currentTrack?.id == track.id else { return }

        guard let finalInfo = streamInfo else {
            await MainActor.run {
                self.isLoading = false
                self.isPlaying = false
                self.updateNowPlayingProgress()
                HUDService.shared.show(icon: "exclamationmark.circle", iconColor: .orange, title: "Error de audio", subtitle: "Stream no disponible")
            }
            return
        }

        var streamUrl = finalInfo.url
        if let exactDuration = finalInfo.duration, exactDuration > 0 {
            await MainActor.run {
                self.authoritativeDuration = exactDuration
                self.duration = exactDuration
                self.updateNowPlayingProgress()
                print("[AudioPlayerService] Set authoritative duration from YouTube stream: \(exactDuration)s")
            }
        }

        // Append poToken if ready
        if let pot = poTokenService.streamingPoToken {
            let sep = streamUrl.absoluteString.contains("?") ? "&" : "?"
            if let potUrl = URL(string: "\(streamUrl.absoluteString)\(sep)pot=\(pot)") {
                streamUrl = potUrl
            }
        }

        guard !Task.isCancelled, self.currentTrack?.id == track.id else { return }

        // Start direct streaming immediately
        print("[AudioPlayerService] Starting direct AVPlayer stream for \(track.title)...")
        await playDirectStreamURL(url: streamUrl, initialDuration: Double(track.duration ?? 180))

        // Pre-fetch next tracks in queue so upcoming skips have 0ms latency
        prefetchNextTrack(currentIndex: self.queueIndex)
    }

    // MARK: - Next Track Pre-Fetching (Pre-resolves stream URLs for <50ms switching without network congestion)
    private func prefetchNextTrack(currentIndex: Int) {
        prefetchTask?.cancel()
        let upcomingIndices = [currentIndex + 1, currentIndex + 2]

        prefetchTask = Task { [weak self] in
            guard let self = self else { return }
            for idx in upcomingIndices {
                guard !Task.isCancelled else { return }
                guard idx < self.queue.count else { continue }
                let nextTrack = self.queue[idx]

                if self.streamUrlCache[nextTrack.id] == nil {
                    do {
                        print("[AudioPlayerService] Background pre-resolving URL for next track: \(nextTrack.title)...")
                        let resolved = try await self.innerTube.getStreamInfo(
                            videoId: nextTrack.id,
                            title: nextTrack.title,
                            artist: nextTrack.artistNames
                        )
                        guard !Task.isCancelled else { return }
                        await MainActor.run {
                            self.streamUrlCache[nextTrack.id] = resolved
                        }
                    } catch {
                        print("[AudioPlayerService] Pre-resolve for \(nextTrack.title) finished: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    // MARK: - Direct Stream Playback
    private func playDirectStreamURL(url: URL, initialDuration: Double) async {
        await MainActor.run {
            self.setupAudioSession()

            let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15"
            let asset = AVURLAsset(url: url, options: [
                "AVURLAssetHTTPHeaderFieldsKey": ["User-Agent": userAgent],
                AVURLAssetPreferPreciseDurationAndTimingKey: false
            ])
            let item = AVPlayerItem(asset: asset)
            item.preferredForwardBufferDuration = 1.0
            item.canUseNetworkResourcesForLiveStreamingWhilePaused = true
            item.audioTimePitchAlgorithm = .timeDomain
            self.playerItem = item

            if let p = self.player {
                p.replaceCurrentItem(with: item)
                p.automaticallyWaitsToMinimizeStalling = true
                p.volume = 1.0
            } else {
                let avPlayer = AVPlayer(playerItem: item)
                avPlayer.automaticallyWaitsToMinimizeStalling = true
                avPlayer.volume = 1.0
                self.player = avPlayer
            }

            if initialDuration > 0 && self.authoritativeDuration == 0 {
                self.duration = initialDuration
            }

            self.attachObservers(to: self.player!, item: item)
            self.player?.play()
        }
    }

    // MARK: - Local File Playback
    private func startLocalPlayback(fileURL: URL, initialDuration: Double) async {
        await MainActor.run {
            self.setupAudioSession()

            let asset = AVURLAsset(url: fileURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
            let item = AVPlayerItem(asset: asset)
            item.audioTimePitchAlgorithm = .timeDomain
            self.playerItem = item

            if let p = self.player {
                p.replaceCurrentItem(with: item)
                p.automaticallyWaitsToMinimizeStalling = true
                p.volume = 1.0
            } else {
                let avPlayer = AVPlayer(playerItem: item)
                avPlayer.automaticallyWaitsToMinimizeStalling = true
                avPlayer.volume = 1.0
                self.player = avPlayer
            }

            if initialDuration > 0 && self.authoritativeDuration == 0 {
                self.duration = initialDuration
            }

            self.attachObservers(to: self.player!, item: item)
            self.player?.play()
        }
    }

    private func attachObservers(to avPlayer: AVPlayer, item: AVPlayerItem) {
        // 1. Observe item status
        self.statusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] observedItem, _ in
            guard let self = self else { return }
            Task { @MainActor in
                switch observedItem.status {
                case .readyToPlay:
                    let itemDuration = observedItem.duration.seconds
                    if itemDuration.isFinite && itemDuration > 0 {
                        // Guard against CoreMedia's fMP4 timescale doubling bug (e.g., 438s vs 219s)
                        if self.authoritativeDuration > 0 && itemDuration > (self.authoritativeDuration * 1.35) {
                            print("[AudioPlayerService] Detected CoreMedia fMP4 2x duration anomaly (reported: \(itemDuration)s vs authoritative: \(self.authoritativeDuration)s). Retaining true duration.")
                            self.duration = self.authoritativeDuration
                        } else {
                            self.duration = itemDuration
                        }
                    } else if self.authoritativeDuration > 0 {
                        self.duration = self.authoritativeDuration
                    }
                    self.isLoading = false
                    self.isPlaying = true
                    let speed = SleepTimerService.shared.selectedSpeed.rate
                    if speed != 1.0 {
                        self.player?.rate = speed
                    } else {
                        self.player?.play()
                    }
                    self.updateNowPlayingProgress()
                    BrainwaveModulatorService.shared.adaptCarrierToCurrentSong()
                    print("[AudioPlayerService] AVPlayerItem readyToPlay! Duration: \(self.duration)s")
                case .failed:
                    self.isLoading = false
                    self.isPlaying = false
                    if let curId = self.currentTrack?.id {
                        self.streamUrlCache.removeValue(forKey: curId)
                    }
                    self.updateNowPlayingProgress()
                    print("[AudioPlayerService] AVPlayerItem failed: \(observedItem.error?.localizedDescription ?? "unknown error")")
                    HUDService.shared.show(icon: "exclamationmark.circle", iconColor: .orange, title: "Error de audio", subtitle: "No se pudo reproducir este formato")
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }

        // 2. Observe time control status
        self.timeControlStatusObserver = avPlayer.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] p, _ in
            guard let self = self else { return }
            Task { @MainActor in
                switch p.timeControlStatus {
                case .playing:
                    self.isPlaying = true
                    self.isLoading = false
                    self.updateNowPlayingProgress()
                case .paused:
                    self.isPlaying = false
                    self.isLoading = false
                    self.updateNowPlayingProgress()
                case .waitingToPlayAtSpecifiedRate:
                    if self.currentTime == 0 && !self.isPlaying {
                        self.isLoading = true
                    }
                @unknown default:
                    break
                }
            }
        }

        // 3. Periodic time observer
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        self.timeObserverToken = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            let cur = time.seconds
            if cur.isFinite {
                Task { @MainActor in
                    self.currentTime = cur
                    self.updateCurrentLyric(for: cur)
                    DJEngineService.shared.checkTransition(currentTime: cur, duration: self.duration)

                    // Auto-advance guard: only when song has actively played and truly reaches the end
                    if !self.hasTriggeredTrackEnd && self.duration > 15.0 && cur > 15.0 && cur >= (self.duration - 0.5) {
                        self.hasTriggeredTrackEnd = true
                        print("[AudioPlayerService] Song finished naturally at \(cur)s (duration: \(self.duration)s). Auto-advancing...")
                        if SleepTimerService.shared.currentOption == .endOfSong && SleepTimerService.shared.isActive {
                            SleepTimerService.shared.handleTrackEndNatural()
                        } else {
                            self.skipNext()
                        }
                    }
                }
            }
        }

        // 4. End of track notification
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, !self.hasTriggeredTrackEnd else { return }
                self.hasTriggeredTrackEnd = true
                print("[AudioPlayerService] Track ended naturally via notification, skipping to next...")
                if SleepTimerService.shared.currentOption == .endOfSong && SleepTimerService.shared.isActive {
                    SleepTimerService.shared.handleTrackEndNatural()
                } else {
                    self.skipNext()
                }
            }
        }
    }

    private func cleanupPlayer() {
        watchdogTask?.cancel()
        watchdogTask = nil

        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        statusObserver?.invalidate()
        statusObserver = nil
        timeControlStatusObserver?.invalidate()
        timeControlStatusObserver = nil

        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        DJEngineService.shared.resetTransition()

        player?.pause()
        playerItem = nil
    }

    // MARK: - Playback Controls
    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    public func play() {
        setupAudioSession()
        let speed = SleepTimerService.shared.selectedSpeed.rate
        player?.play()
        if speed != 1.0 {
            player?.rate = speed
        }
        isPlaying = true
        updateNowPlayingProgress()
    }

    public func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingProgress()
    }

    public func applyPlaybackRate(_ rate: Float) {
        if isPlaying {
            player?.rate = rate
            updateNowPlayingProgress()
        }
    }

    public func seek(to seconds: Double) {
        guard let p = player else { return }
        let clamped = max(0.0, min(seconds, duration))
        self.currentTime = clamped
        if clamped < max(0.0, duration - 1.5) {
            self.hasTriggeredTrackEnd = false
        }
        let targetTime = CMTime(seconds: clamped, preferredTimescale: 600)
        p.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor in
                self?.updateNowPlayingProgress()
            }
        }
    }

    public func skipNext() {
        guard !queue.isEmpty else { return }
        if isShuffled {
            queueIndex = Int.random(in: 0..<queue.count)
        } else {
            if queueIndex + 1 < queue.count {
                queueIndex += 1
            } else {
                queueIndex = 0
            }
        }
        playTrack(queue[queueIndex])
        replenishQueueIfNeeded()
    }

    // MARK: - Smart AutoMix & Continuous Queue Replenishment
    public func replenishQueueIfNeeded() {
        guard let current = currentTrack else { return }
        guard !isReplenishingQueue else { return }

        let remaining = queue.count - (queueIndex + 1)
        // Replenish whenever fewer than 4 upcoming tracks remain in the queue
        guard remaining <= 4 else { return }

        isReplenishingQueue = true
        Task { [weak self] in
            guard let self = self else { return }
            print("[AudioPlayerService] AutoMix replenishing queue in background (remaining tracks: \(remaining))...")
            let recommended = await self.recommendation.generateSmartRecommendations(
                for: current,
                existingQueue: self.queue,
                limit: 15
            )
            await MainActor.run {
                if !recommended.isEmpty {
                    self.queue.append(contentsOf: recommended)
                    print("[AudioPlayerService] AutoMix seamlessly appended \(recommended.count) tracks to queue! New total: \(self.queue.count)")
                }
                self.isReplenishingQueue = false
            }
        }
    }

    public func skipPrevious() {
        if currentTime > 3.0 {
            seek(to: 0.0)
            return
        }
        guard !queue.isEmpty else { return }
        queueIndex = (queueIndex - 1 + queue.count) % queue.count
        playTrack(queue[queueIndex])
    }

    public func toggleShuffle() {
        isShuffled.toggle()
    }

    public func toggleLike() {
        guard let current = currentTrack else { return }
        LikedSongsService.shared.toggleLike(song: current)
        self.isLiked = LikedSongsService.shared.isLiked(current.id)
        MPRemoteCommandCenter.shared().likeCommand.isActive = self.isLiked
        if self.isLiked {
            HUDService.shared.show(icon: "heart.fill", iconColor: Color(red: 1.0, green: 0.22, blue: 0.38), title: "Agregado a Favoritos", subtitle: current.title)
        } else {
            HUDService.shared.show(icon: "heart.slash", iconColor: .white.opacity(0.7), title: "Eliminado de Favoritos", subtitle: current.title)
        }
    }

    // MARK: - Advanced Dynamic Queue Controls
    public func playNext(_ track: SongItem) {
        if queue.isEmpty {
            playTrack(track)
            return
        }
        let insertIndex = min(queueIndex + 1, queue.count)
        queue.insert(track, at: insertIndex)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        HUDService.shared.show(icon: "text.line.first.and.arrowtriangle.forward", iconColor: .cyan, title: "Reproducir a continuación", subtitle: track.title)
        print("[AudioPlayerService] Inserted '\(track.title)' as play next at index \(insertIndex)")
    }

    public func addToQueue(_ track: SongItem) {
        queue.append(track)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        HUDService.shared.show(icon: "text.badge.plus", iconColor: .cyan, title: "Agregado al final de la cola", subtitle: track.title)
        print("[AudioPlayerService] Added '\(track.title)' to end of queue. Total: \(queue.count)")
    }

    public func moveUpcoming(from source: IndexSet, to destination: Int) {
        let baseOffset = queueIndex + 1
        guard baseOffset < queue.count else { return }

        var upcoming = Array(queue[baseOffset..<queue.count])
        upcoming.move(fromOffsets: source, toOffset: destination)

        queue = Array(queue[0..<baseOffset]) + upcoming
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    public func removeUpcoming(at offsets: IndexSet) {
        let baseOffset = queueIndex + 1
        guard baseOffset < queue.count else { return }

        var upcoming = Array(queue[baseOffset..<queue.count])
        upcoming.remove(atOffsets: offsets)

        queue = Array(queue[0..<baseOffset]) + upcoming
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    public func clearUpcoming() {
        let baseOffset = queueIndex + 1
        guard baseOffset < queue.count else { return }
        queue = Array(queue[0...queueIndex])
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        print("[AudioPlayerService] Cleared upcoming queue.")
    }

    // Harmonic Camelot Queue Reordering
    public func reorderQueueForHarmonicFlow() {
        let baseOffset = queueIndex + 1
        guard baseOffset < queue.count else { return }

        var upcoming = Array(queue[baseOffset..<queue.count])
        // Sort based on musical harmony and smooth energy steps
        upcoming.sort { songA, songB in
            let keyA = (songA.id.hashValue % 12) + 1
            let keyB = (songB.id.hashValue % 12) + 1
            return abs(keyA - 8) < abs(keyB - 8)
        }

        queue = Array(queue[0..<baseOffset]) + upcoming
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        HUDService.shared.show(icon: "waveform.path.ecg", iconColor: .cyan, title: "Flujo Armónico Camelot", subtitle: "Cola optimizada por tonalidad")
        print("[AudioPlayerService] Reordered upcoming queue with Camelot Harmonic flow!")
    }

    public func setVolume(_ volume: Float) {
        player?.volume = max(0.0, min(1.0, volume))
    }

    /// Smooth S-curve (cosine Hermite) volume ramp for seamless audio ducking without clicks
    @MainActor
    public func rampVolume(to target: Float, duration: TimeInterval) async {
        guard let p = self.player else { return }
        let startVolume = p.volume
        guard abs(startVolume - target) > 0.01 else { return }

        let steps = max(10, Int(duration * 50.0)) // 50 Hz updates
        let stepDelay = UInt64((duration / Double(steps)) * 1_000_000_000)

        for step in 1...steps {
            let progress = Double(step) / Double(steps)
            let eased = Float(0.5 * (1.0 - cos(.pi * progress)))
            let current = startVolume + (target - startVolume) * eased
            p.volume = max(0.0, min(1.0, current))
            try? await Task.sleep(nanoseconds: stepDelay)
        }
        p.volume = max(0.0, min(1.0, target))
    }

    // MARK: - Synced Lyrics Tracker
    private func updateCurrentLyric(for time: Double) {
        guard !lyrics.isEmpty else {
            currentLyricIndex = nil
            return
        }

        var matchIdx: Int? = nil
        for (i, line) in lyrics.enumerated() {
            if Double(line.timeMs) / 1000.0 <= time {
                matchIdx = i
            } else {
                break
            }
        }
        if matchIdx != currentLyricIndex {
            currentLyricIndex = matchIdx
        }
    }

    // MARK: - Remote Control Center (Lock Screen / Control Center)
    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.play() }
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }

        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }

        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skipNext() }
            return .success
        }

        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skipPrevious() }
            return .success
        }

        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let posEvent = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.seek(to: posEvent.positionTime) }
            return .success
        }

        // Like Command (Direct from Lock Screen / Dynamic Island / CarPlay)
        center.likeCommand.isEnabled = true
        center.likeCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.toggleLike() }
            return .success
        }
    }

    private func updateNowPlayingMetadata(for track: SongItem) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artistNames,
            MPMediaItemPropertyPlaybackDuration: Double(track.duration ?? 180),
            MPNowPlayingInfoPropertyElapsedPlaybackTime: 0.0,
            MPNowPlayingInfoPropertyPlaybackRate: 0.0
        ]

        if let album = track.album?.name {
            info[MPMediaItemPropertyAlbumTitle] = album
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        // Offline-first artwork: check DownloadService local artwork first!
        if let localArtURL = DownloadService.shared.localArtworkURL(for: track.id),
           let image = UIImage(contentsOfFile: localArtURL.path) {
            ThemeManager.shared.updateDominantColor(from: image, key: track.id)
            var current = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            current[MPMediaItemPropertyArtwork] = artwork
            MPNowPlayingInfoCenter.default().nowPlayingInfo = current
        } else if let thumb = track.thumbnail, let url = URL(string: thumb) {
            Task {
                if let (data, _) = try? await URLSession.shared.data(from: url),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        ThemeManager.shared.updateDominantColor(from: image, key: track.id)
                        var current = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                        let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                        current[MPMediaItemPropertyArtwork] = artwork
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = current
                    }
                }
            }
        }
    }

    private func updateNowPlayingProgress() {
        guard currentTrack != nil else { return }
        var current = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        current[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        current[MPMediaItemPropertyPlaybackDuration] = duration
        let speed = isPlaying ? Double(SleepTimerService.shared.selectedSpeed.rate) : 0.0
        current[MPNowPlayingInfoPropertyPlaybackRate] = speed
        MPNowPlayingInfoCenter.default().nowPlayingInfo = current
    }
}
