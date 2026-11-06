import Foundation
import AVFoundation
import SwiftUI
import Combine

// MARK: - DJ Voice Quality & Selector
public final class DJVoiceSelector: Sendable {
    public static func resolveBestVoice(preferredLocale: String = "es-MX") -> AVSpeechSynthesisVoice {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        let spanishVoices = allVoices.filter { $0.language.lowercased().hasPrefix("es") }

        let scored = spanishVoices.map { voice -> (voice: AVSpeechSynthesisVoice, score: Int) in
            var score = 0
            if #available(iOS 16.0, *) {
                if voice.quality == .premium {
                    score += 100
                } else if voice.quality == .enhanced {
                    score += 50
                }
            }

            let name = voice.name.lowercased()
            if name.contains("paulina") {
                score += 40
            } else if name.contains("monica") || name.contains("mónica") {
                score += 30
            } else if name.contains("angelica") || name.contains("angélica") {
                score += 25
            }

            if voice.language.caseInsensitiveCompare(preferredLocale) == .orderedSame {
                score += 20
            } else if voice.language.contains("MX") {
                score += 15
            }
            return (voice, score)
        }

        if let best = scored.max(by: { $0.score < $1.score })?.voice {
            return best
        }

        return AVSpeechSynthesisVoice(language: preferredLocale)
            ?? AVSpeechSynthesisVoice(language: "es-MX")
            ?? AVSpeechSynthesisVoice(language: "es-ES")
            ?? AVSpeechSynthesisVoice(language: "es-US")
            ?? AVSpeechSynthesisVoice()
    }
}

// MARK: - DJ Livi Voice Service
@MainActor
public final class DJLiviVoiceService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    public static let shared = DJLiviVoiceService()

    @AppStorage("dj_livi_voice_enabled") public var isVoiceEnabled: Bool = true
    @AppStorage("dj_livi_voice_locale") public var voiceLocale: String = "es-MX"
    @AppStorage("dj_livi_duck_level") public var duckLevel: Double = 0.14

    @Published public private(set) var isSpeaking: Bool = false
    @Published public private(set) var speechAmplitude: Float = 0.0 // 0.0 to 1.0 for visual orb
    @Published public private(set) var activeVoiceName: String = "Resolviendo..."
    @Published public private(set) var currentUtteranceText: String = ""

    private let synthesizer = AVSpeechSynthesizer()
    private var activeVoice: AVSpeechSynthesisVoice?
    private var continuation: CheckedContinuation<Void, Never>?
    private var amplitudeTimer: Timer?
    private var amplitudeTicks: Int = 0

    override private init() {
        super.init()
        self.synthesizer.delegate = self
        self.synthesizer.usesApplicationAudioSession = true
        refreshVoice()
    }

    public func refreshVoice() {
        let voice = DJVoiceSelector.resolveBestVoice(preferredLocale: voiceLocale)
        self.activeVoice = voice
        var qual = "Normal"
        if #available(iOS 16.0, *) {
            if voice.quality == .premium { qual = "★ Premium" }
            else if voice.quality == .enhanced { qual = "⚡ Enhanced" }
        }
        self.activeVoiceName = "\(voice.name) (\(voice.language) • \(qual))"
        print("[DJLiviVoiceService] Vocera asignada: \(self.activeVoiceName)")
    }

    // MARK: - Speech Synthesis with Programmatic Ducking
    public func speak(text: String, rate: Float = 0.525, pitchMultiplier: Float = 1.08) async {
        guard isVoiceEnabled else { return }
        stopSpeakingImmediately()

        currentUtteranceText = text
        startAmplitudeSimulation()

        // 1. Duck background audio smoothly (S-Curve)
        await AudioPlayerService.shared.rampVolume(to: Float(duckLevel), duration: 0.35)

        // 2. Synthesize voice with continuation
        await withCheckedContinuation { cont in
            self.continuation = cont
            self.isSpeaking = true

            let utterance: AVSpeechUtterance
            // Try SSML if iOS 16+
            if #available(iOS 16.0, *), text.hasPrefix("<speak>") {
                if let ssmlUtterance = AVSpeechUtterance(ssmlRepresentation: text) {
                    utterance = ssmlUtterance
                } else {
                    utterance = AVSpeechUtterance(string: stripSSML(text))
                    applyVoiceProfile(to: utterance, rate: rate, pitchMultiplier: pitchMultiplier)
                }
            } else {
                utterance = AVSpeechUtterance(string: stripSSML(text))
                applyVoiceProfile(to: utterance, rate: rate, pitchMultiplier: pitchMultiplier)
            }

            synthesizer.speak(utterance)
        }

        // 3. Restore audio volume smoothly
        await AudioPlayerService.shared.rampVolume(to: 1.0, duration: 0.35)
        stopAmplitudeSimulation()
        currentUtteranceText = ""
    }

    private func applyVoiceProfile(to utterance: AVSpeechUtterance, rate: Float, pitchMultiplier: Float) {
        utterance.voice = self.activeVoice
        utterance.rate = max(0.48, min(0.58, rate))
        utterance.pitchMultiplier = max(0.95, min(1.20, pitchMultiplier))
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0.12
        utterance.postUtteranceDelay = 0.08
    }

    public func stopSpeakingImmediately() {
        if isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
            stopAmplitudeSimulation()
            continuation?.resume()
            continuation = nil
            Task { @MainActor in
                await AudioPlayerService.shared.rampVolume(to: 1.0, duration: 0.20)
            }
        }
    }

    // MARK: - Amplitude Animation Simulator (For 120 FPS Holographic Orb)
    private func startAmplitudeSimulation() {
        amplitudeTicks = 0
        amplitudeTimer?.invalidate()
        amplitudeTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isSpeaking else { return }
                self.amplitudeTicks += 1
                let base = sin(Double(self.amplitudeTicks) * 0.5) * cos(Double(self.amplitudeTicks) * 0.28)
                let noise = Double.random(in: -0.15...0.15)
                let amp = max(0.1, min(1.0, (base + 1.0) / 2.0 + noise))
                self.speechAmplitude = Float(amp)
            }
        }
    }

    private func stopAmplitudeSimulation() {
        amplitudeTimer?.invalidate()
        amplitudeTimer = nil
        speechAmplitude = 0.0
    }

    private func stripSSML(_ raw: String) -> String {
        return raw.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - AVSpeechSynthesizerDelegate
    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.continuation?.resume()
            self.continuation = nil
        }
    }

    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.continuation?.resume()
            self.continuation = nil
        }
    }
}
