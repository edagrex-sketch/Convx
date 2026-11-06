import Foundation
import SwiftUI
import Combine

// MARK: - Sing-Along / Karaoke Modes
public enum SingAlongVocalMode: String, CaseIterable, Identifiable, Codable {
    case karaoke = "Karaoke Puro"
    case duet = "Dúo / Práctica"
    case vocalLead = "Vocal Lead (+3dB)"
    case original = "Original"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .karaoke:    return "mic.slash.fill"
        case .duet:       return "person.2.wave.2.fill"
        case .vocalLead:  return "mic.badge.plus"
        case .original:   return "music.note"
        }
    }

    public var targetVocalLevel: Double {
        switch self {
        case .karaoke:   return 0.05
        case .duet:      return 0.45
        case .vocalLead: return 1.35
        case .original:  return 1.0
        }
    }
}

// MARK: - Universal Sing-Along Service
@MainActor
public final class SingAlongService: ObservableObject {
    public static let shared = SingAlongService()

    @AppStorage("sing_along_enabled") public var isSingAlongEnabled: Bool = false
    @Published public var vocalVolume: Double = 0.05 // 0.0 (silent vocal) to 1.0 (full original)
    @Published public var pitchSemitones: Int = 0    // -6 to +6 semitones
    @Published public var reverbAmbience: Double = 0.35 // 0.0 to 1.0
    @Published public var selectedMode: SingAlongVocalMode = .karaoke
    @Published public var isSheetPresented: Bool = false

    private init() {}

    public func toggleSingAlong() {
        isSingAlongEnabled.toggle()
        if isSingAlongEnabled {
            applyMode(.karaoke)
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            HUDService.shared.show(
                icon: "mic.fill",
                iconColor: .pink,
                title: "Modo Sing-Along Activado",
                subtitle: "Voz atenuada en tiempo real con graves intactos"
            )
        } else {
            vocalVolume = 1.0
            pitchSemitones = 0
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            HUDService.shared.show(
                icon: "music.note",
                iconColor: .cyan,
                title: "Voz Original Restaurada",
                subtitle: "Modo estéreo original activo"
            )
        }
    }

    public func applyMode(_ mode: SingAlongVocalMode) {
        selectedMode = mode
        vocalVolume = mode.targetVocalLevel
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    public func incrementPitch() {
        guard pitchSemitones < 6 else { return }
        pitchSemitones += 1
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    public func decrementPitch() {
        guard pitchSemitones > -6 else { return }
        pitchSemitones -= 1
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    public func resetPitch() {
        pitchSemitones = 0
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    public var formattedPitch: String {
        if pitchSemitones == 0 {
            return "Tono Original"
        } else if pitchSemitones > 0 {
            return "+\(pitchSemitones) Semitonos"
        } else {
            return "\(pitchSemitones) Semitonos"
        }
    }
}
