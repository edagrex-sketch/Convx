import Foundation
import SwiftUI
import Combine

// MARK: - DJ Transition Styles
public enum DJTransitionStyle: String, CaseIterable, Identifiable, Codable {
    case dropAndBassSwap = "The Drop & Bass Swap"
    case ambientReverbFreeze = "Ambient Reverb Freeze"
    case harmonicCrossfade = "Mezcla Armónica Camelot"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .dropAndBassSwap:      return "waveform.path.badge.plus"
        case .ambientReverbFreeze:  return "aqi.low"
        case .harmonicCrossfade:    return "circle.grid.cross.fill"
        }
    }

    public var explanation: String {
        switch self {
        case .dropAndBassSwap:
            return "Barrido de filtro paso-alto en los últimos 4 compases y drop con pegada instantánea"
        case .ambientReverbFreeze:
            return "Congela el último acorde en un colchón estéreo infinito al cambiar de género"
        case .harmonicCrossfade:
            return "Fundido cruzado de potencia constante alineado a la rueda de Camelot"
        }
    }
}

// MARK: - Smart DJ Engine Service
@MainActor
public final class DJEngineService: ObservableObject {
    public static let shared = DJEngineService()

    @AppStorage("dj_smart_enabled") public var isSmartDJEnabled: Bool = true
    @AppStorage("dj_transition_style") public var selectedStyle: DJTransitionStyle = .dropAndBassSwap
    @AppStorage("dj_transition_duration") public var transitionDuration: Double = 5.5 // Seconds
    @AppStorage("dj_haptic_drops") public var hapticDropsEnabled: Bool = true

    // Active Transition Real-Time State
    @Published public var isTransitionActive: Bool = false
    @Published public var transitionProgress: Double = 0.0 // 0.0 to 1.0
    @Published public var highPassCutoffHz: Double = 20.0  // Sweeps from 20Hz to 850Hz

    // Camelot key cache
    private var bpmCache: [String: Int] = [:]
    private var camelotCache: [String: String] = [:]

    private init() {}

    // MARK: - BPM & Key Estimation
    public func estimateBPM(for song: SongItem) -> Int {
        if let cached = bpmCache[song.id] { return cached }
        // Algorithmic deterministic tempo hash from title/artist/duration
        let seed = abs(song.id.hashValue ^ (song.title.count * 17))
        let commonBPMs = [78, 85, 92, 98, 105, 112, 118, 124, 126, 128, 132, 140, 150]
        let bpm = commonBPMs[seed % commonBPMs.count]
        bpmCache[song.id] = bpm
        return bpm
    }

    public func estimateCamelotKey(for song: SongItem) -> String {
        if let cached = camelotCache[song.id] { return cached }
        let camelotWheel = ["1A", "1B", "2A", "2B", "3A", "3B", "4A", "4B", "5A", "5B", "6A", "6B", "7A", "7B", "8A", "8B", "9A", "9B", "10A", "10B", "11A", "11B", "12A", "12B"]
        let seed = abs(song.title.hashValue ^ (song.artistNames.count * 23))
        let key = camelotWheel[seed % camelotWheel.count]
        camelotCache[song.id] = key
        return key
    }

    public func harmonicMatchQuality(outgoing: SongItem, incoming: SongItem) -> (label: String, tint: Color) {
        let keyA = estimateCamelotKey(for: outgoing)
        let keyB = estimateCamelotKey(for: incoming)
        if keyA == keyB {
            return ("Armonía Perfecta (Misma Tónica)", .green)
        }
        // Extract numeric part
        let numA = Int(keyA.filter { $0.isNumber }) ?? 1
        let numB = Int(keyB.filter { $0.isNumber }) ?? 1
        let diff = abs(numA - numB)
        if diff == 1 || diff == 11 {
            return ("Flujo Armónico Natural (+1 Camelot)", .cyan)
        } else if diff == 2 || diff == 10 {
            return ("Impulso de Energía (+2 Camelot)", .orange)
        } else {
            return ("Contraste Dinámico", .purple)
        }
    }

    // MARK: - Transition Trigger Logic (Called by AudioPlayerService periodic observer)
    public func checkTransition(currentTime: Double, duration: Double) {
        guard isSmartDJEnabled, duration > transitionDuration else { return }
        let remaining = duration - currentTime

        if remaining <= transitionDuration && remaining > 0.15 {
            if !isTransitionActive {
                isTransitionActive = true
                print("[DJEngineService] 🚀 Starting Smart DJ Transition (\(selectedStyle.rawValue)) with \(remaining)s left...")
            }
            let progress = 1.0 - (remaining / transitionDuration)
            self.transitionProgress = min(1.0, max(0.0, progress))

            switch selectedStyle {
            case .dropAndBassSwap:
                // High-pass filter exponential sweep removing sub-bass before the drop
                let sweep = pow(progress, 2.2)
                self.highPassCutoffHz = 20.0 + (sweep * 830.0) // 20Hz -> 850Hz
            case .ambientReverbFreeze:
                self.highPassCutoffHz = 20.0 + (progress * 400.0)
            case .harmonicCrossfade:
                self.highPassCutoffHz = 20.0
            }
        } else if remaining <= 0.15 && isTransitionActive {
            // Trigger the downbeat drop
            triggerDropHaptics()
            resetTransition()
        } else if remaining > transitionDuration && isTransitionActive {
            resetTransition()
        }
    }

    public func triggerDropHaptics() {
        guard hapticDropsEnabled else { return }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    public func resetTransition() {
        self.isTransitionActive = false
        self.transitionProgress = 0.0
        self.highPassCutoffHz = 20.0
    }
}
