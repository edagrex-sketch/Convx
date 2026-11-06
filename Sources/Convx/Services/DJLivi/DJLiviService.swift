import Foundation
import SwiftUI
import Combine

// MARK: - DJ Livi State
public enum DJLiviState: Equatable, Sendable {
    case idle
    case speaking(topic: String)
    case playing(setName: String, bpm: Int)
    case listening
    case analyzing(action: String)

    public var statusText: String {
        switch self {
        case .idle:
            return "DJ Livi lista para mezclar"
        case .speaking(let topic):
            return "Livi hablando: \(topic)"
        case .playing(let setName, let bpm):
            return "Set: \(setName) • \(bpm) BPM"
        case .listening:
            return "Livi te está escuchando..."
        case .analyzing(let action):
            return "\(action)..."
        }
    }
}

// MARK: - Chat Message Model
public struct DJLiviChatMessage: Identifiable, Equatable {
    public let id: String
    public let sender: MessageSender
    public let text: String
    public let timestamp: Date
    public let suggestedSongs: [SongItem]?
    public let triviaData: String?

    public enum MessageSender: Equatable {
        case user
        case livi
    }

    public init(
        id: String = UUID().uuidString,
        sender: MessageSender,
        text: String,
        timestamp: Date = Date(),
        suggestedSongs: [SongItem]? = nil,
        triviaData: String? = nil
    ) {
        self.id = id
        self.sender = sender
        self.text = text
        self.timestamp = timestamp
        self.suggestedSongs = suggestedSongs
        self.triviaData = triviaData
    }
}

// MARK: - Chapter Definition
public struct DJMusicChapter {
    public let name: String
    public let searchSeed: String
    public let category: String
    public let defaultBPM: Int
    public let introPhrase: String
}

// MARK: - Master DJ Livi Service
@MainActor
public final class DJLiviService: ObservableObject {
    public static let shared = DJLiviService()

    @Published public var currentState: DJLiviState = .idle
    @Published public var isDJSessionActive: Bool = false
    @Published public var isSheetPresented: Bool = false
    @Published public var currentSetName: String = "Descubrimiento Personal Convx"
    @Published public var chatMessages: [DJLiviChatMessage] = []
    @Published public var songsInChapter: [SongItem] = []
    @Published public var currentSongInChapterIndex: Int = 0
    @Published public var talkFrequency: Int = 3 // Habla cada 3 canciones
    @Published public var songsPlayedInCurrentBlock: Int = 0

    private var dislikedGenres: Set<String> = []
    private var lastPlayedVibes: [String] = []
    private var cancellables = Set<AnyCancellable>()

