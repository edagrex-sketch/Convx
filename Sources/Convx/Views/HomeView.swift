import SwiftUI

public struct HomeView: View {
    @ObservedObject var player = AudioPlayerService.shared
    private let history = PlaybackHistoryService.shared
    private let likedService = LikedSongsService.shared

    @State private var sections: [HomeSection] = []
    @State private var recentSongs: [SongItem] = []
    @State private var favoriteSongs: [SongItem] = []
    @State private var featuredPlaylists: [PlaylistItem] = []
    @State private var isLoading = true
    @State private var selectedMood = "All"
    @State private var selectedArtist: ArtistItem?
    @State private var selectedAlbum: AlbumItem?
    @State private var selectedSongForPlaylist: SongItem?

    let moods = ["All", "Chill", "Energy", "Workout", "Focus", "Party"]

    public init() {}

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 5 && hour < 12 {
            return "Buenos días"
        } else if hour >= 12 && hour < 20 {
            return "Buenas tardes"
        } else {
            return "Buenas noches"
        }
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.clear

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header & Greeting
                        headerView
                            .padding(.horizontal, 20)
                            .padding(.top, 16)

                        // Mood Pills
                        moodSelectorView

                        // DJ Livi AI Curator Hero Card (Comentado temporalmente)
                        // DJLiviHeroCard()
                        //     .padding(.horizontal, 20)

                        // Quick Access Grid (Top 6 Recents / Favorites)
                        if !quickAccessItems.isEmpty {
                            quickAccessGridView
                                .padding(.horizontal, 20)
                        }

                        // Main Content Sections
                        if isLoading && sections.isEmpty && recentSongs.isEmpty {
                            loadingFeedView
                        } else {
                            // Section 1: Recently Played (from History)
                            if !recentSongs.isEmpty {
                                songCarousel(
                                    title: "Escuchado Recientemente",
                                    subtitle: "Vuelve a donde te quedaste",
                                    items: recentSongs
                                )
                            }

                            // Section 2: User Favorites / Most Repeated
                            if !favoriteSongs.isEmpty {
                                songCarousel(
                                    title: "Tus Favoritas y Más Repetidas",
                                    subtitle: "Las canciones que más te gustan",
                                    items: favoriteSongs
                                )
                            }

                            // Dynamic Recommendation Sections from Music Pipeline
                            ForEach(sections) { section in
                                songCarousel(
                                    title: section.title,
                                    subtitle: section.subtitle,
                                    items: section.items
                                )
                            }

                            // Public Playlists Section
                            if !featuredPlaylists.isEmpty {
                                playlistsCarousel(
                                    title: "Playlists Sugeridas Para Ti",
                                    subtitle: "Colecciones públicas listas para escuchar",
                                    playlists: featuredPlaylists
                                )
                            }
                        }

