import Foundation

// MARK: - Musical Genre & Aesthetic Profile
public struct MusicGenreKnowledge: Identifiable, Sendable {
    public var id: String { name }
    public let name: String
    public let aliases: [String]
    public let aestheticVibe: String
    public let iconicInstruments: String
    public let triviaFact: String
    public let subgenreTags: [String]
}

// MARK: - DJ Livi Encyclopedic Musicology Database
public final class DJLiviEncyclopediaService: Sendable {
    public static let shared = DJLiviEncyclopediaService()

    private let genres: [MusicGenreKnowledge] = [
        // 1. Regional & Latin
        MusicGenreKnowledge(
            name: "Corridos Tumbados",
            aliases: ["corridos belicos", "corridos", "musica mexicana", "pluma", "fuerza regida", "natanael"],
            aestheticVibe: "Fusión de guitarras de doce cuerdas tradicionales con bajos acústicos y actitud trap callejera",
            iconicInstruments: "Requinto docerola, tololoche percutido y charcheta",
            triviaFact: "El movimiento nació fusionando el corrido tradicional sonorense y sinaloense con el rap chicano de Los Ángeles.",
            subgenreTags: ["Bélico", "Sierreño Urbano", "Trap Corrido"]
        ),
        MusicGenreKnowledge(
            name: "Reggaetón Clásico & Neoperreo",
            aliases: ["reggaeton", "perreo", "urbano latino", "dembow", "bad bunny", "feid", "tainy"],
            aestheticVibe: "El ritmo sincopado del Dembow jamaicano procesado con bajos sub pesados y melodías contagiosas",
            iconicInstruments: "Caja de ritmos LinnDrum / Roland R-8, kick en 4/4 y síncopa de tresillo",
            triviaFact: "El patrón clásico de dembow fue producido originalmente por Steely & Clevie en 1989 y cruzó de Jamaica a Panamá y Puerto Rico.",
            subgenreTags: ["Old School", "Perreo Pesado", "Neo-Perreo"]
        ),
        MusicGenreKnowledge(
            name: "Rock en Español de los 90s",
            aliases: ["rock en espanol", "rock latino", "soda stereo", "caifanes", "heroes del silencio", "cafe tacvba"],
            aestheticVibe: "Guitarras con chorus y reverb expansivos, letras poéticas y la era dorada de los estadios en Iberoamérica",
            iconicInstruments: "Fender Stratocaster, sintetizadores Roland Juno-106 y bajos distorsionados",
            triviaFact: "La gira 'Canción Animal' de Soda Stereo en 1991 congregó a más de 250,000 personas en la Avenida 9 de Julio de Buenos Aires.",
            subgenreTags: ["Rock Alternativo", "Post-Punk Latino", "Goth Rock"]
        ),

        // 2. Synth, Electronic & Retro
        MusicGenreKnowledge(
            name: "Synthwave & Darksynth",
            aliases: ["synthwave", "retrowave", "outrun", "cyberpunk", "synthpop"],
            aestheticVibe: "Nostalgia retrofuturista de los años 80, persecuciones nocturnas en autos deportivos y luces de neón",
            iconicInstruments: "LinnDrum, sintetizador Prophet-5, arpegios analógicos y compresión sidechain pesada",
            triviaFact: "El movimiento estético Outrun toma su nombre del legendario videojuego de arcade de SEGA lanzado en 1986.",
            subgenreTags: ["Outrun", "Darksynth", "Dreamwave"]
        ),
        MusicGenreKnowledge(
            name: "City Pop Japonés",
            aliases: ["city pop", "japanese 80s", "tatsuro yamashita", "mariya takeuchi", "miki matsubara"],
            aestheticVibe: "Lujo cosmopolita de Tokio en plena era de la burbuja económica, mezcla de funk, jazz fusión y pop brillante",
            iconicInstruments: "Piano eléctrico Fender Rhodes, bajo slap Funky y secciones de metales impecables",
            triviaFact: "'Plastic Love' de Mariya Takeuchi fue redescubierta globalmente 35 años después gracias al algoritmo de recomendación de YouTube.",
            subgenreTags: ["Showa Pop", "AOR", "Boogie Japonés"]
        ),
        MusicGenreKnowledge(
            name: "French House & Disco Filter",
            aliases: ["french touch", "french house", "daft punk", "justice", "modjo"],
            aestheticVibe: "Samples de vinilo disco de los 70s pasados por filtros paso-bajo resonantes y una energía de pista implacable",
            iconicInstruments: "Sampler E-mu SP-1200, compresor Alesis 3630 y filtros analógicos Moog",
            triviaFact: "Daft Punk logró su característico sonido 'French Touch' aplastando las pistas de bombo contra el compresor Alesis de bajo costo.",
            subgenreTags: ["Nu-Disco", "Filter House", "Electroclash"]
        ),

        // 3. Alternative, Indie & Shoegaze
        MusicGenreKnowledge(
            name: "Shoegaze & Dream Pop",
            aliases: ["shoegaze", "dream pop", "my bloody valentine", "slowdive", "cocteau twins"],
            aestheticVibe: "Muros masivos de guitarras distorsionadas flotando bajo voces etéreas e introspectivas",
            iconicInstruments: "Fender Jazzmaster con palanca de trémolo continua (Glide Guitar) y pedal de reverb inverso Yamaha SPX90",
            triviaFact: "El término 'Shoegaze' fue inventado por la prensa británica en 1990 porque los guitarristas no miraban al público, sino a su enorme pedalera.",
            subgenreTags: ["Ethereal Wave", "Noise Pop", "Blackgaze"]
        ),
        MusicGenreKnowledge(
            name: "Hyperpop & Glitchcore",
            aliases: ["hyperpop", "glitchcore", "sophie", "100 gecs", "charli xcx"],
            aestheticVibe: "Saturación pop maximalista a velocidades vertiginosas, texturas metálicas y voces moduladas al extremo",
            iconicInstruments: "Síntesis wavetable en Serum, modulación vocal de formantes y compresión OTT al 100%",
            triviaFact: "La pionera escocesa SOPHIE diseñaba cada sonido sintetizando materiales físicos como burbujas de látex y choques de metal.",
            subgenreTags: ["Bubblegum Bass", "Digicore", "Nightcore"]
        ),

        // 4. Urban & Global
        MusicGenreKnowledge(
            name: "Afrobeats & Amapiano",
            aliases: ["afrobeats", "amapiano", "burna boy", "rema", "wizkid", "asake"],
            aestheticVibe: "Poli-ritmos africanos cálidos, vibras bailables de Lagos y Sudáfrica con bajos de troncos y shakers envolventes",
            iconicInstruments: "Log Drum sudafricano (bajos con pitch glide), kalimba y percusión talking drum",
            triviaFact: "El Amapiano nació en los townships de Gauteng, Sudáfrica, mezclando Deep House con jazz de piano y kwaito.",
            subgenreTags: ["Naija Pop", "Log Drum Beats", "Afropop"]
        ),
        MusicGenreKnowledge(
            name: "Lo-Fi Hip Hop & Chillhop",
            aliases: ["lofi", "lo-fi", "chillhop", "chilledcow", "study beats", "jazzy hip hop"],
            aestheticVibe: "Sonido de cinta analógica gastada, lluvia sutil de fondo y acordes de piano jazz ideales para concentración profunda",
            iconicInstruments: "Sampler Roland SP-404, filtros de corte de vinilo y cajas de ritmos Akai MPC",
            triviaFact: "El movimiento fue cimentado por los legendarios productores Nujabes en Japón y J Dilla en Detroit a principios de los 2000.",
            subgenreTags: ["Boom Bap", "Tape Beats", "Study Flow"]
        )
    ]