    // Catálogo diverso de Capítulos para mezclar (30+ estilos)
    private let availableChapters: [DJMusicChapter] = [
        DJMusicChapter(
            name: "Joyas Ocultas & Indie Pop",
            searchSeed: "indie pop dream pop gems 2024",
            category: "Indie",
            defaultBPM: 116,
            introPhrase: "¡Qué onda! Te preparé una tanda de joyas ocultas e indie pop fresquecito que te va a volar la cabeza."
        ),
        DJMusicChapter(
            name: "Noche Cyberpunk & Synthwave",
            searchSeed: "synthwave darksynth retrowave essentials",
            category: "Synthwave",
            defaultBPM: 122,
            introPhrase: "Vámonos con luces de neón y sintetizadores ochenteros. Pura vibra outrun para la noche."
        ),
        DJMusicChapter(
            name: "Tokyo 80s City Pop",
            searchSeed: "japanese 80s city pop essentials",
            category: "City Pop",
            defaultBPM: 118,
            introPhrase: "Viajando a Tokio en 1985 con puro City Pop elegante, bajos con slap y pianos brillantes."
        ),
        DJMusicChapter(
            name: "Corridos Tumbados & Bélicos",
            searchSeed: "corridos tumbados exitos 2024",
            category: "Corridos",
            defaultBPM: 130,
            introPhrase: "¡Y arriba México! Vámonos con requintos y charchetas en esta selección bélica."
        ),
        DJMusicChapter(
            name: "French House & Nu-Disco",
            searchSeed: "french touch nu disco filter house hits",
            category: "Electronic",
            defaultBPM: 125,
            introPhrase: "¡A bailar! Metemos filtro disco y compresión pesada al estilo French Touch."
        ),
        DJMusicChapter(
            name: "Shoegaze & Dream Waves",
            searchSeed: "shoegaze dream pop ethereal essentials",
            category: "Shoegaze",
            defaultBPM: 110,
            introPhrase: "Guitarras con reverb infinito y voces etéreas... Sumérgete en este viaje de shoegaze."
        ),
        DJMusicChapter(
            name: "Reggaetón & Perreo Pesado",
            searchSeed: "reggaeton clasico y nuevo perreo hits",
            category: "Urbano",
            defaultBPM: 95,
            introPhrase: "¡Súbele al bajo! Traigo una selección con el dembow bien puesto para encender la vibra."
        ),
        DJMusicChapter(
            name: "Afrobeats & Amapiano",
            searchSeed: "afrobeats amapiano viral hits",
            category: "Afrobeats",
            defaultBPM: 112,
            introPhrase: "Poli-ritmos africanos y log drums envolventes. Esta vibra bailable no falla."
        ),
        DJMusicChapter(
            name: "Rock en Español 90s Inmortales",
            searchSeed: "rock en espanol clasicos 90s soda caifanes",
            category: "Rock",
            defaultBPM: 120,
            introPhrase: "Puros himnos que marcaron época. La era dorada del rock en nuestro idioma."
        ),
        DJMusicChapter(
            name: "Lo-Fi Beats para Concentrarse",
            searchSeed: "lofi hip hop beats to study relax chill",
            category: "Lo-Fi",
            defaultBPM: 85,
            introPhrase: "Modo enfoque activado. Texturas de vinilo y acordes de piano jazz para concentrarse."
        ),
        DJMusicChapter(
            name: "Hyperpop Maximalista",
            searchSeed: "hyperpop glitchcore essentials",
            category: "Hyperpop",
            defaultBPM: 140,
            introPhrase: "Saturación pop al límite, energía glitch y sintetizadores futuristas. ¡Pura adrenalina!"
        ),
        DJMusicChapter(
            name: "Post-Punk & Dark Wave",
            searchSeed: "russian post punk darkwave molchat doma",
            category: "Post-Punk",
            defaultBPM: 128,
            introPhrase: "Cajas de ritmo frías, bajos melancólicos y estética soviética post-punk."
        )
    ]

    private init() {
        setupWelcomeMessage()
        // observePlayback() // Comentado para evitar que interfiera con la reproducción normal
    }

    private func setupWelcomeMessage() {
        chatMessages = [
            DJLiviChatMessage(
                sender: .livi,
                text: "¡Hola! Soy Livi, tu DJ e investigadora musical en Convx. Cuéntame qué vibra traes hoy, pídeme una trivia de la canción actual, o dime si quieres cambiar de género.",
                triviaData: nil
            )
        ]
    }

    // MARK: - Observer for Chapters & Bound Transitions
    private func observePlayback() {
        AudioPlayerService.shared.$currentTrack
            .compactMap { $0 }
            .removeDuplicates { $0.id == $1.id }
            .sink { [weak self] currentSong in
                guard let self = self, self.isDJSessionActive else { return }
                self.handleTrackChanged(currentSong)
            }
            .store(in: &cancellables)
    }

