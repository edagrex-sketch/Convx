import Foundation
import SwiftUI
import Combine

// MARK: - Generative Sound Capsule Model
public struct SoundCapsule: Identifiable, Codable {
    public let id: String
    public let prompt: String
    public let title: String
    public let aestheticTags: [String]
    public let estimatedBPM: Int
    public let hexPrimary: String
    public let hexSecondary: String
    public let hexAccent: String
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        prompt: String,
        title: String,
        aestheticTags: [String],
        estimatedBPM: Int,
        hexPrimary: String,
        hexSecondary: String,
        hexAccent: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.prompt = prompt
        self.title = title
        self.aestheticTags = aestheticTags
        self.estimatedBPM = estimatedBPM
        self.hexPrimary = hexPrimary
        self.hexSecondary = hexSecondary
        self.hexAccent = hexAccent
        self.createdAt = createdAt
    }

    public var primaryColor: Color { Color(hexString: hexPrimary) }
    public var secondaryColor: Color { Color(hexString: hexSecondary) }
    public var accentColor: Color { Color(hexString: hexAccent) }
}

extension Color {
    init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 240, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Prompt-to-Music Vibe Radio Generator
@MainActor
public final class VibeGeneratorService: ObservableObject {
    public static let shared = VibeGeneratorService()

    @Published public var isGenerating: Bool = false
    @Published public var currentCapsule: SoundCapsule?
    @Published public var savedCapsules: [SoundCapsule] = []

    // Pre-configured inspiration prompts
    public let promptInspirations: [(prompt: String, icon: String, tag: String)] = [
        ("Noche lluviosa en Tokio manejando entre luces de neón", "cloud.rain.fill", "Cyberpunk / Synth"),
        ("Programación en la madrugada, lofi profundo sin voces", "laptopcomputer", "Deep Focus / Lo-Fi"),
        ("Entrenamiento intenso con bass drops demoledores", "flame.fill", "Gym / Hard Electro"),
        ("Tarde de café de domingo con guitarra acústica suave", "cup.and.saucer.fill", "Acoustic / Warm"),
        ("Viaje espacial cinemático con sintetizadores y ambient", "sparkles", "Ambient / Space")
    ]

    private init() {
        loadSavedCapsules()
    }

    // MARK: - Multi-Vector Vibe Decomposition & Generation
    public func generateVibeRadio(prompt: String) async -> [SongItem] {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        isGenerating = true
        defer { isGenerating = false }

        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()

        // 1. Semantic Analysis: Extract mood, genre and aesthetic
        let lower = prompt.lowercased()
        var searchSeed = prompt
        var detectedTags: [String] = []
        var estimatedBPM = 115
        var pColor = "#1A1A3A"
        var sColor = "#00F0FF"
        var aColor = "#FF007F"

        if lower.contains("tokio") || lower.contains("neon") || lower.contains("cyberpunk") || lower.contains("synth") {
            searchSeed = "\(prompt) synthwave darksynth retrowave"
            detectedTags = ["Cyberpunk", "Synthwave", "Retro-Futuristic"]
            estimatedBPM = 88
            pColor = "#0D0A24"
            sColor = "#00F0FF"
            aColor = "#FF0055"
        } else if lower.contains("lofi") || lower.contains("focus") || lower.contains("codigo") || lower.contains("dormir") || lower.contains("madrugada") {
            searchSeed = "\(prompt) lofi chill beats instrumental focus study"
            detectedTags = ["Lo-Fi Beats", "Study Flow", "Instrumental"]
            estimatedBPM = 75
            pColor = "#1C1427"
            sColor = "#A288E3"
            aColor = "#BBD5ED"
        } else if lower.contains("entrenamiento") || lower.contains("gym") || lower.contains("drop") || lower.contains("intenso") || lower.contains("electro") {
            searchSeed = "\(prompt) edm workout bass drop phonk festival"
            detectedTags = ["High Energy", "Bass Drop", "Workout"]
            estimatedBPM = 138
            pColor = "#1A0000"
            sColor = "#FF3B30"
            aColor = "#FF9500"
        } else if lower.contains("cafe") || lower.contains("acustica") || lower.contains("guitarra") || lower.contains("relajante") {
            searchSeed = "\(prompt) acoustic guitar coffee shop indie folk cozy"
            detectedTags = ["Acoustic Folk", "Cozy Coffee", "Warm Strings"]
            estimatedBPM = 92
            pColor = "#26170E"
            sColor = "#D4A373"
            aColor = "#FAEDCD"
        } else {
            searchSeed = "\(prompt) music mix"
            detectedTags = ["Curated Vibe", "Sound Capsule", "Dynamic"]
            pColor = "#121212"
            sColor = "#4ADE80"
            aColor = "#38BDF8"
        }

        // 2. Query InnerTube search API
        let searchResults = (try? await InnerTubeService.shared.search(query: searchSeed)) ?? []
        let resolvedSongs = Array(searchResults.prefix(25))

        // 3. Create Generative Sound Capsule
        let title = generateCapsuleTitle(from: prompt)
        let capsule = SoundCapsule(
            prompt: prompt,
            title: title,
            aestheticTags: detectedTags,
            estimatedBPM: estimatedBPM,
            hexPrimary: pColor,
            hexSecondary: sColor,
            hexAccent: aColor
        )
        self.currentCapsule = capsule
        saveCapsule(capsule)

        if let first = resolvedSongs.first {
            AudioPlayerService.shared.playTrack(first, inQueue: resolvedSongs)
            HUDService.shared.show(
                icon: "sparkles",
                iconColor: capsule.accentColor,
                title: "Vibe Radio Generada",
                subtitle: "\(title) (\(resolvedSongs.count) temas listos)"
            )
        }

        return resolvedSongs
    }

    private func generateCapsuleTitle(from prompt: String) -> String {
        let words = prompt.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        if words.count <= 4 {
            return prompt.capitalized
        }
        return words.prefix(4).joined(separator: " ").capitalized + "..."
    }

    private func saveCapsule(_ capsule: SoundCapsule) {
        if !savedCapsules.contains(where: { $0.id == capsule.id }) {
            savedCapsules.insert(capsule, at: 0)
            if savedCapsules.count > 20 { savedCapsules.removeLast() }
            if let data = try? JSONEncoder().encode(savedCapsules) {
                UserDefaults.standard.set(data, forKey: "convx_sound_capsules")
            }
        }
    }

    private func loadSavedCapsules() {
        if let data = UserDefaults.standard.data(forKey: "convx_sound_capsules"),
           let list = try? JSONDecoder().decode([SoundCapsule].self, from: data) {
            self.savedCapsules = list
        }
    }
}