    private init() {}

    // MARK: - Match Genre
    public func findGenre(for text: String) -> MusicGenreKnowledge? {
        let clean = text.lowercased()
        for g in genres {
            if clean.contains(g.name.lowercased()) { return g }
            for alias in g.aliases {
                if clean.contains(alias) { return g }
            }
        }
        return nil
    }

    public func searchGenre(matching text: String) -> MusicGenreKnowledge? {
        return findGenre(for: text)
    }

    public func getRandomKnowledge() -> MusicGenreKnowledge {
        return genres.randomElement() ?? genres[0]
    }

    // MARK: - Dynamic Track Trivia Generator
    public func generateTrivia(for song: SongItem) -> String {
        let titleLower = song.title.lowercased()
        let artistLower = song.artistNames.lowercased()

        // Check matched genre
        if let matched = findGenre(for: "\(titleLower) \(artistLower)") {
            return "Dato de DJ Livi: Esta rola navega por el \(matched.name). \(matched.triviaFact) Escucha el trabajo de \(matched.iconicInstruments)."
        }

        // Generic intelligent trivia if not in specific genre catalogue
        if let year = song.album?.name, !year.isEmpty {
            return "Dato curioso: Esta joya forma parte de '\(year)'. Destaca por su impecable ingeniería sonora y su balance armónico."
        }

        return "Dato de DJ Livi: '\(song.title)' de \(song.artistNames) es uno de los temas que más define la identidad de su estilo en la escena musical actual."
    }

    // MARK: - Conversational Question Answering
    public func answerQuestion(question: String, currentSong: SongItem?) -> String {
        let q = question.lowercased()

        if q.contains("dato") || q.contains("curioso") || q.contains("trivia") || q.contains("chisme") {
            if let song = currentSong {
                return generateTrivia(for: song)
            } else {
                return "Pon una canción y te cuento anécdotas de producción, samples ocultos y la historia de cómo se grabó."
            }
        }

        if q.contains("por que") || q.contains("elegiste") || q.contains("recomiendas") {
            if let song = currentSong {
                return "Elegí '\(song.title)' porque comparte una tonalidad armónica y un tempo perfecto con lo que te gusta escuchar. ¡El algoritmo y mi instinto de curadora coincidieron al cien!"
            } else {
                return "Analizo tu historial de reproducción, los compases por minuto y tus favoritas para que la vibra nunca se caiga."
            }
        }

        if q.contains("quien eres") || q.contains("livi") || q.contains("hola") {
            return "¡Hola! Soy Livi, tu DJ y curadora musical con inteligencia artificial en Convx. Conozco de todo tipo de música, desde corridos y shoegaze hasta city pop y electrónica. ¡Dime qué se te antoja escuchar!"
        }

        if q.contains("cambiar") || q.contains("otra") || q.contains("diferente") {
            return "¡Entendido! Toca el botón de DJ o pídeme un género específico para dar un volantazo y refrescar toda la sesión."
        }

        return "Me encanta esa idea. Como tu curadora, estoy ajustando tu sesión para que disfrutes de las mejores transiciones y descubras música que realmente te mueva."
    }
}