    private func handleTrackChanged(_ song: SongItem) {
        songsPlayedInCurrentBlock += 1
        let bpm = DJEngineService.shared.estimateBPM(for: song)
        self.currentState = .playing(setName: currentSetName, bpm: bpm)

        // Si ya tocamos el bloque de 3-4 canciones, cambiamos de onda automáticamente
        if songsPlayedInCurrentBlock >= talkFrequency {
            print("[DJLiviService] Chapter boundary reached (\(songsPlayedInCurrentBlock) songs). Transitioning to next set...")
            songsPlayedInCurrentBlock = 0
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                self.triggerVibeShift(automatic: true)
            }
        }
    }

    // MARK: - Start DJ Session
    public func startDJSession(themeName: String? = nil) {
        isDJSessionActive = true
        songsPlayedInCurrentBlock = 0
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()

        let chapter = availableChapters.first(where: { $0.name == themeName }) ?? availableChapters[0]
        currentSetName = chapter.name
        currentState = .analyzing(action: "Curando set de \(chapter.name)")

        Task {
            let results = (try? await InnerTubeService.shared.search(query: chapter.searchSeed)) ?? []
            let tracks = Array(results.prefix(4))

            if let first = tracks.first {
                AudioPlayerService.shared.playTrack(first, inQueue: tracks)
            }

            let greeting = getTimeBasedGreeting()
            let speechScript = "\(greeting) Soy Livi. \(chapter.introPhrase) ¡Disfruta a \(tracks.first?.artistNames ?? "los mejores artistas")!"

            self.currentState = .speaking(topic: chapter.name)
            await DJLiviVoiceService.shared.speak(text: speechScript)

            let bpm = tracks.first != nil ? DJEngineService.shared.estimateBPM(for: tracks.first!) : chapter.defaultBPM
            self.currentState = .playing(setName: self.currentSetName, bpm: bpm)

            HUDService.shared.show(icon: "sparkles", iconColor: .cyan, title: "DJ Livi Activa", subtitle: chapter.name)
        }
    }

    // MARK: - Cambiar Onda (Vibe Shift)
    public func triggerVibeShift(automatic: Bool = false) {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        DJEngineService.shared.triggerDropHaptics()

        // Filtrar capítulos disponibles
        let validChapters = availableChapters.filter { ch in
            !dislikedGenres.contains(ch.category.lowercased()) && ch.name != currentSetName
        }
        let nextChapter = validChapters.randomElement() ?? availableChapters[1]
        currentSetName = nextChapter.name
        currentState = .analyzing(action: "Cambiando a \(nextChapter.name)")

        Task {
            let results = (try? await InnerTubeService.shared.search(query: nextChapter.searchSeed)) ?? []
            let tracks = Array(results.prefix(4))

            if let first = tracks.first {
                // Mezcla suave con DJEngineService
                AudioPlayerService.shared.playTrack(first, inQueue: tracks)
            }

            let speech: String
            if automatic {
                speech = "Cerramos esa tanda. Ahora vámonos con \(nextChapter.name)... ¡Súbele al beat!"
            } else {
                speech = "¡Cambiamos de onda! Te traigo una selección de \(nextChapter.name)... ¡Chécate esto!"
            }

            self.currentState = .speaking(topic: nextChapter.name)
            await DJLiviVoiceService.shared.speak(text: speech)

            let bpm = tracks.first != nil ? DJEngineService.shared.estimateBPM(for: tracks.first!) : nextChapter.defaultBPM
            self.currentState = .playing(setName: nextChapter.name, bpm: bpm)

            HUDService.shared.show(icon: "arrow.triangle.2.circlepath", iconColor: .purple, title: "Cambio de Onda", subtitle: nextChapter.name)
        }
    }

    // MARK: - Bidirectional Conversational Assistant
    public func sendUserPrompt(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let userMsg = DJLiviChatMessage(sender: .user, text: trimmed)
        chatMessages.append(userMsg)

        currentState = .analyzing(action: "Livi está procesando")

        Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            await processAIResponse(for: trimmed)
        }
    }

    private func processAIResponse(for query: String) async {
        let lower = query.lowercased()

        // 1. Trivia o Dato Curioso
        if lower.contains("curioso") || lower.contains("trivia") || lower.contains("sabias") || lower.contains("historia") {
            let current = AudioPlayerService.shared.currentTrack
            let songTitle = current?.title ?? "esta pista"
            let artist = current?.artistNames ?? "este artista"

            // Consultar enciclopedia de Livi
            let searchGenre = DJLiviEncyclopediaService.shared.searchGenre(matching: "\(songTitle) \(artist)")
                ?? DJLiviEncyclopediaService.shared.getRandomKnowledge()

            let trivia = "Dato de producción sobre \(artist): Su sonido en '\(songTitle)' se caracteriza por \(searchGenre.iconicInstruments). \(searchGenre.triviaFact)"
            let responseText = "¡Tengo el dato perfecto! \(trivia)"

            appendLiviMessage(text: responseText, trivia: trivia)
            await speakResponse(text: "¡Chécate este dato! \(searchGenre.triviaFact)")

        // 2. ¿Por qué elegiste esta rola?
        } else if lower.contains("por qué") || lower.contains("porque") || lower.contains("elegiste") || lower.contains("pusiste") {
            let current = AudioPlayerService.shared.currentTrack
            let bpm = current != nil ? DJEngineService.shared.estimateBPM(for: current!) : 120
            let key = current != nil ? DJEngineService.shared.estimateCamelotKey(for: current!) : "8A"
            let title = current?.title ?? "esta canción"

            let explanation = "Elegí '\(title)' porque hace una transición armónica ideal en clave Camelot \(key) a \(bpm) BPM con tu flujo de escucha reciente, manteniendo la energía alta sin fatiga auditiva."
            appendLiviMessage(text: explanation)
            await speakResponse(text: "La elegí por compatibilidad armónica en Camelot \(key) y porque encaja perfecto con tu energía actual.")

        // 3. Solicitud de Fiesta / Más Bailable
        } else if lower.contains("bailable") || lower.contains("fiesta") || lower.contains("antrero") || lower.contains("bailar") {
            let tracks = (try? await InnerTubeService.shared.search(query: "club dance hits bailable latino 2024")) ?? []
            let topTracks = Array(tracks.prefix(4))
            currentSetName = "Fiesta & Club Energy"

            let text = "¡Subiendo los decibeles! Te armé un set de fiesta a 128 BPM con 'Drop & Bass Swap' activado para que la pista no se apague."
            appendLiviMessage(text: text, songs: topTracks)

            if let first = topTracks.first {
                AudioPlayerService.shared.playTrack(first, inQueue: topTracks)
            }
            await speakResponse(text: "¡Vámonos de fiesta! Aquí tienes un set bailable con ritmo continuo.")

        // 4. Veto o Descarte de Género
        } else if lower.contains("no me gustó") || lower.contains("no me gusta") || lower.contains("quita") || lower.contains("salta") || lower.contains("bloquea") {
            let current = AudioPlayerService.shared.currentTrack
            if let artist = current?.artistNames {
                dislikedGenres.insert(artist.lowercased())
            }
            AudioPlayerService.shared.skipNext()

            let text = "¡Entendido al 100%! Salté la canción y tomé nota para no meter este género en tu sesión de hoy. Recalibrando el algoritmo de una..."
            appendLiviMessage(text: text)
            triggerVibeShift()

        // 5. Géneros Específicos (City Pop, Corridos, Shoegaze, etc.)
        } else if let matchedGenre = DJLiviEncyclopediaService.shared.searchGenre(matching: query) {
            let tracks = (try? await InnerTubeService.shared.search(query: "\(matchedGenre.name) best songs")) ?? []
            let topTracks = Array(tracks.prefix(4))
            currentSetName = matchedGenre.name

            let text = "¡Excelente gusto! Sumergiéndonos en \(matchedGenre.name). Instrumentación típica: \(matchedGenre.iconicInstruments). \(matchedGenre.triviaFact)"
            appendLiviMessage(text: text, songs: topTracks, trivia: matchedGenre.triviaFact)

            if let first = topTracks.first {
                AudioPlayerService.shared.playTrack(first, inQueue: topTracks)
            }
            await speakResponse(text: "¡De una! Vámonos con lo mejor de \(matchedGenre.name).")

        // 6. Solicitud Libre / Búsqueda Genérica
        } else {
            let tracks = (try? await InnerTubeService.shared.search(query: "\(query) mix")) ?? []
            let topTracks = Array(tracks.prefix(4))

            let text = "Ajusté tu set para reflejar: \"\(query)\". Aquí tienes las canciones que acabo de incorporar a la cola para ti:"
            appendLiviMessage(text: text, songs: topTracks)

            if let first = topTracks.first {
                AudioPlayerService.shared.playNext(first)
            }
            await speakResponse(text: "Listo, agregué música con la onda que me pediste a tu cola.")
        }
    }

    private func appendLiviMessage(text: String, songs: [SongItem]? = nil, trivia: String? = nil) {
        let msg = DJLiviChatMessage(sender: .livi, text: text, suggestedSongs: songs, triviaData: trivia)
        chatMessages.append(msg)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func speakResponse(text: String) async {
        guard DJLiviVoiceService.shared.isVoiceEnabled else {
            currentState = .playing(setName: currentSetName, bpm: 120)
            return
        }
        currentState = .speaking(topic: "Respondiendo")
        await DJLiviVoiceService.shared.speak(text: text)
        let bpm = AudioPlayerService.shared.currentTrack != nil ? DJEngineService.shared.estimateBPM(for: AudioPlayerService.shared.currentTrack!) : 124
        currentState = .playing(setName: currentSetName, bpm: bpm)
    }

    private func getTimeBasedGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "¡Buenos días!"
        case 12..<19: return "¡Buenas tardes!"
        default:      return "¡Buenas noches!"
        }
    }
}