                        // Bottom spacing for miniplayer + floating glass tab bar
                        Spacer().frame(height: 165)
                    }
                }
                .refreshable {
                    await loadHomeFeed(mood: selectedMood)
                }
            }
            .task {
                await loadHomeFeed(mood: selectedMood)
            }
            .sheet(item: $selectedArtist) { artist in
                ArtistDetailView(artistId: artist.id, initialName: artist.name, initialThumbnail: artist.thumbnail)
            }
            .sheet(item: $selectedAlbum) { album in
                AlbumDetailView(albumId: album.id, initialTitle: album.title, initialArtist: album.artistName, initialThumbnail: album.thumbnail)
            }
            .sheet(item: $selectedSongForPlaylist) { song in
                AddToPlaylistSheet(song: song)
            }
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(greetingText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.cyan.opacity(0.9))
                    .textCase(.uppercase)

                Text("Convx Music")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            Spacer()

            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                Task { await loadHomeFeed(mood: selectedMood) }
            }) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.cyan)
                    .frame(width: 42, height: 42)
                    .liquidGlass(cornerRadius: 21, opacity: 0.65)
            }
        }
    }

    // MARK: - Mood Selector
    private var moodSelectorView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(moods, id: \.self) { mood in
                    Button(action: {
                        guard selectedMood != mood else { return }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedMood = mood
                        Task {
                            await loadHomeFeed(mood: mood)
                        }
                    }) {
                        Text(mood)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(selectedMood == mood ? .black : .white.opacity(0.85))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selectedMood == mood ? Color.white : Color.white.opacity(0.10))
                            )
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Quick Access 6-Grid
    private var quickAccessItems: [SongItem] {
        var items: [SongItem] = []
        var seenIds = Set<String>()

        for song in recentSongs + favoriteSongs {
            if !seenIds.contains(song.id) {
                seenIds.insert(song.id)
                items.append(song)
                if items.count == 6 { break }
            }
        }
        return items
    }

    private var quickAccessGridView: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(quickAccessItems) { song in
                let isPlaying = player.currentTrack?.id == song.id

                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    player.playTrack(song, inQueue: quickAccessItems)
                }) {
                    HStack(spacing: 10) {
                        ArtworkImageView(urlString: song.thumbnail, songId: song.id, size: 52, cornerRadius: 10)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(isPlaying ? .cyan : .white)
                                .lineLimit(1)

                            Text(song.artistNames)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                        }

                        Spacer()

                        if isPlaying {
                            Image(systemName: "waveform")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.cyan)
                                .padding(.trailing, 6)
                        }
                    }
                    .padding(6)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        player.playNext(song)
                    } label: {
                        Label("Reproducir a continuación", systemImage: "text.line.first.and.arrowtriangle.forward")
                    }

                    Button {
                        player.addToQueue(song)
                    } label: {
                        Label("Agregar a la cola", systemImage: "text.append")
                    }

                    if let firstArtist = song.artists.first, let artistId = firstArtist.id, !artistId.isEmpty {
                        Button {
                            selectedArtist = ArtistItem(id: artistId, name: firstArtist.name, thumbnail: song.thumbnail)
                        } label: {
                            Label("Ver Artista: \(firstArtist.name)", systemImage: "person.circle")
                        }
                    }

                    if let album = song.album, !album.id.isEmpty {
                        Button {
                            selectedAlbum = AlbumItem(id: album.id, title: album.name, artistName: song.artistNames, thumbnail: song.thumbnail)
                        } label: {
                            Label("Ver Álbum: \(album.name)", systemImage: "opticaldisc")
                        }
                    }

                    Button {
                        selectedSongForPlaylist = song
                    } label: {
                        Label("Agregar a playlist", systemImage: "plus")
                    }
                }
            }
        }
    }

    // MARK: - Song Carousel
    private func songCarousel(title: String, subtitle: String? = nil, items: [SongItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(.white)
                    if let sub = subtitle {
                        Text(sub)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.55))
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(items) { item in
                        let isPlaying = player.currentTrack?.id == item.id

                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            player.playTrack(item, inQueue: items)
                        }) {
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack(alignment: .bottomTrailing) {
                                    ArtworkImageView(urlString: item.thumbnail, songId: item.id, size: 148, cornerRadius: 16)
                                        .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)

                                    if isPlaying {
                                        Circle()
                                            .fill(Color.black.opacity(0.75))
                                            .frame(width: 32, height: 32)
                                            .overlay(
                                                Image(systemName: "waveform")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(.cyan)
                                            )
                                            .padding(8)
                                    }
                                }

                                Text(item.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(isPlaying ? .cyan : .white)
                                    .lineLimit(1)
                                    .frame(width: 148, alignment: .leading)

                                Text(item.artistNames)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.6))
                                    .lineLimit(1)
                                    .frame(width: 148, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                player.playNext(item)
                            } label: {
                                Label("Reproducir a continuación", systemImage: "text.line.first.and.arrowtriangle.forward")
                            }

                            Button {
                                player.addToQueue(item)
                            } label: {
                                Label("Agregar a la cola", systemImage: "text.append")
                            }

                            if let firstArtist = item.artists.first, let artistId = firstArtist.id, !artistId.isEmpty {
                                Button {
                                    selectedArtist = ArtistItem(id: artistId, name: firstArtist.name, thumbnail: item.thumbnail)
                                } label: {
                                    Label("Ver Artista: \(firstArtist.name)", systemImage: "person.circle")
                                }
                            }

                            if let album = item.album, !album.id.isEmpty {
                                Button {
                                    selectedAlbum = AlbumItem(id: album.id, title: album.name, artistName: item.artistNames, thumbnail: item.thumbnail)
                                } label: {
                                    Label("Ver Álbum: \(album.name)", systemImage: "opticaldisc")
                                }
                            }

                            Button {
                                selectedSongForPlaylist = item
                            } label: {
                                Label("Agregar a playlist", systemImage: "plus")
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Playlists Carousel
    private func playlistsCarousel(title: String, subtitle: String? = nil, playlists: [PlaylistItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(.white)
                    if let sub = subtitle {
                        Text(sub)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.55))
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(playlists) { playlist in
                        NavigationLink(destination: PublicPlaylistDetailView(playlist: playlist)) {
                            VStack(alignment: .leading, spacing: 8) {
                                ArtworkImageView(urlString: playlist.thumbnail, size: 148, cornerRadius: 16)
                                    .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)

                                Text(playlist.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .frame(width: 148, alignment: .leading)

                                Text(playlist.author ?? "YouTube Music")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.6))
                                    .lineLimit(1)
                                    .frame(width: 148, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var loadingFeedView: some View {
        VStack(spacing: 12) {
            ForEach(0..<5, id: \.self) { _ in
                SongRowSkeletonView()
                    .padding(.horizontal, 20)
            }
        }
        .padding(.top, 16)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Smart Home Feed Loader
    private func loadHomeFeed(mood: String) async {
        // 1. Instant Local History & Favorites (0ms offline ready)
        let historyItems = history.getHistoryItems()
        let localRecents = historyItems.prefix(15).map { $0.toSongItem() }
        let repeated = history.getRepeatedSongs(minPlayCount: 2, limit: 12)
        let liked = likedService.getLikedSongs()

        await MainActor.run {
            self.recentSongs = Array(localRecents)
            var favList = liked
            for r in repeated {
                if !favList.contains(where: { $0.id == r.id }) {
                    favList.append(r)
                }
            }
            self.favoriteSongs = favList
            if let firstFav = favList.first {
                AudioPlayerService.shared.prewarmTrack(firstFav)
            } else if let firstRecent = self.recentSongs.first {
                AudioPlayerService.shared.prewarmTrack(firstRecent)
            }
        }

        // 2. Specific Mood Handler
        if mood != "All" {
            await loadMoodSpecificFeed(mood: mood)
            await MainActor.run { self.isLoading = false }
            return
        }

        // 3. Personalized "All" Feed Construction
        let topArtists = history.getTopArtists(limit: 3)
        let primaryArtist = topArtists.first ?? "Morat"
        let secondaryArtist = topArtists.count > 1 ? topArtists[1] : "Reik"

        async let topHitsTask = InnerTubeService.shared.search(query: "Top Canciones Éxitos 2026")
        async let primaryArtistTask = InnerTubeService.shared.search(query: "\(primaryArtist) álbumes éxitos")
        async let secondaryArtistTask = InnerTubeService.shared.search(query: "\(secondaryArtist) canciones")
        async let discoveryTask = InnerTubeService.shared.search(query: "Descubrimiento Pop Latino")
        async let playlistsTask = InnerTubeService.shared.searchPlaylists(query: "Grandes Éxitos")

        var newSections: [HomeSection] = []

        // Primary Artist Spotlight (User favorite)
        if let artist1Songs = try? await primaryArtistTask, !artist1Songs.isEmpty {
            newSections.append(HomeSection(
                title: "Porque escuchas \(primaryArtist)",
                subtitle: "Álbumes y canciones recomendadas de tu artista favorito",
                items: artist1Songs
            ))
        }

        // Global / Regional Chart Toppers
        if let topHits = try? await topHitsTask, !topHits.isEmpty {
            newSections.append(HomeSection(
                title: "Éxitos del Momento",
                subtitle: "Lo más escuchado y tendencia en la música",
                items: topHits
            ))
        }

        // Secondary Artist / Related Vibe
        if let artist2Songs = try? await secondaryArtistTask, !artist2Songs.isEmpty {
            newSections.append(HomeSection(
                title: "Para tu vibra: \(secondaryArtist)",
                subtitle: "Música que te va a encantar",
                items: artist2Songs
            ))
        }

        // Discovery Radar
        if let discovery = try? await discoveryTask, !discovery.isEmpty {
            newSections.append(HomeSection(
                title: "Joyas para Descubrir",
                subtitle: "Nuevas recomendaciones basadas en lo que escuchas",
                items: discovery
            ))
        }

        // Playlists
        if let playlists = try? await playlistsTask, !playlists.isEmpty {
            await MainActor.run {
                self.featuredPlaylists = playlists
            }
        }

        await MainActor.run {
            self.sections = newSections
            self.isLoading = false
        }
    }

    private func loadMoodSpecificFeed(mood: String) async {
        let query1: String
        let title1: String
        let query2: String
        let title2: String

        switch mood {
        case "Chill":
            query1 = "Acústico Relajante Pop"
            title1 = "Acústico & Tranquilidad"
            query2 = "Lo-Fi Beats Chill"
            title2 = "Calma & Desconexión"
        case "Energy":
            query1 = "Pop Dance Electrónica"
            title1 = "Energía Pura"
            query2 = "Reggaeton Éxitos Ritmo"
            title2 = "Ritmo Imparable"
        case "Workout":
            query1 = "Workout Gym Beats Motivación"
            title1 = "Motivación Entrenamiento"
            query2 = "Electro Fitness High BPM"
            title2 = "Máxima Intensidad"
        case "Focus":
            query1 = "Piano Instrumental Concentración"
            title1 = "Enfoque & Estudio"
            query2 = "Ambient Chill Focus"
            title2 = "Sonidos Sin Distracciones"
        case "Party":
            query1 = "Fiesta Latina Éxitos Baile"
            title1 = "Noche de Fiesta"
            query2 = "Reggaeton Pop Hits"
            title2 = "Para Bailar y Cantar"
        default:
            query1 = "Top Hits"
            title1 = "Top Hits"
            query2 = "Pop Hits"
            title2 = "Pop Hits"
        }

        async let task1 = InnerTubeService.shared.search(query: query1)
        async let task2 = InnerTubeService.shared.search(query: query2)
        async let playTask = InnerTubeService.shared.searchPlaylists(query: mood)

        var moodSections: [HomeSection] = []
        if let songs1 = try? await task1, !songs1.isEmpty {
            moodSections.append(HomeSection(title: title1, subtitle: "Selección para \(mood)", items: songs1))
        }
        if let songs2 = try? await task2, !songs2.isEmpty {
            moodSections.append(HomeSection(title: title2, subtitle: "Mejor música \(mood)", items: songs2))
        }
        if let pls = try? await playTask, !pls.isEmpty {
            await MainActor.run {
                self.featuredPlaylists = pls
            }
        }

        await MainActor.run {
            self.sections = moodSections
        }
    }
}
