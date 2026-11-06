import SwiftUI
import Combine

// MARK: - Visualizer Styles
public enum VisualizerStyle: String, CaseIterable, Identifiable, Codable {
    case liquidSphere = "Esfera Líquida visionOS"
    case quantumSpectrum = "Espectro Cuántico 120 FPS"
    case particleVortex = "Vórtice de Partículas"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .liquidSphere:     return "circle.hexagongrid.fill"
        case .quantumSpectrum:  return "waveform.path.ecg"
        case .particleVortex:   return "atom"
        }
    }
}

// MARK: - 120 FPS Real-Time Audio Reactive Visualizer View
public struct VisualizerView: View {
    @ObservedObject var dsp = AudiophileDSPService.shared
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var player = AudioPlayerService.shared

    @AppStorage("selected_visualizer_style") public var selectedStyle: VisualizerStyle = .liquidSphere
    @State private var rotationAngle: Double = 0.0
    @State private var dragOffset: CGSize = .zero

    public init() {}

    public var body: some View {
        ZStack {
            // Background Ambient Glow
            RadialGradient(
                colors: [
                    theme.activeAccentColor.opacity(Double(dsp.overallEnergy * 0.35)),
                    Color.clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 180
            )
            .allowsHitTesting(false)

            // Dynamic Visualizer Core
            Group {
                switch selectedStyle {
                case .liquidSphere:
                    LiquidEnergySphere(
                        subBass: dsp.subBassLevel,
                        midEnergy: dsp.midLevel,
                        overall: dsp.overallEnergy,
                        accentColor: theme.activeAccentColor
                    )
                case .quantumSpectrum:
                    QuantumSpectrumRibbon(
                        bands: [dsp.subBassLevel, dsp.bassLevel, dsp.lowMidLevel, dsp.midLevel, dsp.highMidLevel, dsp.brillianceLevel],
                        accentColor: theme.activeAccentColor
                    )
                case .particleVortex:
                    CosmicParticleVortex(
                        energy: dsp.overallEnergy,
                        subBass: dsp.subBassLevel,
                        accentColor: theme.activeAccentColor
                    )
                }
            }
            .rotationEffect(.degrees(rotationAngle))
            .offset(dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { val in
                        dragOffset = CGSize(width: val.translation.width * 0.25, height: val.translation.height * 0.25)
                        rotationAngle = Double(val.translation.width * 0.1)
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
                            dragOffset = .zero
                            rotationAngle = 0
                        }
                    }
            )
            .onTapGesture(count: 2) {
                // Cycle visualizer style on double tap
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    let all = VisualizerStyle.allCases
                    if let idx = all.firstIndex(of: selectedStyle) {
                        let nextIdx = (idx + 1) % all.count
                        selectedStyle = all[nextIdx]
                    }
                }
            }

            // Top-Right Style Switcher Pill
            VStack {
                HStack {
                    Spacer()
                    Menu {
                        ForEach(VisualizerStyle.allCases) { style in
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation { selectedStyle = style }
                            }) {
                                HStack {
                                    Label(style.rawValue, systemImage: style.icon)
                                    if selectedStyle == style {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: selectedStyle.icon)
                                .font(.system(size: 11, weight: .bold))
                            Text(selectedStyle.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                        )
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 4)
                }
                Spacer()
            }
        }
        .frame(height: 260)
    }
}

// MARK: - 1. Liquid Energy Sphere (visionOS Raymarched Style)
struct LiquidEnergySphere: View {
    let subBass: Float
    let midEnergy: Float
    let overall: Float
    let accentColor: Color

    @State private var phase: Double = 0.0

    var body: some View {
        TimelineView(.animation) { timeline in
            let date = timeline.date.timeIntervalSinceReferenceDate
            let bassScale = 1.0 + CGFloat(subBass) * 0.22
            let pulseOpacity = 0.65 + Double(overall) * 0.35

            ZStack {
                // Outer Fresnel Aura
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                accentColor.opacity(0.5 * pulseOpacity),
                                accentColor.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 50,
                            endRadius: 135
                        )
                    )
                    .frame(width: 250, height: 250)
                    .scaleEffect(bassScale)

                // Internal Liquid Membrane Rings
                ForEach(0..<4) { i in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    accentColor.opacity(0.8 - Double(i) * 0.15),
                                    Color.white.opacity(0.6),
                                    accentColor.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: CGFloat(2.0 + Float(i) * 0.5 + subBass * 2.0)
                        )
                        .frame(width: CGFloat(150 - i * 28), height: CGFloat(150 - i * 28))
                        .scaleEffect(1.0 + CGFloat(sin(date * 3.5 + Double(i) * 1.2)) * 0.08 * CGFloat(midEnergy + 0.2))
                        .rotationEffect(.degrees(date * (25.0 + Double(i) * 15.0)))
                }

                // Core Caustic Reflection
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [
                                accentColor,
                                Color.white.opacity(0.9),
                                Color.cyan,
                                accentColor
                            ],
                            center: .center,
                            angle: .degrees(date * 50)
                        )
                    )
                    .frame(width: 80, height: 80)
                    .blur(radius: 20)
                    .opacity(0.7 + Double(subBass) * 0.3)
            }
        }
    }
}

// MARK: - 2. Quantum Spectrum Ribbon
struct QuantumSpectrumRibbon: View {
    let bands: [Float]
    let accentColor: Color

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 14) {
                ForEach(0..<bands.count, id: \.self) { idx in
                    let val = bands[idx]
                    let barHeight = max(18.0, CGFloat(val) * 170.0 + CGFloat(sin(time * 4.0 + Double(idx))) * 10.0)

                    VStack {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        accentColor,
                                        Color.white.opacity(0.85),
                                        accentColor.opacity(0.4)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 14, height: barHeight)
                            .shadow(color: accentColor.opacity(0.65), radius: 8, x: 0, y: 0)
                    }
                }
            }
            .frame(height: 220)
        }
    }
}

// MARK: - 3. Cosmic Particle Vortex
struct CosmicParticleVortex: View {
    let energy: Float
    let subBass: Float
    let accentColor: Color

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let particleCount = 28

            ZStack {
                ForEach(0..<particleCount, id: \.self) { i in
                    let angle = (Double(i) / Double(particleCount)) * 2.0 * .pi + (time * 0.8)
                    let radius = 65.0 + Double(sin(time * 2.5 + Double(i))) * 35.0 * Double(energy + 0.3) + Double(subBass) * 30.0
                    let x = cos(angle) * radius
                    let y = sin(angle) * radius
                    let pSize = max(3.0, 7.0 + Double(sin(Double(i) + time * 3.0)) * 3.0)

                    Circle()
                        .fill(
                            (i % 3 == 0) ? Color.white : accentColor
                        )
                        .frame(width: CGFloat(pSize), height: CGFloat(pSize))
                        .offset(x: CGFloat(x), y: CGFloat(y))
                        .shadow(color: accentColor, radius: 4)
                }

                // Center Pulse
                Circle()
                    .fill(accentColor.opacity(0.35 + Double(subBass) * 0.5))
                    .frame(width: 48, height: 48)
                    .blur(radius: 12)
                    .scaleEffect(1.0 + CGFloat(subBass) * 0.4)
            }
        }
    }
}
