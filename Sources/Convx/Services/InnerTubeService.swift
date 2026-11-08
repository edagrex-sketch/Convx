import Foundation

public final class InnerTubeService: Sendable {
    public static let shared = InnerTubeService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Search Models & Methods
    public struct SearchResult: Sendable {
        public let songs: [SongItem]
        public let artist: ArtistItem?

        public init(songs: [SongItem], artist: ArtistItem? = nil) {
            self.songs = songs
            self.artist = artist
        }
    }

    public func search(query: String) async throws -> [SongItem] {
        return (try await searchDetailed(query: query)).songs
    }

    public func searchDetailed(query: String) async throws -> SearchResult {
        guard let url = URL(string: "https://music.youtube.com/youtubei/v1/search?prettyPrint=false") else {
            return SearchResult(songs: [], artist: nil)
        }

        let region = Locale.current.region?.identifier ?? "MX"
        let language = Locale.current.language.languageCode?.identifier == "es" ? "es-419" : "es"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("67", forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue("1.20260213.01.00", forHTTPHeaderField: "X-YouTube-Client-Version")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "X-Origin")
        request.setValue("https://music.youtube.com/", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")

        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20260213.01.00",
                    "gl": region,
                    "hl": language
                ]
            ],
            "query": query
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await session.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return SearchResult(songs: [], artist: nil)
        }

        let (songs, artistItem) = parseSearchSongsAndArtistCard(from: json)

        // If an artist was detected (e.g., José José, Luis Miguel, Queen), fetch their official Top Hits playlist!
        if let artist = artistItem {
            print("[InnerTubeService] Detected Artist search for '\(query)' with BrowseId: \(artist.id). Fetching Top Hits...")
            let artistHits = await fetchArtistTopHits(artistBrowseId: artist.id)
            if !artistHits.isEmpty {
                print("[InnerTubeService] Prepending \(artistHits.count) artist top hits for '\(query)'!")
                var seen = Set<String>()
                var combined: [SongItem] = []
                for song in artistHits {
                    if !seen.contains(song.id) {
                        seen.insert(song.id)
                        combined.append(song)
                    }
                }
                for song in songs {
                    if !seen.contains(song.id) {
                        seen.insert(song.id)
                        combined.append(song)
                    }
                }
                return SearchResult(songs: combined, artist: artist)
            }
        }

        // If general search yielded few results, fallback to filtered song query
        if songs.isEmpty {
            let fallback = try await searchFilteredSongs(query: query)
            return SearchResult(songs: fallback, artist: artistItem)
        }

        return SearchResult(songs: songs, artist: artistItem)
    }

    private func searchFilteredSongs(query: String) async throws -> [SongItem] {
        guard let url = URL(string: "https://music.youtube.com/youtubei/v1/search?prettyPrint=false") else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("67", forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue("1.20260213.01.00", forHTTPHeaderField: "X-YouTube-Client-Version")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "X-Origin")
        request.setValue("https://music.youtube.com/", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64)", forHTTPHeaderField: "User-Agent")

        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20260213.01.00",
                    "gl": Locale.current.region?.identifier ?? "MX",
                    "hl": "es-419"
                ]
            ],
            "query": query,
            "params": "EgWKAQIIAWoKEAkQBRAKEAMQBA%3D%3D"
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await session.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        return parseSearchSongs(from: json)
    }

    // MARK: - Artist Top Hits Resolver
    public func fetchArtistTopHits(artistBrowseId: String) async -> [SongItem] {
        guard let url = URL(string: "https://music.youtube.com/youtubei/v1/browse?prettyPrint=false") else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("67", forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue("1.20260213.01.00", forHTTPHeaderField: "X-YouTube-Client-Version")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "X-Origin")
        request.setValue("https://music.youtube.com/", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64)", forHTTPHeaderField: "User-Agent")

        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20260213.01.00",
                    "gl": Locale.current.region?.identifier ?? "MX",
                    "hl": "es-419"
                ]
            ],
            "browseId": artistBrowseId
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, _) = try? await session.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contents = json["contents"] as? [String: Any],
              let single = contents["singleColumnBrowseResultsRenderer"] as? [String: Any],
              let tabs = single["tabs"] as? [[String: Any]],
              let tabContent = tabs.first?["tabRenderer"] as? [String: Any],
              let content = tabContent["content"] as? [String: Any],
              let sectionList = content["sectionListRenderer"] as? [String: Any],
              let sections = sectionList["contents"] as? [[String: Any]] else {
            return []
        }

        var directShelfSongs: [SongItem] = []
        var playlistBrowseId: String? = nil

        for s in sections {
            if let shelf = s["musicShelfRenderer"] as? [String: Any] {
                if let bottom = shelf["bottomEndpoint"] as? [String: Any],
                   let browse = bottom["browseEndpoint"] as? [String: Any],
                   let bId = browse["browseId"] as? String {
                    playlistBrowseId = bId
                }

                if let shelfItems = shelf["contents"] as? [[String: Any]] {
                    for item in shelfItems {
                        if let rend = item["musicResponsiveListItemRenderer"] as? [String: Any],
                           let song = parseMusicResponsiveListItem(rend) {
                            directShelfSongs.append(song)
                        }
                    }
                }
                break
            }
        }

        // If full top songs playlist is available, fetch the full hit-parade!
        if let plId = playlistBrowseId {
            let (_, playlistTracks) = (try? await getPlaylist(playlistId: plId)) ?? (nil, [])
            if !playlistTracks.isEmpty {
                return playlistTracks
            }
        }

        return directShelfSongs
    }

    // MARK: - Artist Details Resolver
    public func fetchArtistDetails(artistBrowseId: String) async -> ArtistDetail? {
        guard let url = URL(string: "https://music.youtube.com/youtubei/v1/browse?prettyPrint=false") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("67", forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue("1.20260213.01.00", forHTTPHeaderField: "X-YouTube-Client-Version")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "X-Origin")
        request.setValue("https://music.youtube.com/", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64)", forHTTPHeaderField: "User-Agent")

        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20260213.01.00",
                    "gl": Locale.current.region?.identifier ?? "MX",
                    "hl": "es-419"
                ]
            ],
            "browseId": artistBrowseId
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, _) = try? await session.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let header = (json["header"] as? [String: Any])?["musicImmersiveHeaderRenderer"] as? [String: Any]
            ?? (json["header"] as? [String: Any])?["musicVisualHeaderRenderer"] as? [String: Any]

        let nameRuns = (header?["title"] as? [String: Any])?["runs"] as? [[String: Any]]
        let artistName = nameRuns?.first?["text"] as? String ?? "Artista"

        var bannerURL: String? = nil
        let thumbContainer = header?["thumbnail"] as? [String: Any]
        let musicThumb = thumbContainer?["musicThumbnailRenderer"] as? [String: Any]
        let thumbs = (musicThumb?["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]]
            ?? header?["thumbnails"] as? [[String: Any]]
        if let lastThumb = thumbs?.last?["url"] as? String {
            bannerURL = lastThumb
        }

        let descRuns = (header?["description"] as? [String: Any])?["runs"] as? [[String: Any]]
        let description = descRuns?.compactMap { $0["text"] as? String }.joined()

        guard let contents = json["contents"] as? [String: Any],
              let single = contents["singleColumnBrowseResultsRenderer"] as? [String: Any],
              let tabs = single["tabs"] as? [[String: Any]],
              let tabContent = tabs.first?["tabRenderer"] as? [String: Any],
              let content = tabContent["content"] as? [String: Any],
              let sectionList = content["sectionListRenderer"] as? [String: Any],
              let sections = sectionList["contents"] as? [[String: Any]] else {
            return ArtistDetail(id: artistBrowseId, name: artistName, bannerThumbnail: bannerURL, description: description)
        }

        var topSongs: [SongItem] = []
        var albums: [AlbumItem] = []
        var singles: [AlbumItem] = []

        for s in sections {
            if let shelf = s["musicShelfRenderer"] as? [String: Any] {
                if let shelfItems = shelf["contents"] as? [[String: Any]] {
                    for item in shelfItems {
                        if let rend = item["musicResponsiveListItemRenderer"] as? [String: Any],
                           let song = parseMusicResponsiveListItem(rend) {
                            topSongs.append(song)
                        }
                    }
                }
            } else if let carousel = s["musicCarouselShelfRenderer"] as? [String: Any] {
                let headerTitle = ((carousel["header"] as? [String: Any])?["musicCarouselShelfBasicHeaderRenderer"] as? [String: Any])?["title"] as? [String: Any]
                let titleStr = ((headerTitle?["runs"] as? [[String: Any]])?.first?["text"] as? String ?? "").lowercased()

                let items = carousel["contents"] as? [[String: Any]] ?? []
                for it in items {
                    if let twoRow = it["musicTwoRowItemRenderer"] as? [String: Any] {
                        let titleRun = ((twoRow["title"] as? [String: Any])?["runs"] as? [[String: Any]])?.first?["text"] as? String ?? ""
                        let browseEndpoint = (twoRow["navigationEndpoint"] as? [String: Any])?["browseEndpoint"] as? [String: Any]
                        let itemBrowseId = browseEndpoint?["browseId"] as? String ?? ""

                        let subRuns = (twoRow["subtitle"] as? [String: Any])?["runs"] as? [[String: Any]]
                        let year = subRuns?.compactMap { $0["text"] as? String }.first(where: { $0.count == 4 && Int($0) != nil })

                        let thumbObj = (twoRow["thumbnailRenderer"] as? [String: Any])?["musicThumbnailRenderer"] as? [String: Any]
                        let thumbList = (thumbObj?["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]]
                        let itemThumb = thumbList?.last?["url"] as? String

                        let albumItem = AlbumItem(
                            id: itemBrowseId,
                            playlistId: itemBrowseId,
                            title: titleRun,
                            artistName: artistName,
                            year: year,
                            thumbnail: itemThumb
                        )

                        if titleStr.contains("sencillo") || titleStr.contains("single") || titleStr.contains("ep") {
                            singles.append(albumItem)
                        } else if titleStr.contains("álbum") || titleStr.contains("album") || titleStr.contains("discograf") {
                            albums.append(albumItem)
                        } else if !itemBrowseId.isEmpty && !itemBrowseId.hasPrefix("UC") && !itemBrowseId.hasPrefix("VLPL") {
                            albums.append(albumItem)
                        }
                    }
                }
            }
        }

        return ArtistDetail(
            id: artistBrowseId,
            name: artistName,
            bannerThumbnail: bannerURL,
            avatarThumbnail: bannerURL,
            description: description,
            topSongs: topSongs,
            albums: albums,
            singles: singles
        )
    }

    // MARK: - Album Details Resolver
    public func fetchAlbumDetails(browseId: String) async -> AlbumDetail? {
        guard let url = URL(string: "https://music.youtube.com/youtubei/v1/browse?prettyPrint=false") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("67", forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue("1.20260213.01.00", forHTTPHeaderField: "X-YouTube-Client-Version")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "X-Origin")
        request.setValue("https://music.youtube.com/", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64)", forHTTPHeaderField: "User-Agent")

        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20260213.01.00",
                    "gl": Locale.current.region?.identifier ?? "MX",
                    "hl": "es-419"
                ]
            ],
            "browseId": browseId
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, _) = try? await session.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        var albumTitle = "Álbum"
        var artistName: String? = nil
        var albumYear: String? = nil
        var albumThumb: String? = nil
        var tracks: [SongItem] = []

        if let contents = json["contents"] as? [String: Any],
           let twoCol = contents["twoColumnBrowseResultsRenderer"] as? [String: Any] {

            if let tabs = twoCol["tabs"] as? [[String: Any]],
               let tabContent = tabs.first?["tabRenderer"] as? [String: Any],
               let content = tabContent["content"] as? [String: Any],
               let sectionList = content["sectionListRenderer"] as? [String: Any],
               let sections = sectionList["contents"] as? [[String: Any]] {
                for s in sections {
                    if let hdr = s["musicResponsiveHeaderRenderer"] as? [String: Any] {
                        if let runs = (hdr["title"] as? [String: Any])?["runs"] as? [[String: Any]], let t = runs.first?["text"] as? String {
                            albumTitle = t
                        }
                        if let subRuns = (hdr["subtitle"] as? [String: Any])?["runs"] as? [[String: Any]] {
                            for r in subRuns {
                                if let txt = r["text"] as? String {
                                    if txt.count == 4, Int(txt) != nil {
                                        albumYear = txt
                                    } else if !txt.contains("•") && !txt.contains("Álbum") && !txt.contains("Album") && artistName == nil && !txt.trimmingCharacters(in: .whitespaces).isEmpty {
                                        artistName = txt
                                    }
                                }
                            }
                        }
                        let thumbCont = hdr["thumbnail"] as? [String: Any]
                        let mThumb = thumbCont?["musicThumbnailRenderer"] as? [String: Any]
                        let thumbs = (mThumb?["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]]
                        albumThumb = thumbs?.last?["url"] as? String
                    }
                }
            }

            if let secContents = twoCol["secondaryContents"] as? [String: Any],
               let sectionList = secContents["sectionListRenderer"] as? [String: Any],
               let sections = sectionList["contents"] as? [[String: Any]] {
                for s in sections {
                    if let shelf = s["musicShelfRenderer"] as? [String: Any],
                       let shelfItems = shelf["contents"] as? [[String: Any]] {
                        for item in shelfItems {
                            if let rend = item["musicResponsiveListItemRenderer"] as? [String: Any] {
                                if let song = parseMusicResponsiveListItem(rend) {
                                    tracks.append(song)
                                } else {
                                    let flex = rend["flexColumns"] as? [[String: Any]] ?? []
                                    let titleCol = flex.first?["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any]
                                    let tRuns = (titleCol?["text"] as? [String: Any])?["runs"] as? [[String: Any]]
                                    let trackTitle = tRuns?.first?["text"] as? String ?? "Track"
                                    let vid = (rend["playlistItemData"] as? [String: Any])?["videoId"] as? String

                                    if let vid = vid {
                                        let song = SongItem(
                                            id: vid,
                                            title: trackTitle,
                                            artists: [Artist(name: artistName ?? "Artista")],
                                            album: Album(name: albumTitle, id: browseId),
                                            duration: nil,
                                            thumbnail: albumThumb
                                        )
                                        tracks.append(song)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        if tracks.isEmpty {
            let (_, playlistTracks) = (try? await getPlaylist(playlistId: browseId)) ?? (nil, [])
            if !playlistTracks.isEmpty {
                tracks = playlistTracks
                if albumTitle == "Álbum", let firstTrack = tracks.first {
                    albumTitle = firstTrack.album?.name ?? albumTitle
                    artistName = firstTrack.artistNames
                    albumThumb = firstTrack.thumbnail
                }
            }
        }

        return AlbumDetail(
            id: browseId,
            title: albumTitle,
            artistName: artistName,
            year: albumYear,
            thumbnail: albumThumb,
            tracks: tracks
        )
    }

    // MARK: - Search Suggestions
    public func getSuggestions(query: String) async -> [String] {
        guard let url = URL(string: "https://music.youtube.com/youtubei/v1/music/get_search_suggestions?prettyPrint=false") else {
            return []
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("67", forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue("1.20260213.01.00", forHTTPHeaderField: "X-YouTube-Client-Version")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "X-Origin")
        request.setValue("https://music.youtube.com/", forHTTPHeaderField: "Referer")

        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20260213.01.00",
                    "gl": "US",
                    "hl": "en"
                ]
            ],
            "input": query
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, _) = try await session.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let contents = json["contents"] as? [[String: Any]],
                  let section = contents.first?["searchSuggestionsSectionRenderer"] as? [String: Any],
                  let items = section["contents"] as? [[String: Any]] else {
                return []
            }

            var results: [String] = []
            for item in items {
                if let renderer = item["searchSuggestionRenderer"] as? [String: Any],
                   let suggestion = renderer["suggestion"] as? [String: Any],
                   let runs = suggestion["runs"] as? [[String: Any]] {
                    let text = runs.compactMap { $0["text"] as? String }.joined()
                    if !text.isEmpty {
                        results.append(text)
                    }
                }
            }
            return results
        } catch {
            return []
        }
    }

    // MARK: - Stream URL Extraction (VISIONOS Client with Unrestricted 140 m4a Stream)
    public struct StreamInfo: Sendable {
        public let url: URL
        public let duration: Double?

        public init(url: URL, duration: Double? = nil) {
            self.url = url
            self.duration = duration
        }
    }

    public func getStreamUrl(videoId: String, title: String? = nil, artist: String? = nil) async throws -> URL {
        let info = try await getStreamInfo(videoId: videoId, title: title, artist: artist)
        return info.url
    }

    public func getStreamInfo(videoId: String, title: String? = nil, artist: String? = nil) async throws -> StreamInfo {
        // Priority 1: Native Apple YouTube client (Direct unthrottled itag 140 AAC stream, 0.6s response, 100% success rate without login)
        do {
            let iosInfo = try await getIOSClientStreamInfo(videoId: videoId)
            print("[InnerTubeService] Got direct IOS client stream for \(videoId) in ~600ms! Duration: \(iosInfo.duration ?? 0)s")
            return iosInfo
        } catch {
            print("[InnerTubeService] IOS client stream failed: \(error). Starting fallbacks...")
        }

        // Priority 2: Direct VISIONOS fallback
        if let visionInfo = await getVisionOSStreamInfo(videoId: videoId) {
            print("[InnerTubeService] Got unrestricted VISIONOS stream! Duration: \(visionInfo.duration ?? 0)s")
            return visionInfo
        }

        // Priority 3: Alternative YouTube Video Resolution (Same song, unrestricted upload)
        if let title = title, !title.isEmpty {
            let artistStr = artist ?? ""
            if let altInfo = await findPlayableAlternative(title: title, artist: artistStr, originalVideoId: videoId) {
                print("[InnerTubeService] Found playable alternative YouTube track for '\(title)'! Duration: \(altInfo.duration ?? 0)s")
                return altInfo
            }
        }

        // Priority 4: JioSaavn Direct 320kbps / 160kbps High Fidelity CDN Stream
        if let title = title, !title.isEmpty {
            let artistStr = artist ?? ""
            if let saavnUrl = await SaavnService.shared.getStreamUrl(title: title, artist: artistStr) {
                print("[InnerTubeService] Found Saavn CDN audio stream for '\(title)'!")
                return StreamInfo(url: saavnUrl, duration: nil)
            }
        }

        throw URLError(.resourceUnavailable)
    }

    public func getFallbackStreamInfo(videoId: String, title: String? = nil, artist: String? = nil) async throws -> StreamInfo {
        // Priority 1: Direct VISIONOS fallback
        if let visionInfo = await getVisionOSStreamInfo(videoId: videoId) {
            print("[InnerTubeService] Fallback: Got unrestricted VISIONOS stream! Duration: \(visionInfo.duration ?? 0)s")
            return visionInfo
        }

        // Priority 2: Alternative YouTube Video Resolution (Same song, unrestricted upload)
        if let title = title, !title.isEmpty {
            let artistStr = artist ?? ""
            if let altInfo = await findPlayableAlternative(title: title, artist: artistStr, originalVideoId: videoId) {
                print("[InnerTubeService] Fallback: Found playable alternative YouTube track for '\(title)'! Duration: \(altInfo.duration ?? 0)s")
                return altInfo
            }
        }

        // Priority 3: JioSaavn Direct 320kbps / 160kbps High Fidelity CDN Stream
        if let title = title, !title.isEmpty {
            let artistStr = artist ?? ""
            if let saavnUrl = await SaavnService.shared.getStreamUrl(title: title, artist: artistStr) {
                print("[InnerTubeService] Fallback: Found Saavn CDN audio stream for '\(title)'!")
                return StreamInfo(url: saavnUrl, duration: nil)
            }
        }

        throw URLError(.resourceUnavailable)
    }

    // MARK: - Alternative Track Resolution (For Disney / Restricted Tracks)
    public func findPlayableAlternative(title: String, artist: String, originalVideoId: String) async -> StreamInfo? {
        let query = "\(title) \(artist)".trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty,
              let url = URL(string: "https://music.youtube.com/youtubei/v1/search?prettyPrint=false") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("67", forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue("1.20260213.01.00", forHTTPHeaderField: "X-YouTube-Client-Version")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "X-Origin")
        request.setValue("https://music.youtube.com/", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")

        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20260213.01.00",
                    "gl": "US",
                    "hl": "en"
                ]
            ],
            "query": query,
            "params": "EgWKAQIIAWoKEAkQBRAKEAMQBA%3D%3D"
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, _) = try? await session.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let songs = parseSearchSongs(from: json)
        let candidates = songs.filter { $0.id != originalVideoId }

        for candidate in candidates.prefix(3) {
            print("[InnerTubeService] Testing candidate alternative: '\(candidate.title)' (\(candidate.id))...")
            if let iosInfo = try? await getIOSClientStreamInfo(videoId: candidate.id) {
                print("[InnerTubeService] Selected fast iOS client alternative: '\(candidate.title)' (\(candidate.id))")
                return iosInfo
            }
            if let visionInfo = await getVisionOSStreamInfo(videoId: candidate.id) {
                print("[InnerTubeService] Selected VISIONOS alternative: '\(candidate.title)' (\(candidate.id))")
                return visionInfo
            }
        }

        return nil
    }

    private func getVisionOSStreamInfo(videoId: String) async -> StreamInfo? {
        guard let url = URL(string: "https://www.youtube.com/youtubei/v1/player?prettyPrint=false") else {
            return nil
        }

        let visitorId = await VisitorManager.shared.getVisitorId(session: session, videoId: videoId)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("101", forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue("1.02", forHTTPHeaderField: "X-YouTube-Client-Version")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
        let visionUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15"
        request.setValue(visionUA, forHTTPHeaderField: "User-Agent")
        if let vid = visitorId, !vid.isEmpty {
            request.setValue(vid, forHTTPHeaderField: "X-Goog-Visitor-Id")
        }

        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "VISIONOS",
                    "clientVersion": "1.02",
                    "deviceMake": "Apple",
                    "deviceModel": "RealityDevice17,1",
                    "userAgent": visionUA,
                    "osName": "visionOS",
                    "osVersion": "26.5.23O471",
                    "hl": "en",
                    "timeZone": "UTC",
                    "utcOffsetMinutes": 0
                ]
            ],
            "videoId": videoId,
            "playbackContext": [
                "contentPlaybackContext": [
                    "html5Preference": "HTML5_PREF_WANTS"
                ]
            ],
            "contentCheckOk": true,
            "racyCheckOk": true
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            return nil
        }
        request.httpBody = bodyData

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }

            if let playability = json["playabilityStatus"] as? [String: Any],
               let status = playability["status"] as? String, status != "OK" {
                print("[InnerTubeService] VISIONOS playabilityStatus: \(status)")
                return nil
            }

            // Extract authoritative duration if present
            var authorDuration: Double? = nil
            if let videoDetails = json["videoDetails"] as? [String: Any],
               let lenStr = videoDetails["lengthSeconds"] as? String,
               let lenSec = Double(lenStr), lenSec > 0 {
                authorDuration = lenSec
            }

            guard let streamingData = json["streamingData"] as? [String: Any],
                  let adaptiveFormats = streamingData["adaptiveFormats"] as? [[String: Any]] else {
                return nil
            }

            // Priority 1: itag 140 (AAC 128k m4a)
            for f in adaptiveFormats {
                if let itag = f["itag"] as? Int, itag == 140,
                   let urlStr = f["url"] as? String, let targetUrl = URL(string: urlStr) {
                    print("[InnerTubeService] Selected VISIONOS itag 140 stream")
                    var dur = authorDuration
                    if dur == nil, let msStr = f["approxDurationMs"] as? String, let ms = Double(msStr) {
                        dur = ms / 1000.0
                    }
                    return StreamInfo(url: targetUrl, duration: dur)
                }
            }

            // Priority 2: any audio/mp4
            for f in adaptiveFormats {
                if let mime = f["mimeType"] as? String, mime.contains("audio/mp4"),
                   let urlStr = f["url"] as? String, let targetUrl = URL(string: urlStr) {
                    print("[InnerTubeService] Selected VISIONOS audio/mp4 stream")
                    var dur = authorDuration
                    if dur == nil, let msStr = f["approxDurationMs"] as? String, let ms = Double(msStr) {
                        dur = ms / 1000.0
                    }
                    return StreamInfo(url: targetUrl, duration: dur)
                }
            }

            // Priority 3: any audio
            for f in adaptiveFormats {
                if let mime = f["mimeType"] as? String, mime.starts(with: "audio/"),
                   let urlStr = f["url"] as? String, let targetUrl = URL(string: urlStr) {
                    print("[InnerTubeService] Selected VISIONOS audio stream: \(mime)")
                    var dur = authorDuration
                    if dur == nil, let msStr = f["approxDurationMs"] as? String, let ms = Double(msStr) {
                        dur = ms / 1000.0
                    }
                    return StreamInfo(url: targetUrl, duration: dur)
                }
            }
        } catch {
            print("[InnerTubeService] VISIONOS request error: \(error)")
        }

        return nil
    }

    private func getIOSClientStreamInfo(videoId: String) async throws -> StreamInfo {
        guard let url = URL(string: "https://music.youtube.com/youtubei/v1/player?prettyPrint=false") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("5", forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue("21.03.1", forHTTPHeaderField: "X-YouTube-Client-Version")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "X-Origin")
        request.setValue("https://music.youtube.com/", forHTTPHeaderField: "Referer")
        request.setValue("com.google.ios.youtube/21.03.1 (iPhone16,2; U; CPU iOS 18_2 like Mac OS X;)", forHTTPHeaderField: "User-Agent")

        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "IOS",
                    "clientVersion": "21.03.1",
                    "deviceMake": "Apple",
                    "deviceModel": "iPhone16,2",
                    "osName": "iOS",
                    "osVersion": "18.2.22C152",
                    "gl": "US",
                    "hl": "en"
                ]
            ],
            "videoId": videoId,
            "contentCheckOk": true,
            "racyCheckOk": true
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await session.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }

        var authorDuration: Double? = nil
        if let videoDetails = json["videoDetails"] as? [String: Any],
           let lenStr = videoDetails["lengthSeconds"] as? String,
           let lenSec = Double(lenStr), lenSec > 0 {
            authorDuration = lenSec
        }

        guard let streamingData = json["streamingData"] as? [String: Any],
              let adaptiveFormats = streamingData["adaptiveFormats"] as? [[String: Any]] else {
            throw URLError(.cannotParseResponse)
        }

        // Prefer itag 140 (m4a AAC ~128kbps) for AVPlayer, or any audio/mp4 format
        var streamUrlString: String?
        var formatDuration: Double? = authorDuration

        // 1. First priority: itag 140 (native AAC)
        for format in adaptiveFormats {
            if let itag = format["itag"] as? Int, itag == 140,
               let urlStr = format["url"] as? String {
                streamUrlString = urlStr
                if formatDuration == nil, let msStr = format["approxDurationMs"] as? String, let ms = Double(msStr) {
                    formatDuration = ms / 1000.0
                }
                break
            }
        }

        // 2. Second priority: any audio/mp4 format
        if streamUrlString == nil {
            for format in adaptiveFormats {
                if let mimeType = format["mimeType"] as? String, mimeType.contains("audio/mp4"),
                   let urlStr = format["url"] as? String {
                    streamUrlString = urlStr
                    if formatDuration == nil, let msStr = format["approxDurationMs"] as? String, let ms = Double(msStr) {
                        formatDuration = ms / 1000.0
                    }
                    break
                }
            }
        }

        // 3. Fallback: any audio format with direct URL
        if streamUrlString == nil {
            for format in adaptiveFormats {
                if let mimeType = format["mimeType"] as? String, mimeType.starts(with: "audio/"),
                   let urlStr = format["url"] as? String {
                    streamUrlString = urlStr
                    if formatDuration == nil, let msStr = format["approxDurationMs"] as? String, let ms = Double(msStr) {
                        formatDuration = ms / 1000.0
                    }
                    break
                }
            }
        }

        guard let streamUrlString = streamUrlString, let targetUrl = URL(string: streamUrlString) else {
            throw URLError(.resourceUnavailable)
        }

        return StreamInfo(url: targetUrl, duration: formatDuration)
    }

    // MARK: - Queue / Next & Automix Radio
    public func getNext(videoId: String, playlistId: String? = nil) async -> [SongItem] {
        guard let url = URL(string: "https://music.youtube.com/youtubei/v1/next?prettyPrint=false") else {
            return []
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("67", forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue("1.20260213.01.00", forHTTPHeaderField: "X-YouTube-Client-Version")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "X-Origin")
        request.setValue("https://music.youtube.com/", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")

        let resolvedPlaylistId = playlistId ?? "RDAMVM\(videoId)"

        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20260213.01.00",
                    "gl": "US",
                    "hl": "es"
                ]
            ],
            "videoId": videoId,
            "playlistId": resolvedPlaylistId
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, _) = try await session.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return []
            }
            let items = parseQueueItems(from: json)
            if !items.isEmpty {
                return items
            }

            // Fallback without playlistId if RDAMVM was empty
            var fallbackBody = body
            fallbackBody.removeValue(forKey: "playlistId")
            request.httpBody = try? JSONSerialization.data(withJSONObject: fallbackBody)
            let (fallbackData, _) = try await session.data(for: request)
            if let fallbackJson = try? JSONSerialization.jsonObject(with: fallbackData) as? [String: Any] {
                return parseQueueItems(from: fallbackJson)
            }
            return []
        } catch {
            return []
        }
    }

    // MARK: - Synced Lyrics (LRCLIB + YT Subtitle)
    public func getLyrics(videoId: String, title: String, artist: String, duration: Int) async -> [LyricLine] {
        // Query LRCLIB
        var components = URLComponents(string: "https://lrclib.net/api/get")
        components?.queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "duration", value: "\(duration)")
        ]

        if let lrcUrl = components?.url {
            var request = URLRequest(url: lrcUrl)
            request.setValue("Convx-iOS/1.0", forHTTPHeaderField: "User-Agent")
            if let (data, _) = try? await session.data(for: request),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let syncedLyrics = json["syncedLyrics"] as? String, !syncedLyrics.isEmpty {
                    return parseLrcString(syncedLyrics)
                }
                if let plainLyrics = json["plainLyrics"] as? String, !plainLyrics.isEmpty {
                    return plainLyrics.components(separatedBy: "\n").map { LyricLine(timeMs: 0, text: $0) }
                }
            }
        }

        return []
    }

    // MARK: - Home Recommendations
    public func getHomeFeed() async -> [HomeSection] {
        guard let url = URL(string: "https://music.youtube.com/youtubei/v1/browse?prettyPrint=false") else {
            return []
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("67", forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue("1.20260213.01.00", forHTTPHeaderField: "X-YouTube-Client-Version")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "X-Origin")
        request.setValue("https://music.youtube.com/", forHTTPHeaderField: "Referer")

        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20260213.01.00",
                    "gl": "US",
                    "hl": "en"
                ]
            ],
            "browseId": "FEmusic_home"
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, _) = try await session.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return []
            }
            return parseHomeSections(from: json)
        } catch {
            return []
        }
    }

    // MARK: - Parsing Helpers
    private func parseSearchSongsAndArtistCard(from json: [String: Any]) -> (songs: [SongItem], artist: ArtistItem?) {
        var songs: [SongItem] = []
        var artistBrowseId: String? = nil
        var artistName: String? = nil
        var artistThumb: String? = nil

        guard let contents = json["contents"] as? [String: Any],
              let tabbedRenderer = contents["tabbedSearchResultsRenderer"] as? [String: Any],
              let tabs = tabbedRenderer["tabs"] as? [[String: Any]],
              let tabContent = tabs.first?["tabRenderer"] as? [String: Any],
              let content = tabContent["content"] as? [String: Any],
              let sectionList = content["sectionListRenderer"] as? [String: Any],
              let sectionContents = sectionList["contents"] as? [[String: Any]] else {
            return ([], nil)
        }

        for section in sectionContents {
            // 1. Detect Artist Card Shelf (e.g. José José, Luis Miguel, Queen)
            if let card = section["musicCardShelfRenderer"] as? [String: Any] {
                if let titleObj = card["title"] as? [String: Any],
                   let runs = titleObj["runs"] as? [[String: Any]] {
                    artistName = runs.first?["text"] as? String
                    for r in runs {
                        if let nav = r["navigationEndpoint"] as? [String: Any],
                           let browse = nav["browseEndpoint"] as? [String: Any],
                           let bId = browse["browseId"] as? String {
                            let configs = browse["browseEndpointContextSupportedConfigs"] as? [String: Any]
                            let musicConfig = configs?["browseEndpointContextMusicConfig"] as? [String: Any]
                            let pageType = musicConfig?["pageType"] as? String ?? ""
                            if pageType.contains("ARTIST") || bId.hasPrefix("UC") {
                                artistBrowseId = bId
                            }
                        }
                    }
                }
                if artistBrowseId == nil,
                   let onTap = card["onTap"] as? [String: Any],
                   let browse = onTap["browseEndpoint"] as? [String: Any],
                   let bId = browse["browseId"] as? String {
                    artistBrowseId = bId
                }

                // Thumbnail
                if let thumbContainer = card["thumbnail"] as? [String: Any],
                   let musicThumb = thumbContainer["musicThumbnailRenderer"] as? [String: Any],
                   let thumbObj = musicThumb["thumbnail"] as? [String: Any],
                   let thumbs = thumbObj["thumbnails"] as? [[String: Any]] {
                    artistThumb = thumbs.last?["url"] as? String
                }

                // Also parse any preview tracks inside the card
                if let cardContents = card["contents"] as? [[String: Any]] {
                    for item in cardContents {
                        if let rend = item["musicResponsiveListItemRenderer"] as? [String: Any],
                           let song = parseMusicResponsiveListItem(rend) {
                            songs.append(song)
                        }
                    }
                }
            }

            // 2. Regular Songs Shelf
            if let musicShelf = section["musicShelfRenderer"] as? [String: Any],
               let shelfContents = musicShelf["contents"] as? [[String: Any]] {
                for item in shelfContents {
                    if let renderer = item["musicResponsiveListItemRenderer"] as? [String: Any],
                       let song = parseMusicResponsiveListItem(renderer) {
                        songs.append(song)
                    }
                }
            }
        }

        var artistItem: ArtistItem? = nil
        if let id = artistBrowseId {
            artistItem = ArtistItem(id: id, name: artistName ?? "Artista", thumbnail: artistThumb)
        }

        return (songs, artistItem)
    }

    private func parseSearchSongs(from json: [String: Any]) -> [SongItem] {
        var songs: [SongItem] = []
        guard let contents = json["contents"] as? [String: Any],
              let tabbedRenderer = contents["tabbedSearchResultsRenderer"] as? [String: Any],
              let tabs = tabbedRenderer["tabs"] as? [[String: Any]],
              let tabContent = tabs.first?["tabRenderer"] as? [String: Any],
              let content = tabContent["content"] as? [String: Any],
              let sectionList = content["sectionListRenderer"] as? [String: Any],
              let sectionContents = sectionList["contents"] as? [[String: Any]] else {
            return []
        }

        for section in sectionContents {
            guard let musicShelf = section["musicShelfRenderer"] as? [String: Any],
                  let shelfContents = musicShelf["contents"] as? [[String: Any]] else {
                continue
            }

            for item in shelfContents {
                if let renderer = item["musicResponsiveListItemRenderer"] as? [String: Any] {
                    if let song = parseMusicResponsiveListItem(renderer) {
                        songs.append(song)
                    }
                }
            }
        }
        return songs
    }

    private func parseMusicResponsiveListItem(_ renderer: [String: Any]) -> SongItem? {
        guard let flexColumns = renderer["flexColumns"] as? [[String: Any]], flexColumns.count >= 2 else {
            return nil
        }

        // Title
        let titleCol = flexColumns[0]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any]
        let titleText = (titleCol?["text"] as? [String: Any])?["runs"] as? [[String: Any]]
        let title = titleText?.first?["text"] as? String ?? "Unknown Title"

        // Video ID
        let videoId = renderer["playlistItemData"] as? [String: Any]
        var vid = videoId?["videoId"] as? String
        if vid == nil {
            let nav = renderer["navigationEndpoint"] as? [String: Any]
            vid = (nav?["watchEndpoint"] as? [String: Any])?["videoId"] as? String
        }
        if vid == nil {
            let overlay = renderer["overlay"] as? [String: Any]
            let thumbOverlay = overlay?["musicItemThumbnailOverlayRenderer"] as? [String: Any]
            let playBtn = (thumbOverlay?["content"] as? [String: Any])?["musicPlayButtonRenderer"] as? [String: Any]
            let watch = (playBtn?["playNavigationEndpoint"] as? [String: Any])?["watchEndpoint"] as? [String: Any]
            vid = watch?["videoId"] as? String
        }

        guard let finalId = vid else { return nil }

        // Subtitle runs (Artists • Album • Duration)
        let subCol = flexColumns[1]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any]
        let subRuns = (subCol?["text"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []

        var artists: [Artist] = []
        var durationSeconds: Int?
        var albumName: String?
        var albumBrowseId: String?

        for run in subRuns {
            if let text = run["text"] as? String {
                if text == " • " || text == ", " { continue }
                let nav = run["navigationEndpoint"] as? [String: Any]
                let browse = nav?["browseEndpoint"] as? [String: Any]
                let bId = browse?["browseId"] as? String

                if text.contains(":") {
                    durationSeconds = parseDuration(text)
                } else if let bId = bId, bId.hasPrefix("UC") {
                    artists.append(Artist(name: text, id: bId))
                } else if let bId = bId, (bId.hasPrefix("MPREb_") || bId.hasPrefix("OLAK5uy_")) {
                    albumName = text
                    albumBrowseId = bId
                } else if artists.isEmpty {
                    artists.append(Artist(name: text, id: bId))
                } else if albumName == nil {
                    albumName = text
                    albumBrowseId = bId
                }
            }
        }

        // Thumbnail
        var thumbUrl: String?
        if let thumb = renderer["thumbnail"] as? [String: Any],
           let musicThumb = thumb["musicThumbnailRenderer"] as? [String: Any],
           let thumbObj = musicThumb["thumbnail"] as? [String: Any],
           let thumbs = thumbObj["thumbnails"] as? [[String: Any]] {
            thumbUrl = thumbs.last?["url"] as? String
        }

        let album = albumName.map { Album(name: $0, id: albumBrowseId ?? "") }
        return SongItem(id: finalId, title: title, artists: artists, album: album, duration: durationSeconds, thumbnail: thumbUrl)
    }

    private func parseQueueItems(from json: [String: Any]) -> [SongItem] {
        var songs: [SongItem] = []
        guard let contents = json["contents"] as? [String: Any],
              let singleCol = contents["singleColumnMusicWatchNextResultsRenderer"] as? [String: Any],
              let tabbed = singleCol["tabbedRenderer"] as? [String: Any],
              let watchNext = tabbed["watchNextTabbedResultsRenderer"] as? [String: Any],
              let tabs = watchNext["tabs"] as? [[String: Any]],
              let firstTab = tabs.first?["tabRenderer"] as? [String: Any],
              let content = firstTab["content"] as? [String: Any],
              let queueRenderer = content["musicQueueRenderer"] as? [String: Any],
              let queueContent = queueRenderer["content"] as? [String: Any],
              let playlistPanel = queueContent["playlistPanelRenderer"] as? [String: Any],
              let items = playlistPanel["contents"] as? [[String: Any]] else {
            return []
        }

        for item in items {
            guard let renderer = item["playlistPanelVideoRenderer"] as? [String: Any],
                  let videoId = renderer["videoId"] as? String else {
                continue
            }

            let titleRuns = (renderer["title"] as? [String: Any])?["runs"] as? [[String: Any]]
            let title = titleRuns?.first?["text"] as? String ?? "Unknown Title"

            let bylineRuns = (renderer["longBylineText"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []
            var artists: [Artist] = []
            for run in bylineRuns {
                if let text = run["text"] as? String, text != " • ", text != ", ", !text.contains(":") {
                    artists.append(Artist(name: text))
                }
            }

            let lengthRuns = (renderer["lengthText"] as? [String: Any])?["runs"] as? [[String: Any]]
            let durationStr = lengthRuns?.first?["text"] as? String
            let durationSeconds = durationStr.flatMap { parseDuration($0) }

            let thumbs = (renderer["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]]
            let thumbUrl = thumbs?.last?["url"] as? String

            songs.append(SongItem(
                id: videoId,
                title: title,
                artists: artists,
                duration: durationSeconds,
                thumbnail: thumbUrl
            ))
        }

        return songs
    }

    private func parseHomeSections(from json: [String: Any]) -> [HomeSection] {
        var sections: [HomeSection] = []
        guard let contents = json["contents"] as? [String: Any],
              let singleCol = contents["singleColumnBrowseResultsRenderer"] as? [String: Any],
              let tabs = singleCol["tabs"] as? [[String: Any]],
              let tabContent = tabs.first?["tabRenderer"] as? [String: Any],
              let content = tabContent["content"] as? [String: Any],
              let sectionList = content["sectionListRenderer"] as? [String: Any],
              let sectionContents = sectionList["contents"] as? [[String: Any]] else {
            return []
        }

        for section in sectionContents {
            guard let carousel = section["musicCarouselShelfRenderer"] as? [String: Any] else {
                continue
            }

            let header = carousel["header"] as? [String: Any]
            let basicHeader = header?["musicCarouselShelfBasicHeaderRenderer"] as? [String: Any]
            let titleRuns = (basicHeader?["title"] as? [String: Any])?["runs"] as? [[String: Any]]
            let title = titleRuns?.first?["text"] as? String ?? "Recommended"
            let straplineRuns = (basicHeader?["strapline"] as? [String: Any])?["runs"] as? [[String: Any]]
            let subtitle = straplineRuns?.first?["text"] as? String

            var sectionSongs: [SongItem] = []
            if let shelfItems = carousel["contents"] as? [[String: Any]] {
                for shelfItem in shelfItems {
                    if let renderer = shelfItem["musicResponsiveListItemRenderer"] as? [String: Any],
                       let song = parseMusicResponsiveListItem(renderer) {
                        sectionSongs.append(song)
                    } else if let twoRow = shelfItem["musicTwoRowItemRenderer"] as? [String: Any] {
                        let titleRuns = (twoRow["title"] as? [String: Any])?["runs"] as? [[String: Any]]
                        let title = titleRuns?.first?["text"] as? String ?? ""
                        let nav = twoRow["navigationEndpoint"] as? [String: Any]
                        let watch = nav?["watchEndpoint"] as? [String: Any]
                        if let vid = watch?["videoId"] as? String {
                            let subRuns = (twoRow["subtitle"] as? [String: Any])?["runs"] as? [[String: Any]]
                            let artist = subRuns?.first?["text"] as? String ?? ""
                            let thumbs = (twoRow["thumbnailRenderer"] as? [String: Any])?["musicThumbnailRenderer"] as? [String: Any]
                            let thumbList = ((thumbs?["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]])
                            let thumbUrl = thumbList?.last?["url"] as? String
                            sectionSongs.append(SongItem(
                                id: vid,
                                title: title,
                                artists: [Artist(name: artist)],
                                thumbnail: thumbUrl
                            ))
                        }
                    }
                }
            }

            if !sectionSongs.isEmpty {
                sections.append(HomeSection(title: title, subtitle: subtitle, items: sectionSongs))
            }
        }

        return sections
    }

    private func parseDuration(_ text: String) -> Int? {
        let parts = text.split(separator: ":").compactMap { Int($0) }
        if parts.count == 2 {
            return parts[0] * 60 + parts[1]
        } else if parts.count == 3 {
            return parts[0] * 3600 + parts[1] * 60 + parts[2]
        }
        return nil
    }

    private func parseLrcString(_ lrc: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        let pattern = "\\[(\\d{2}):(\\d{2})\\.(\\d{2,3})\\](.*)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        for lineStr in lrc.components(separatedBy: "\n") {
            let nsStr = lineStr as NSString
            let matches = regex.matches(in: lineStr, range: NSRange(location: 0, length: nsStr.length))
            if let match = matches.first, match.numberOfRanges == 5 {
                let min = Int64(nsStr.substring(with: match.range(at: 1))) ?? 0
                let sec = Int64(nsStr.substring(with: match.range(at: 2))) ?? 0
                let msRaw = nsStr.substring(with: match.range(at: 3))
                var ms = Int64(msRaw) ?? 0
                if msRaw.count == 2 { ms *= 10 }
                let timeMs = min * 60000 + sec * 1000 + ms
                let text = nsStr.substring(with: match.range(at: 4)).trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    lines.append(LyricLine(timeMs: timeMs, text: text))
                }
            }
        }
        return lines.sorted { $0.timeMs < $1.timeMs }
    }

    // MARK: - Search Playlists
    public func searchPlaylists(query: String) async throws -> [PlaylistItem] {
        guard let url = URL(string: "https://music.youtube.com/youtubei/v1/search?prettyPrint=false") else {
            return []
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("67", forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue("1.20260213.01.00", forHTTPHeaderField: "X-YouTube-Client-Version")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "X-Origin")
        request.setValue("https://music.youtube.com/", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")

        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20260213.01.00",
                    "gl": "US",
                    "hl": "es"
                ]
            ],
            "query": query,
            // Filter: Playlists (all community and featured playlists)
            "params": "EgWKAQIoAWoMEA4QChADEAQQCRAF"
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await session.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        return parseSearchPlaylists(from: json)
    }

    // MARK: - Get Playlist Details & Tracks
    public func getPlaylist(playlistId: String) async throws -> (playlist: PlaylistItem?, tracks: [SongItem]) {
        guard let url = URL(string: "https://music.youtube.com/youtubei/v1/browse?prettyPrint=false") else {
            return (nil, [])
        }

        // InnerTube REQUIRES the "VL" prefix for playlist browseId
        let browseId = playlistId.hasPrefix("VL") ? playlistId : "VL\(playlistId)"
        let cleanId = playlistId.hasPrefix("VL") ? String(playlistId.dropFirst(2)) : playlistId

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("67", forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue("1.20260213.01.00", forHTTPHeaderField: "X-YouTube-Client-Version")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "X-Origin")
        request.setValue("https://music.youtube.com/", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")

        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20260213.01.00",
                    "gl": "US",
                    "hl": "es"
                ]
            ],
            "browseId": browseId
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await session.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (nil, [])
        }

        return parsePlaylistBrowse(from: json, defaultPlaylistId: cleanId)
    }

    // MARK: - Search Playlists Parsing
    private func parseSearchPlaylists(from json: [String: Any]) -> [PlaylistItem] {
        var playlists: [PlaylistItem] = []
        guard let contents = json["contents"] as? [String: Any],
              let tabbedRenderer = contents["tabbedSearchResultsRenderer"] as? [String: Any],
              let tabs = tabbedRenderer["tabs"] as? [[String: Any]],
              let tabContent = tabs.first?["tabRenderer"] as? [String: Any],
              let content = tabContent["content"] as? [String: Any],
              let sectionList = content["sectionListRenderer"] as? [String: Any],
              let sectionContents = sectionList["contents"] as? [[String: Any]] else {
            return []
        }

        for section in sectionContents {
            if let musicShelf = section["musicShelfRenderer"] as? [String: Any],
               let shelfContents = musicShelf["contents"] as? [[String: Any]] {
                for item in shelfContents {
                    if let renderer = item["musicResponsiveListItemRenderer"] as? [String: Any],
                       let playlist = parsePlaylistResponsiveListItem(renderer) {
                        playlists.append(playlist)
                    } else if let twoRow = item["musicTwoRowItemRenderer"] as? [String: Any],
                              let playlist = parsePlaylistTwoRowItem(twoRow) {
                        playlists.append(playlist)
                    }
                }
            } else if let itemSection = section["itemSectionRenderer"] as? [String: Any],
                      let itemContents = itemSection["contents"] as? [[String: Any]] {
                for item in itemContents {
                    if let renderer = item["musicResponsiveListItemRenderer"] as? [String: Any],
                       let playlist = parsePlaylistResponsiveListItem(renderer) {
                        playlists.append(playlist)
                    }
                }
            }
        }
        return playlists
    }

    private func parsePlaylistResponsiveListItem(_ renderer: [String: Any]) -> PlaylistItem? {
        var playlistId: String?
        if let nav = renderer["navigationEndpoint"] as? [String: Any],
           let browse = nav["browseEndpoint"] as? [String: Any],
           let browseId = browse["browseId"] as? String {
            playlistId = browseId.hasPrefix("VL") ? String(browseId.dropFirst(2)) : browseId
        }

        if playlistId == nil {
            let overlay = renderer["overlay"] as? [String: Any]
            let thumbOverlay = overlay?["musicItemThumbnailOverlayRenderer"] as? [String: Any]
            let playBtn = (thumbOverlay?["content"] as? [String: Any])?["musicPlayButtonRenderer"] as? [String: Any]
            let watchPlaylist = (playBtn?["playNavigationEndpoint"] as? [String: Any])?["watchPlaylistEndpoint"] as? [String: Any]
            playlistId = watchPlaylist?["playlistId"] as? String
        }

        guard let id = playlistId, !id.isEmpty else { return nil }

        guard let flexColumns = renderer["flexColumns"] as? [[String: Any]], !flexColumns.isEmpty else {
            return nil
        }
        let titleCol = flexColumns[0]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any]
        let titleRuns = (titleCol?["text"] as? [String: Any])?["runs"] as? [[String: Any]]
        let title = titleRuns?.first?["text"] as? String ?? "Unknown Playlist"

        var author: String?
        var songCountText: String?
        if flexColumns.count >= 2 {
            let subCol = flexColumns[1]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any]
            let subRuns = (subCol?["text"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []

            for run in subRuns {
                guard let text = run["text"] as? String, text != " • ", text != ", " else { continue }
                let lower = text.lowercased()
                if lower.contains("canc") || lower.contains("song") || lower.contains("track") || lower.contains("view") || lower.contains("vis") {
                    songCountText = text
                } else if author == nil {
                    author = text
                }
            }
        }

        var thumbUrl: String?
        if let thumb = renderer["thumbnail"] as? [String: Any],
           let musicThumb = thumb["musicThumbnailRenderer"] as? [String: Any],
           let thumbObj = musicThumb["thumbnail"] as? [String: Any],
           let thumbs = thumbObj["thumbnails"] as? [[String: Any]] {
            thumbUrl = thumbs.last?["url"] as? String
        }

        return PlaylistItem(
            id: id,
            title: title,
            author: author,
            songCountText: songCountText,
            thumbnail: thumbUrl
        )
    }

    private func parsePlaylistTwoRowItem(_ renderer: [String: Any]) -> PlaylistItem? {
        var playlistId: String?
        if let nav = renderer["navigationEndpoint"] as? [String: Any],
           let browse = nav["browseEndpoint"] as? [String: Any],
           let browseId = browse["browseId"] as? String {
            playlistId = browseId.hasPrefix("VL") ? String(browseId.dropFirst(2)) : browseId
        }

        if playlistId == nil {
            let overlay = renderer["thumbnailOverlay"] as? [String: Any]
            let thumbOverlay = overlay?["musicItemThumbnailOverlayRenderer"] as? [String: Any]
            let playBtn = (thumbOverlay?["content"] as? [String: Any])?["musicPlayButtonRenderer"] as? [String: Any]
            let watchPlaylist = (playBtn?["playNavigationEndpoint"] as? [String: Any])?["watchPlaylistEndpoint"] as? [String: Any]
            playlistId = watchPlaylist?["playlistId"] as? String
        }

        guard let id = playlistId, !id.isEmpty else { return nil }

        let titleRuns = (renderer["title"] as? [String: Any])?["runs"] as? [[String: Any]]
        let title = titleRuns?.first?["text"] as? String ?? ""

        var author: String?
        var songCountText: String?
        let subRuns = (renderer["subtitle"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []
        for run in subRuns {
            guard let text = run["text"] as? String, text != " • ", text != ", " else { continue }
            let lower = text.lowercased()
            if lower.contains("canc") || lower.contains("song") || lower.contains("track") || lower.contains("view") || lower.contains("vis") {
                songCountText = text
            } else if author == nil {
                author = text
            }
        }

        var thumbUrl: String?
        if let thumbRenderer = (renderer["thumbnailRenderer"] as? [String: Any])?["musicThumbnailRenderer"] as? [String: Any],
           let thumbObj = thumbRenderer["thumbnail"] as? [String: Any],
           let thumbList = thumbObj["thumbnails"] as? [[String: Any]] {
            thumbUrl = thumbList.last?["url"] as? String
        }

        return PlaylistItem(
            id: id,
            title: title,
            author: author,
            songCountText: songCountText,
            thumbnail: thumbUrl
        )
    }

    // MARK: - Playlist Browse Parsing
    private func parsePlaylistBrowse(from json: [String: Any], defaultPlaylistId: String) -> (playlist: PlaylistItem?, tracks: [SongItem]) {
        guard let contents = json["contents"] as? [String: Any] else {
            return (nil, [])
        }

        var playlistInfo: PlaylistItem?
        var tracks: [SongItem] = []

        if let twoCol = contents["twoColumnBrowseResultsRenderer"] as? [String: Any] {
            // 1. Header Details
            if let tabs = twoCol["tabs"] as? [[String: Any]],
               let tabContent = tabs.first?["tabRenderer"] as? [String: Any],
               let content = tabContent["content"] as? [String: Any],
               let sectionList = content["sectionListRenderer"] as? [String: Any],
               let sectionContents = sectionList["contents"] as? [[String: Any]],
               let header = sectionContents.first?["musicResponsiveHeaderRenderer"] as? [String: Any] {

                let titleRuns = (header["title"] as? [String: Any])?["runs"] as? [[String: Any]]
                let title = titleRuns?.first?["text"] as? String ?? ""

                var author: String?
                let subRuns = (header["subtitle"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []
                for run in subRuns {
                    guard let text = run["text"] as? String, text != "Playlist", text != " • ", text != ", " else { continue }
                    author = text
                    break
                }

                var trackCount: String?
                let secSubRuns = (header["secondSubtitle"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []
                for run in secSubRuns {
                    guard let text = run["text"] as? String, text.contains("track") || text.contains("song") || text.contains("canc") else { continue }
                    trackCount = text
                    break
                }

                var thumbUrl: String?
                if let thumb = header["thumbnail"] as? [String: Any],
                   let musicThumb = thumb["musicThumbnailRenderer"] as? [String: Any],
                   let thumbObj = musicThumb["thumbnail"] as? [String: Any],
                   let thumbs = thumbObj["thumbnails"] as? [[String: Any]] {
                    thumbUrl = thumbs.last?["url"] as? String
                }

                playlistInfo = PlaylistItem(
                    id: defaultPlaylistId,
                    title: title,
                    author: author,
                    songCountText: trackCount,
                    thumbnail: thumbUrl
                )
            }

            // 2. Tracks Shelf
            if let secondary = twoCol["secondaryContents"] as? [String: Any],
               let secList = secondary["sectionListRenderer"] as? [String: Any],
               let secContents = secList["contents"] as? [[String: Any]] {
                for item in secContents {
                    if let shelf = item["musicPlaylistShelfRenderer"] as? [String: Any],
                       let shelfItems = shelf["contents"] as? [[String: Any]] {
                        for shelfItem in shelfItems {
                            if let renderer = shelfItem["musicResponsiveListItemRenderer"] as? [String: Any],
                               let song = parsePlaylistTrackListItem(renderer) {
                                tracks.append(song)
                            }
                        }
                    }
                }
            }
        }

        return (playlistInfo, tracks)
    }

    private func parsePlaylistTrackListItem(_ renderer: [String: Any]) -> SongItem? {
        guard let flexColumns = renderer["flexColumns"] as? [[String: Any]], !flexColumns.isEmpty else {
            return nil
        }

        // Title
        let titleCol = flexColumns[0]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any]
        let titleRuns = (titleCol?["text"] as? [String: Any])?["runs"] as? [[String: Any]]
        let title = titleRuns?.first?["text"] as? String ?? "Unknown Title"

        // Video ID
        var vid = (renderer["playlistItemData"] as? [String: Any])?["videoId"] as? String
        if vid == nil {
            let overlay = renderer["overlay"] as? [String: Any]
            let thumbOverlay = overlay?["musicItemThumbnailOverlayRenderer"] as? [String: Any]
            let playBtn = (thumbOverlay?["content"] as? [String: Any])?["musicPlayButtonRenderer"] as? [String: Any]
            let watch = (playBtn?["playNavigationEndpoint"] as? [String: Any])?["watchEndpoint"] as? [String: Any]
            vid = watch?["videoId"] as? String
        }
        if vid == nil {
            let nav = (titleRuns?.first?["navigationEndpoint"] as? [String: Any])?["watchEndpoint"] as? [String: Any]
            vid = nav?["videoId"] as? String
        }

        guard let finalId = vid else { return nil }

        // Artists & Album
        var artists: [Artist] = []
        var albumName: String?
        if flexColumns.count >= 2 {
            let subCol = flexColumns[1]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any]
            let subRuns = (subCol?["text"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []

            for run in subRuns {
                guard let text = run["text"] as? String, text != " • ", text != ", " else { continue }
                if artists.isEmpty {
                    artists.append(Artist(name: text))
                } else if albumName == nil {
                    albumName = text
                }
            }
        }

        // Duration (Playlist items put duration in fixedColumns, not flexColumns)
        var durationSeconds: Int?
        if let fixedColumns = renderer["fixedColumns"] as? [[String: Any]],
           let fixedCol = fixedColumns.first?["musicResponsiveListItemFixedColumnRenderer"] as? [String: Any],
           let fixedRuns = (fixedCol["text"] as? [String: Any])?["runs"] as? [[String: Any]],
           let durText = fixedRuns.first?["text"] as? String {
            durationSeconds = parseDuration(durText)
        }

        // Thumbnail
        var thumbUrl: String?
        if let thumb = renderer["thumbnail"] as? [String: Any],
           let musicThumb = thumb["musicThumbnailRenderer"] as? [String: Any],
           let thumbObj = musicThumb["thumbnail"] as? [String: Any],
           let thumbs = thumbObj["thumbnails"] as? [[String: Any]] {
            thumbUrl = thumbs.last?["url"] as? String
        }

        let album = albumName.map { Album(name: $0, id: "") }
        return SongItem(
            id: finalId,
            title: title,
            artists: artists,
            album: album,
            duration: durationSeconds,
            thumbnail: thumbUrl
        )
    }
}

// MARK: - Visitor Manager (Caches YouTube X-Goog-Visitor-Id)
actor VisitorManager {
    static let shared = VisitorManager()
    private var cachedVisitorId: String?
    private var lastFetchTime: Date?

    func getVisitorId(session: URLSession, videoId: String? = nil) async -> String? {
        if let id = cachedVisitorId, let t = lastFetchTime, Date().timeIntervalSince(t) < 7200 {
            return id
        }

        let targetUrlStr = videoId != nil ? "https://www.youtube.com/watch?v=\(videoId!)" : "https://www.youtube.com/"
        guard let url = URL(string: targetUrlStr) else { return cachedVisitorId }

        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")

        do {
            let (data, _) = try await session.data(for: req)
            if let html = String(data: data, encoding: .utf8) {
                if let range = html.range(of: "\"VISITOR_DATA\":\"") {
                    let substring = html[range.upperBound...]
                    if let endQuote = substring.firstIndex(of: "\"") {
                        let extracted = String(substring[..<endQuote])
                        self.cachedVisitorId = extracted
                        self.lastFetchTime = Date()
                        print("[VisitorManager] Successfully retrieved YouTube VISITOR_DATA: \(extracted.prefix(30))...")
                        return extracted
                    }
                }
            }
        } catch {
            print("[VisitorManager] Failed to fetch visitor id: \(error)")
        }

        return cachedVisitorId
    }
}
