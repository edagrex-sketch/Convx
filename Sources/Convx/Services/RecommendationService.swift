import Foundation

public final class RecommendationService: Sendable {
    public static let shared = RecommendationService()

    private let innerTube = InnerTubeService.shared
    private let history = PlaybackHistoryService.shared
    private let likedService = LikedSongsService.shared

    private init() {}

    /// Automatically generates a tailored queue of recommended tracks based on current song,
    /// liked songs, play repetition history, and sonic vibe continuity.
    public func generateSmartRecommendations(
        for currentSong: SongItem,
        existingQueue: [SongItem],
        limit: Int = 15
    ) async -> [SongItem] {
        print("[RecommendationService] Generating smart recommendations for '\(currentSong.title)' by \(currentSong.artistNames)...")

        // 1. Fetch Candidate Pool via YouTube Automix Radio ("RDAMVM" + videoId)
        let radioTracks = await innerTube.getNext(videoId: currentSong.id, playlistId: "RDAMVM\(currentSong.id)")
        guard !radioTracks.isEmpty else {
            print("[RecommendationService] No radio tracks returned from InnerTube")
            return []
        }

        // 2. Extract User Taste Profile Signals
        let existingIds = Set(existingQueue.map { $0.id })
        let recentIds = history.getRecentlyPlayedIds()
        let topArtists = Set(history.getTopArtists(limit: 6).map { $0.lowercased() })
        let likedSongIds = likedService.getLikedSongIds()
        let likedArtists = likedService.getLikedArtists()
        let currentPrimaryArtist = currentSong.artists.first?.name.lowercased() ?? ""

        // Extract artists appearing in the radio tracks to identify the "vibe neighborhood"
        var radioArtists = Set<String>()
        for track in radioTracks {
            for artist in track.artists {
                let clean = artist.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if !clean.isEmpty { radioArtists.insert(clean) }
            }
        }

        // 3. Score and Rank Radio (Discovery/Vibe) Candidates
        struct ScoredSong {
            let song: SongItem
            let score: Double
            let primaryArtist: String
        }

        var scoredDiscoveryPool: [ScoredSong] = []

        for (index, candidate) in radioTracks.enumerated() {
            if candidate.id == currentSong.id || existingIds.contains(candidate.id) {
                continue
            }

            // Exclude songs played in the last 15 tracks if plenty of alternatives exist
            if recentIds.contains(candidate.id) && radioTracks.count > 8 {
                continue
            }

            let candidateArtist = candidate.artists.first?.name ?? candidate.artistNames
            let candidateArtistLower = candidateArtist.lowercased()

            // A. Base rank score (50.0 down to 1.0 based on YouTube's automated mix order)
            var score = max(1.0, 50.0 - Double(index))

            // B. Liked Song Boost (+35 points if the user has explicitly liked this track)
            if likedSongIds.contains(candidate.id) {
                score += 35.0
            }

            // C. Repetition / Play Count Boost (+4.0 per play, up to +24 points)
            let playCount = history.getPlayCount(for: candidate.id)
            if playCount > 1 {
                score += Double(min(playCount, 6)) * 4.0
            }

            // D. Artist Affinity Boost (How many times has user listened to this artist before?)
            let affinity = history.getArtistAffinity(for: candidateArtist)
            if affinity > 0 {
                score += Double(min(affinity, 5)) * 5.0
            }

            // E. Liked Artists Boost
            if likedArtists.contains(candidateArtistLower) {
                score += 12.0
            }

            // F. Top Artist Boost (User favorite)
            if topArtists.contains(candidateArtistLower) {
                score += 15.0
            }

            // G. Same Artist as Current Track Boost
            if !currentPrimaryArtist.isEmpty && candidateArtistLower == currentPrimaryArtist {
                score += 18.0
            }

            scoredDiscoveryPool.append(ScoredSong(song: candidate, score: score, primaryArtist: candidateArtistLower))
        }

        scoredDiscoveryPool.sort { $0.score > $1.score }

        // 4. Build Familiar Comfort Pool (Liked + Repeated songs that fit the vibe)
        var familiarPool: [SongItem] = []
        let likedSongs = likedService.getLikedSongs()
        let repeatedSongs = history.getRepeatedSongs(minPlayCount: 2, limit: 25)

        // Combine liked and repeated into unified comfort pool
        var seenComfortIds = Set<String>()
        var combinedComfort: [SongItem] = []
        for song in likedSongs + repeatedSongs {
            if !seenComfortIds.contains(song.id) && song.id != currentSong.id && !existingIds.contains(song.id) && !recentIds.contains(song.id) {
                seenComfortIds.insert(song.id)
                combinedComfort.append(song)
            }
        }

        // Score comfort songs by relevance to current vibe/artist
        struct ScoredComfort {
            let song: SongItem
            let score: Double
        }
        var scoredComfortList: [ScoredComfort] = []

        for song in combinedComfort {
            var comfortScore = 10.0
            let songArtists = song.artists.map { $0.name.lowercased() }

            // Huge boost if by the same artist as current song
            if !currentPrimaryArtist.isEmpty && songArtists.contains(currentPrimaryArtist) {
                comfortScore += 40.0
            }

            // Strong boost if by one of the artists in this radio station vibe
            for artist in songArtists {
                if radioArtists.contains(artist) {
                    comfortScore += 25.0
                    break
                }
            }

            // Extra boost if user has repeated this multiple times
            let repeatCount = history.getPlayCount(for: song.id)
            comfortScore += Double(min(repeatCount, 5)) * 4.0

            scoredComfortList.append(ScoredComfort(song: song, score: comfortScore))
        }

        scoredComfortList.sort { $0.score > $1.score }
        familiarPool = scoredComfortList.map { $0.song }

        // 5. Cadence Interleaving: 75% Vibe Discovery + 25% Familiar Favorites
        // We interleave familiar favorites at index 2, 6, 11 (approx 1 every 4 songs)
        var finalSelection: [SongItem] = []
        var selectedIds = Set<String>()
        var artistCountInBatch: [String: Int] = [:]

        var discoveryIndex = 0
        var comfortIndex = 0

        while finalSelection.count < limit && (discoveryIndex < scoredDiscoveryPool.count || comfortIndex < familiarPool.count) {
            let currentTargetSlot = finalSelection.count
            let isComfortSlot = (currentTargetSlot == 2 || currentTargetSlot == 6 || currentTargetSlot == 11)

            if isComfortSlot && comfortIndex < familiarPool.count {
                let comfortTrack = familiarPool[comfortIndex]
                comfortIndex += 1
                if !selectedIds.contains(comfortTrack.id) {
                    selectedIds.insert(comfortTrack.id)
                    finalSelection.append(comfortTrack)
                    continue
                }
            }

            // Otherwise take from discovery pool with diversity filter
            if discoveryIndex < scoredDiscoveryPool.count {
                let candidate = scoredDiscoveryPool[discoveryIndex]
                discoveryIndex += 1

                if selectedIds.contains(candidate.song.id) {
                    continue
                }

                let count = artistCountInBatch[candidate.primaryArtist, default: 0]
                if count >= 3 && scoredDiscoveryPool.count > limit {
                    // Skip to preserve diversity
                    continue
                }

                artistCountInBatch[candidate.primaryArtist] = count + 1
                selectedIds.insert(candidate.song.id)
                finalSelection.append(candidate.song)
            } else if comfortIndex < familiarPool.count {
                // If discovery ran out, take from comfort
                let comfortTrack = familiarPool[comfortIndex]
                comfortIndex += 1
                if !selectedIds.contains(comfortTrack.id) {
                    selectedIds.insert(comfortTrack.id)
                    finalSelection.append(comfortTrack)
                }
            } else {
                break
            }
        }

        // Fallback fill if needed
        if finalSelection.count < limit {
            for item in scoredDiscoveryPool {
                if !selectedIds.contains(item.song.id) {
                    selectedIds.insert(item.song.id)
                    finalSelection.append(item.song)
                    if finalSelection.count >= limit { break }
                }
            }
        }

        print("[RecommendationService] Selected \(finalSelection.count) tracks (including \(familiarPool.prefix(comfortIndex).count) familiar favorites) for seamless queue!")
        for (i, t) in finalSelection.prefix(6).enumerated() {
            let isFamiliar = likedSongIds.contains(t.id) || history.getPlayCount(for: t.id) > 1
            print("  \(i + 1). \(t.title) - \(t.artistNames) \(isFamiliar ? "[★ VIBE FAVORITE]" : "[DISCOVERY]")")
        }

        return finalSelection
    }
}
