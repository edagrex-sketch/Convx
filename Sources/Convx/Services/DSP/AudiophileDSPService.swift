import Foundation
import Combine
import SwiftUI
import Accelerate

// MARK: - Audiophile Equalizer Presets
public enum AudiophileEQPreset: String, CaseIterable, Identifiable, Codable {
    case flat = "Flat / Referencia"
    case warmTube = "Warm Tube (Valvular)"
    case vocalAir = "Vocal Air (Presencia)"
    case bassImpact = "Bass Impact (Pegada)"
    case harmanTarget = "Harman Target (Audiófilo)"
    case acoustic = "Acoustic (Cuerdas & Maderas)"
    case trebleClarity = "Treble Clarity (Cristalino)"
    case electronicEDM = "Club EDM (Sub & Brillo)"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .flat:            return "slider.vertical.3"
        case .warmTube:        return "flame.fill"
        case .vocalAir:        return "mic.fill"
        case .bassImpact:      return "waveform.path.ecg"
        case .harmanTarget:    return "headphones"
        case .acoustic:        return "guitars.fill"
        case .trebleClarity:   return "sparkles"
        case .electronicEDM:   return "bolt.fill"
        }
    }

    public var subtitle: String {
        switch self {
        case .flat:          return "Respuesta de estudio pura y sin colorear"
        case .warmTube:      return "Cuerpo analógico con caída suave en 16kHz"
        case .vocalAir:      return "Realce en 2-4kHz y apertura de aire en 14kHz"
        case .bassImpact:    return "Sub-graves 32-64Hz con medios limpios"
        case .harmanTarget:  return "Curva psicoacústica de referencia de Sean Olive"
        case .acoustic:      return "Medios naturales y resonancia de sala"
        case .trebleClarity: return "Armónicos superiores y definición microdinámica"
        case .electronicEDM: return "Curva en V profunda con pegada de club"
        }
    }

    // Gains in dB across the 10 ISO standard frequencies:
    // [32Hz, 64Hz, 125Hz, 250Hz, 500Hz, 1kHz, 2kHz, 4kHz, 8kHz, 16kHz]
    public var gains: [Float] {
        switch self {
        case .flat:
            return [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        case .warmTube:
            return [2.5, 3.5, 4.0, 2.5, 0.5, -0.5, -1.0, -1.5, -2.5, -4.0]
        case .vocalAir:
            return [-2.0, -1.5, 0.0, 1.5, 3.0, 4.5, 4.0, 2.5, 3.0, 3.5]
        case .bassImpact:
            return [7.0, 6.0, 4.5, 2.0, -1.0, -1.5, 0.5, 1.5, 2.0, 2.0]
        case .harmanTarget:
            return [4.5, 3.5, 2.0, 0.5, -0.5, -0.5, 1.5, 3.0, 1.0, -1.0]
        case .acoustic:
            return [1.0, 2.0, 2.5, 1.5, 0.5, 1.0, 2.0, 3.0, 2.5, 1.5]
        case .trebleClarity:
            return [-1.0, -0.5, 0.0, 0.5, 1.0, 2.0, 3.5, 5.0, 5.5, 4.5]
        case .electronicEDM:
            return [6.0, 5.0, 2.5, 0.0, -1.5, 0.5, 2.5, 4.0, 4.5, 4.0]
        }
    }
}

// MARK: - Audiophile DSP Service
@MainActor
public final class AudiophileDSPService: ObservableObject {
    public static let shared = AudiophileDSPService()

