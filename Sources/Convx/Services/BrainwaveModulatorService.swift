import Foundation
import SwiftUI
import Combine

// MARK: - Brainwave Frequency Bands
public enum BrainwaveBand: String, CaseIterable, Identifiable, Codable {
    case off = "Desactivado"
    case alpha = "Alfa (10 Hz) - Enfoque & Flow"
    case theta = "Theta (6 Hz) - Relajación & Meditación"
    case delta = "Delta (2 Hz) - Sueño Reparador"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .off:   return "waveform.slash"
        case .alpha: return "brain.head.profile"
        case .theta: return "moon.fill"
        case .delta: return "bed.double.fill"
        }
    }

    public var beatFrequencyHz: Double {
        switch self {
        case .off:   return 0.0
        case .alpha: return 10.0
        case .theta: return 6.0
        case .delta: return 2.0
        }
    }

    public var description: String {
        switch self {
        case .off:
            return "Audio estéreo estándar sin modulación neuroacústica"
        case .alpha:
            return "Sincroniza ondas parietales para programación y lectura prolongada sin fatiga"
        case .theta:
            return "Induce estados de calma profunda, introspección y reducción de cortisol"
        case .delta:
            return "Estimula el sueño de ondas lentas y la regeneración celular física"
        }
    }
}

// MARK: - Neuroacoustic Brainwave Modulator Service
@MainActor
public final class BrainwaveModulatorService: ObservableObject {
    public static let shared = BrainwaveModulatorService()

    @AppStorage("neuro_brainwave_band") public var selectedBand: BrainwaveBand = .off {
        didSet { updateModulationState() }
    }
    @AppStorage("neuro_brainwave_volume") public var volume: Double = 0.35 // 0.0 to 1.0
    @AppStorage("neuro_dynamic_ducking") public var isDuckingEnabled: Bool = true

    @Published public var currentCarrierHz: Double = 110.0 // Hz (Subharmonic root note A2)
    @Published public var isSynthesizing: Bool = false

    private init() {
        updateModulationState()
    }

    public func setBand(_ band: BrainwaveBand) {
        selectedBand = band
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if band != .off {
            HUDService.shared.show(
                icon: band.icon,
                iconColor: Color.indigo,
                title: "Modulador Neuroacústico",
                subtitle: band.rawValue
            )
        }
    }

    private func updateModulationState() {
        self.isSynthesizing = (selectedBand != .off)
        if isSynthesizing {
            adaptCarrierToCurrentSong()
        }
    }

    /// Dynamically tunes the subharmonic carrier frequency to the root key of the current song
    public func adaptCarrierToCurrentSong() {
        guard let song = AudioPlayerService.shared.currentTrack else {
            currentCarrierHz = 110.0 // A2 reference
            return
        }
        let camelot = DJEngineService.shared.estimateCamelotKey(for: song)
        // Harmonize with fundamental musical note (A2 = 110Hz, C2 = 130.8Hz, D2 = 146.8Hz, E2 = 164.8Hz)
        switch camelot.prefix(2) {
        case "8A", "8B": currentCarrierHz = 110.0 // A
        case "5A", "5B": currentCarrierHz = 130.8 // C
        case "7A", "7B": currentCarrierHz = 146.8 // D
        case "9A", "9B": currentCarrierHz = 164.8 // E
        case "6A", "6B": currentCarrierHz = 123.4 // B
        case "10", "11": currentCarrierHz = 174.6 // F / F#
        default:         currentCarrierHz = 110.0
        }
        print("[BrainwaveModulator] Harmonized carrier frequency to \(currentCarrierHz)Hz for Camelot key \(camelot)")
    }
}
