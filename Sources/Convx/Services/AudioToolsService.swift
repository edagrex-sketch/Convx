import Foundation
import Combine
import SwiftUI

// MARK: - Sleep Timer Options
public enum SleepTimerOption: String, CaseIterable, Identifiable, Codable {
    case off = "Off"
    case min15 = "15 min"
    case min30 = "30 min"
    case min45 = "45 min"
    case hour1 = "1 hour"
    case endOfSong = "End of Song"

    public var id: String { rawValue }

    public var durationSeconds: TimeInterval? {
        switch self {
        case .off:        return nil
        case .min15:      return 15 * 60
        case .min30:      return 30 * 60
        case .min45:      return 45 * 60
        case .hour1:      return 60 * 60
        case .endOfSong:  return nil
        }
    }
}

// MARK: - Sleep Timer Service with Gradual Fade-Out
@MainActor
public final class SleepTimerService: ObservableObject {
    public static let shared = SleepTimerService()

    @Published public var currentOption: SleepTimerOption = .off
    @Published public var remainingSeconds: TimeInterval = 0
    @Published public var isActive: Bool = false

    @AppStorage("playbackSpeed") public var selectedSpeed: PlaybackSpeed = .normal
    @AppStorage("equalizerPreset") public var selectedPreset: EqualizerPreset = .flat

    private var timerSubscription: AnyCancellable?
    private let fadeOutThreshold: TimeInterval = 30.0

    private init() {}

    public func setSpeed(_ speed: PlaybackSpeed) {
        selectedSpeed = speed
        AudioPlayerService.shared.applyPlaybackRate(speed.rate)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    public func setPreset(_ preset: EqualizerPreset) {
        selectedPreset = preset
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    public func setTimer(to option: SleepTimerOption) {
        currentOption = option
        timerSubscription?.cancel()
        timerSubscription = nil

        guard option != .off else {
            isActive = false
            remainingSeconds = 0
            AudioPlayerService.shared.setVolume(1.0)
            return
        }

        if option == .endOfSong {
            isActive = true
            remainingSeconds = 0
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            return
        }

        if let seconds = option.durationSeconds {
            isActive = true
            remainingSeconds = seconds
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

            timerSubscription = Timer.publish(every: 1.0, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    self?.tick()
                }
        }
    }

    private func tick() {
        guard remainingSeconds > 0 else {
            finishTimer()
            return
        }

        remainingSeconds -= 1

        // Smooth Exponential Volume Fade in the final 30 seconds
        if remainingSeconds <= fadeOutThreshold {
            let volumeFraction = Float(remainingSeconds / fadeOutThreshold)
            AudioPlayerService.shared.setVolume(max(0.0, volumeFraction))
        }
    }

    public func handleTrackEndNatural() {
        if currentOption == .endOfSong && isActive {
            print("[SleepTimer] Reached end of track. Halting playback...")
            finishTimer()
        }
    }

    private func finishTimer() {
        timerSubscription?.cancel()
        timerSubscription = nil
        isActive = false
        currentOption = .off
        remainingSeconds = 0

        AudioPlayerService.shared.pause()
        AudioPlayerService.shared.setVolume(1.0)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    public var formattedRemainingTime: String {
        guard isActive else { return "" }
        if currentOption == .endOfSong { return "At track end" }
        let mins = Int(remainingSeconds) / 60
        let secs = Int(remainingSeconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Playback Speed Options
public enum PlaybackSpeed: String, CaseIterable, Identifiable, Codable {
    case slow = "0.8x"
    case normal = "1.0x"
    case fast = "1.25x"
    case double = "1.5x"

    public var id: String { rawValue }
    public var label: String { rawValue }

    public var rate: Float {
        switch self {
        case .slow: return 0.8
        case .normal: return 1.0
        case .fast: return 1.25
        case .double: return 1.5
        }
    }
}

// MARK: - Equalizer Presets
public enum EqualizerPreset: String, CaseIterable, Identifiable, Codable {
    case flat = "Flat / Studio"
    case bassBoost = "Bass Boost"
    case vocalBooster = "Vocal Booster"
    case acoustic = "Acoustic"
    case trebleClarity = "Treble Clarity"
    case electronicEDM = "Electronic EDM"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .flat:            return "slider.vertical.3"
        case .bassBoost:       return "speaker.wave.3.fill"
        case .vocalBooster:    return "mic.fill"
        case .acoustic:        return "guitars.fill"
        case .trebleClarity:   return "sparkles"
        case .electronicEDM:   return "bolt.fill"
        }
    }

    public var description: String {
        switch self {
        case .flat:          return "Uncolored studio reference response"
        case .bassBoost:     return "Deep punchy sub-bass & warmth"
        case .vocalBooster:  return "Enhanced vocal presence and clarity"
        case .acoustic:      return "Warm natural mids with string shimmer"
        case .trebleClarity: return "Enhanced upper harmonics and crisp highs"
        case .electronicEDM: return "Aggressive club V-curve with heavy kick"
        }
    }
}
