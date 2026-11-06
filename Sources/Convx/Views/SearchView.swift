import SwiftUI

public struct SearchView: View {
    public enum SearchTab: String, CaseIterable {
        case songs = "Canciones"
        case playlists = "Playlists"
    }

    @ObservedObject var player = AudioPlayerService.shared
    @State private var query = ""
    @State private var suggestions: [String] = []
    @State private var results: [SongItem] = []
    @State private var playlistResults: [PlaylistItem] = []
    @State private var selectedTab: SearchTab = .songs
    @State private var isSearching = false
    @State private var isSearchingPlaylists = false
    @State private var hasSearched = false
    @State private var detectedArtist: ArtistItem?
    @State private var selectedArtist: ArtistItem?
    @State private var selectedAlbum: AlbumItem?
    @State private var selectedSongForPlaylist: SongItem?
    @FocusState private var isSearchFocused: Bool

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isSearchFocused = false
                        hideKeyboard()
                    }

                VStack(spacing: 0) {
                    // Header Search Bar Row
                    HStack(spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.white.opacity(0.5))

                            TextField("Search songs, artists, playlists...", text: $query)
                                .foregroundColor(.white)
                                .tint(.cyan)
                                .autocorrectionDisabled()
                                .submitLabel(.search)
                                .focused($isSearchFocused)
                                .onSubmit {
                                    isSearchFocused = false
                                    performSearch(for: query)
                                }
                                .onChange(of: query) { _, newText in
                                    if !newText.isEmpty && !hasSearched {
                                        Task {
                                            suggestions = await InnerTubeService.shared.getSuggestions(query: newText)
                                        }
                                    } else if newText.isEmpty {
                                        suggestions = []
                                        results = []
                                        playlistResults = []
                                        detectedArtist = nil
                                        hasSearched = false
                                    }
                                }

                            if !query.isEmpty {
                                Button(action: {
                                    query = ""
                                    suggestions = []
                                    results = []
                                    playlistResults = []
                                    detectedArtist = nil
                                    hasSearched = false
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .liquidGlass(cornerRadius: 18, opacity: 0.75)

                        // Cancel / Dismiss button
                        if isSearchFocused || !query.isEmpty {
                            Button("Cancelar") {
                                isSearchFocused = false
                                query = ""
                                suggestions = []
                                results = []
                                playlistResults = []
                                detectedArtist = nil
                                hasSearched = false
                                hideKeyboard()
                            }
                            .foregroundColor(.cyan)
                            .font(.system(size: 15, weight: .semibold))
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }

                        if isSearching || isSearchingPlaylists {
                            ProgressView()
                                .tint(.white)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 10)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isSearchFocused)

                    // Filter Tabs: Canciones | Playlists
                    if hasSearched {
                        HStack(spacing: 10) {
                            ForEach(SearchTab.allCases, id: \.self) { tab in
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedTab = tab
                                    }
                                    if tab == .playlists && playlistResults.isEmpty && !query.isEmpty && !isSearchingPlaylists {
                                        fetchPlaylistsOnly(for: query)
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: tab == .songs ? "music.note" : "music.note.list")
                                            .font(.system(size: 13, weight: .semibold))
                                        Text(tab.rawValue)
                                            .font(.system(size: 14, weight: .semibold))

                                        if tab == .songs && !results.isEmpty {
                                            Text("\(results.count)")
                                                .font(.system(size: 11, weight: .bold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.white.opacity(selectedTab == tab ? 0.25 : 0.12))
                                                .clipShape(Capsule())
                                        } else if tab == .playlists && !playlistResults.isEmpty {
                                            Text("\(playlistResults.count)")
                                                .font(.system(size: 11, weight: .bold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.white.opacity(selectedTab == tab ? 0.25 : 0.12))
                                                .clipShape(Capsule())
                                        }
                                    }
                                    .foregroundColor(selectedTab == tab ? .black : .white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        selectedTab == tab
                                            ? Color.white
                                            : Color.white.opacity(0.08)
                                    )
                                    .cornerRadius(20)
                                }
                                .buttonStyle(.plain)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                        .transition(.opacity)
                    }

                    // Results, Playlists, or Suggestions
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 14) {
                            // If user is typing and has not submitted yet: show suggestions
                            if !suggestions.isEmpty && !hasSearched {
                                ForEach(suggestions, id: \.self) { suggestion in
                                    Button(action: {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        query = suggestion
                                        isSearchFocused = false
                                        hideKeyboard()
                                        performSearch(for: suggestion)
                                    }) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "magnifyingglass")
                                                .foregroundColor(.white.opacity(0.4))
                                                .font(.system(size: 14))
                                            Text(suggestion)
                                                .font(.system(size: 16))
                                                .foregroundColor(.white)
                                            Spacer()
                                            Image(systemName: "arrow.up.left")
                                                .foregroundColor(.white.opacity(0.3))
                                                .font(.system(size: 12))
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                    }
                                    .buttonStyle(.plain)
                                }
                            } else if hasSearched {
                                if selectedTab == .songs {
                                    if isSearching && results.isEmpty {
                                        VStack(spacing: 8) {
                                            ForEach(0..<6, id: \.self) { _ in
                                                SongRowSkeletonView()
                                                    .padding(.horizontal, 18)
                                            }
                                        }
                                    } else {
                                        songsResultView
                                    }
                                } else {
                                    playlistsResultView
                                }
                            } else {
                                // Default trending search categories
                                defaultCategoriesView
                            }

                            Spacer().frame(height: 165)
                        }
                        .padding(.top, 8)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .simultaneousGesture(
                        DragGesture().onChanged { _ in
                            if isSearchFocused {
                                isSearchFocused = false
                                hideKeyboard()
                            }
                        }
                    )
                    .onTapGesture {
                        isSearchFocused = false
                        hideKeyboard()
                    }
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isSearchFocused = false
                        hideKeyboard()
                    }
                    .foregroundColor(.cyan)
                    .fontWeight(.semibold)
                }
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

    // MARK: - Songs Results View
    private var songsResultView: some View {
        Group {
            if results.isEmpty && !isSearching {
                VStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.3))
                    Text("No se encontraron canciones para \"\(query)\"")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, minHeight: 250)
            } else {
                // Dedicated Artist Hero Card if an artist was detected
                if let artist = detectedArtist {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        selectedArtist = artist
                    }) {
                        HStack(spacing: 14) {
                            ArtworkImageView(urlString: artist.thumbnail, size: 56, cornerRadius: 28)
                                .overlay(Circle().stroke(Color.cyan.opacity(0.6), lineWidth: 1.5))
                                .shadow(color: Color.cyan.opacity(0.3), radius: 8, x: 0, y: 3)

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(artist.name)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 13))
                                        .foregroundColor(.cyan)
                                }

                                Text("Artista oficial • Ver perfil y discografía")
                                    .font(.system(size: 12))
                                    .foregroundColor(.cyan.opacity(0.85))
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(18)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12), lineWidth: 1))
                        .padding(.horizontal, 18)
                        .padding(.bottom, 6)
                    }
                    .buttonStyle(.plain)
                }

                ForEach(results) { song in
                    SwipeableSongRow(song: song, onPlayNext: {
                        player.playNext(song)
                    }) {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            isSearchFocused = false
                            hideKeyboard()
                            player.playTrack(song, inQueue: results)
                        }) {
                            HStack(spacing: 14) {
                                ArtworkImageView(urlString: song.thumbnail, size: 52, cornerRadius: 10)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(song.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Text(song.artistNames)
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.6))
                                        .lineLimit(1)
                                }

                                Spacer()

                                DownloadButton(song: song, size: 20)
                                    .padding(.trailing, 2)

                                Text(song.formattedDuration)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(14)
                        }
                        .buttonStyle(.plain)
                    }
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
                    .padding(.horizontal, 18)
                }
            }
        }
    }

    // MARK: - Playlists Results View
    private var playlistsResultView: some View {
        Group {
            if isSearchingPlaylists && playlistResults.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
                    Text("Buscando playlists...")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, minHeight: 250)
            } else if playlistResults.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.3))
                    Text("No se encontraron playlists para \"\(query)\"")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, minHeight: 250)
            } else {
                ForEach(playlistResults) { playlist in
                    NavigationLink(destination: PublicPlaylistDetailView(playlist: playlist)) {
                        HStack(spacing: 14) {
                            ArtworkImageView(urlString: playlist.thumbnail, size: 56, cornerRadius: 10)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(playlist.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)

                                Text(playlist.author ?? "YouTube Music")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.6))
                                    .lineLimit(1)

                                if let count = playlist.songCountText {
                                    Text(count)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.cyan.opacity(0.85))
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.35))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(14)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 18)
                }
            }
        }
    }

    private var defaultCategoriesView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Browse Categories")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)

            let categories = [
                ("Top 50 Global", "globe", Color.purple),
                ("Pop Hits", "star.fill", Color.pink),
                ("Hip-Hop & R&B", "flame.fill", Color.orange),
                ("Rock & Alternative", "guitars.fill", Color.red),
                ("Electronic & Dance", "waveform.path", Color.cyan),
                ("Acoustic & Chill", "leaf.fill", Color.green)
            ]

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(categories, id: \.0) { cat in
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        query = cat.0
                        isSearchFocused = false
                        hideKeyboard()
                        performSearch(for: cat.0)
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: cat.1)
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                Text(cat.0)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .frame(height: 85)
                        .background(
                            cat.2.opacity(0.3)
                        )
                        .liquidGlass(cornerRadius: 16, opacity: 0.6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func performSearch(for text: String) {
        let cleanText = text.trimmingCharacters(in: .whitespaces)
        guard !cleanText.isEmpty else { return }

        isSearching = true
        isSearchingPlaylists = true
        hasSearched = true
        suggestions = []

        Task {
            // Concurrent search for songs (with artist detection) and playlists
            async let detailedTask = InnerTubeService.shared.searchDetailed(query: cleanText)
            async let playlistsTask = InnerTubeService.shared.searchPlaylists(query: cleanText)

            do {
                let detailed = try await detailedTask
                results = detailed.songs
                detectedArtist = detailed.artist

                // Predictive stream pre-warming for instant 0ms start on tap
                if let first = detailed.songs.first {
                    AudioPlayerService.shared.prewarmTrack(first)
                }
                if detailed.songs.count > 1 {
                    AudioPlayerService.shared.prewarmTrack(detailed.songs[1])
                }
            } catch {
                results = []
                detectedArtist = nil
            }
            isSearching = false

            do {
                playlistResults = try await playlistsTask
            } catch {
                playlistResults = []
            }
            isSearchingPlaylists = false
        }
    }

    private func fetchPlaylistsOnly(for text: String) {
        let cleanText = text.trimmingCharacters(in: .whitespaces)
        guard !cleanText.isEmpty else { return }

        isSearchingPlaylists = true
        Task {
            do {
                playlistResults = try await InnerTubeService.shared.searchPlaylists(query: cleanText)
            } catch {
                playlistResults = []
            }
            isSearchingPlaylists = false
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