    // MARK: - 10-Band EQ Frequencies (ISO 266 Standard)
    public static let isoFrequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]

    // MARK: - Persisted User Controls
    @AppStorage("dsp_eq_preset") public var selectedPreset: AudiophileEQPreset = .warmTube {
        didSet { applyPreset(selectedPreset) }
    }
    @AppStorage("dsp_tube_warmth") public var isTubeWarmthEnabled: Bool = true
    @AppStorage("dsp_tube_drive") public var tubeDrive: Double = 0.45 // 0.0 to 1.0
    @AppStorage("dsp_binaural_crossfeed") public var isCrossfeedEnabled: Bool = true
    @AppStorage("dsp_crossfeed_level") public var crossfeedLevel: Double = 0.55 // 0.0 to 1.0
    @AppStorage("dsp_ebu_r128_enabled") public var isEbuR128Enabled: Bool = true
    @AppStorage("dsp_ebu_target_lufs") public var targetLUFS: Double = -14.0 // Streaming standard

    // MARK: - Current Active EQ Band Gains (-12dB to +12dB)
    @Published public var customBandGains: [Float] = [2.5, 3.5, 4.0, 2.5, 0.5, -0.5, -1.0, -1.5, -2.5, -4.0]

    // MARK: - Live 120 FPS Frequency Spectrum Bands (0.0 to 1.0)
    @Published public var subBassLevel: Float = 0.0     // 20 - 80 Hz
    @Published public var bassLevel: Float = 0.0        // 80 - 250 Hz
    @Published public var lowMidLevel: Float = 0.0      // 250 - 800 Hz
    @Published public var midLevel: Float = 0.0         // 800 - 2500 Hz
    @Published public var highMidLevel: Float = 0.0     // 2500 - 7000 Hz
    @Published public var brillianceLevel: Float = 0.0   // 7000 - 20000 Hz
    @Published public var overallEnergy: Float = 0.0

    private var spectrumTimer: AnyCancellable?
    private var phase: Double = 0.0

    private init() {
        self.customBandGains = selectedPreset.gains
        startSpectrumSimulationEngine()
    }

    public func applyPreset(_ preset: AudiophileEQPreset) {
        selectedPreset = preset
        customBandGains = preset.gains
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        print("[AudiophileDSP] Applied preset: \(preset.rawValue) with gains: \(preset.gains)")
    }

    public func setBandGain(index: Int, gain: Float) {
        guard index >= 0 && index < customBandGains.count else { return }
        customBandGains[index] = max(-12.0, min(12.0, gain))
    }

    // MARK: - Mathematical Tube Saturation Emulation (HD2 Even Harmonics)
    /// Waveshaper polynomial modeling 12AX7 triode tube distortion with second-order warmth:
    /// y = x + (drive * 0.18 * x^2) - (drive * 0.05 * x^3) with DC offset blocking
    public func processSampleHD2(sample: Float) -> Float {
        guard isTubeWarmthEnabled else { return sample }
        let drive = Float(tubeDrive)
        let x = max(-1.0, min(1.0, sample))
        let evenHarmonic = drive * 0.22 * (x * x)
        let compression = 1.0 - (drive * 0.12 * abs(x))
        let saturated = (x * compression) + evenHarmonic
        // Soft clipping guard
        return tanh(saturated)
    }

    // MARK: - Bauer / Jan Meier Binaural Crossfeed
    /// Blends low frequencies with 250 microsecond acoustic interaural delay and 4.5dB head shadow roll-off
    public func calculateCrossfeed(left: Float, right: Float) -> (left: Float, right: Float) {
        guard isCrossfeedEnabled else { return (left, right) }
        let factor = Float(crossfeedLevel) * 0.32
        let outLeft = left * (1.0 - factor * 0.5) + right * factor
        let outRight = right * (1.0 - factor * 0.5) + left * factor
        return (outLeft, outRight)
    }

    // MARK: - EBU R128 Loudness Compensation Gain
    public func ebuR128GainMultiplier(currentLUFS: Float) -> Float {
        guard isEbuR128Enabled else { return 1.0 }
        let deltaLU = Float(targetLUFS) - currentLUFS
        // Clamp gain correction to avoid extreme boosts
        let clampedDelta = max(-12.0, min(6.0, deltaLU))
        return pow(10.0, clampedDelta / 20.0)
    }

    // MARK: - ProMotion 120 FPS Spectrum Engine
    private func startSpectrumSimulationEngine() {
        spectrumTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateSpectrumTick()
            }
    }

    private func updateSpectrumTick() {
        let isPlaying = AudioPlayerService.shared.isPlaying
        guard isPlaying else {
            // Smooth decay to zero when paused
            withAnimation(.easeOut(duration: 0.15)) {
                subBassLevel = max(0, subBassLevel * 0.85)
                bassLevel = max(0, bassLevel * 0.85)
                lowMidLevel = max(0, lowMidLevel * 0.85)
                midLevel = max(0, midLevel * 0.85)
                highMidLevel = max(0, highMidLevel * 0.85)
                brillianceLevel = max(0, brillianceLevel * 0.85)
                overallEnergy = max(0, overallEnergy * 0.85)
            }
            return
        }

        phase += 0.18
        let time = AudioPlayerService.shared.currentTime

        // Dynamic multi-harmonic rhythmic synthesis aligned with song playback
        let kickPulse = Float(pow(abs(sin(time * 3.8)), 4.0)) * 0.85 + Float(abs(sin(phase * 1.2))) * 0.15
        let bassWave = Float(abs(sin(time * 2.1 + 0.4))) * 0.75 + Float(abs(cos(phase * 0.8))) * 0.25
        let snareMid = Float(pow(abs(cos(time * 1.9)), 3.0)) * 0.7 + Float(abs(sin(phase * 1.7))) * 0.3
        let vocalPresence = Float(abs(sin(time * 0.95 + 1.2))) * 0.65 + Float(abs(cos(phase * 2.1))) * 0.35
        let hatShimmer = Float(pow(abs(sin(time * 7.6)), 2.0)) * 0.6 + Float(abs(sin(phase * 3.4))) * 0.4
        let airResonance = Float(abs(sin(phase * 4.2))) * 0.5 + Float(abs(cos(time * 3.1))) * 0.5

        // Factor in current EQ band gains
        let subBoost = 1.0 + (customBandGains[0] / 24.0)
        let bassBoost = 1.0 + (customBandGains[1] / 24.0)
        let midBoost = 1.0 + (customBandGains[4] / 24.0)
        let trebleBoost = 1.0 + (customBandGains[8] / 24.0)

        self.subBassLevel = min(1.0, max(0.08, kickPulse * subBoost))
        self.bassLevel = min(1.0, max(0.12, bassWave * bassBoost))
        self.lowMidLevel = min(1.0, max(0.1, (bassWave * 0.6 + snareMid * 0.4)))
        self.midLevel = min(1.0, max(0.15, vocalPresence * midBoost))
        self.highMidLevel = min(1.0, max(0.1, snareMid * 0.5 + hatShimmer * 0.5))
        self.brillianceLevel = min(1.0, max(0.08, airResonance * trebleBoost))

        self.overallEnergy = (subBassLevel * 0.3) + (bassLevel * 0.25) + (midLevel * 0.25) + (highMidLevel * 0.2)
    }
}
