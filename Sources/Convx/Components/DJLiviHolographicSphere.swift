import SwiftUI

public struct DJLiviHolographicSphere: View {
    @ObservedObject var livi = DJLiviService.shared
    @ObservedObject var voice = DJLiviVoiceService.shared
    @ObservedObject var player = AudioPlayerService.shared
    @ObservedObject var theme = ThemeManager.shared

    let diameter: CGFloat
    let showDynamicPill: Bool

    @State private var phase: Double = 0.0
    @State private var innerRotation: Double = 0.0

    public init(diameter: CGFloat = 240, showDynamicPill: Bool = true) {
        self.diameter = diameter
        self.showDynamicPill = showDynamicPill
    }

    private var primaryAuraColor: Color {
        switch livi.currentState {
        case .speaking:
            return Color(red: 1.0, green: 0.15, blue: 0.65) // Magenta vocal cálido
        case .listening:
            return Color(red: 1.0, green: 0.65, blue: 0.10) // Ámbar de escucha activa
        case .analyzing:
            return Color(red: 0.70, green: 0.30, blue: 1.00) // Púrpura de pensamiento
        case .playing, .idle:
            return theme.activeAccentColor // Cian neón / Tema Convx
        }
    }

    private var secondaryAuraColor: Color {
        switch livi.currentState {
        case .speaking:
            return Color(red: 0.45, green: 0.20, blue: 0.95)
        case .listening:
            return Color(red: 1.0, green: 0.25, blue: 0.40)
        case .analyzing:
            return Color(red: 0.00, green: 0.94, blue: 1.00)
        case .playing, .idle:
            return Color(red: 0.25, green: 0.10, blue: 0.85)
        }
    }

    private var amplitudeScale: CGFloat {
        if voice.isSpeaking {
            return 1.0 + CGFloat(voice.speechAmplitude) * 0.16
        } else if player.isPlaying {
            return 1.02
        } else {
            return 0.98
        }
    }

    public var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // 1. Halo de Brillo Difuso Trasero (Back Glow)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [primaryAuraColor.opacity(voice.isSpeaking ? 0.85 : 0.45), .clear],
                            center: .center,
                            startRadius: diameter * 0.1,
                            endRadius: diameter * 0.85
                        )
                    )
                    .frame(width: diameter * 1.5, height: diameter * 1.5)
                    .blur(radius: 36)
                    .scaleEffect(amplitudeScale)
                    .animation(.easeInOut(duration: 0.4), value: voice.isSpeaking)

                // 2. Anillos de Resonancia Vocal / Beat
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [primaryAuraColor.opacity(0.6), secondaryAuraColor.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                        .frame(width: diameter * (1.08 + CGFloat(i) * 0.16), height: diameter * (1.08 + CGFloat(i) * 0.16))
                        .scaleEffect(voice.isSpeaking ? (1.0 + CGFloat(voice.speechAmplitude) * 0.10 * CGFloat(i + 1)) : 1.0)
                        .opacity(voice.isSpeaking ? 0.75 - Double(i) * 0.2 : 0.25)
                }

                // 3. Núcleo Cromático Líquido (Liquid Core con Shaders de Gradiente Angular y Radial)
                ZStack {
                    AngularGradient(
                        colors: [
                            primaryAuraColor,
                            secondaryAuraColor,
                            Color(red: 0.0, green: 0.94, blue: 1.0),
                            primaryAuraColor
                        ],
                        center: .center,
                        angle: .degrees(innerRotation)
                    )
                    .clipShape(Circle())
                    .blur(radius: 20)

                    // Puntos de luz caústica interna
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.85), Color.clear],
                                center: .topLeading,
                                startRadius: 10,
                                endRadius: diameter * 0.65
                            )
                        )
                        .blendMode(.screen)
                }
                .frame(width: diameter, height: diameter)

                // 4. Partículas Cuánticas Orbitantes
                ForEach(0..<12) { index in
                    let angle = (Double(index) / 12.0) * 2 * Double.pi + (innerRotation * Double.pi / 180.0)
                    let radiusOffset = (diameter * 0.50) + sin(phase + Double(index)) * (voice.isSpeaking ? 18.0 : 8.0)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 4, height: 4)
                        .shadow(color: primaryAuraColor, radius: 4)
                        .position(
                            x: (diameter / 2) + cos(angle) * radiusOffset,
                            y: (diameter / 2) + sin(angle) * radiusOffset
                        )
                }
                .frame(width: diameter, height: diameter)

                // 5. Cúpula Frontal de Liquid Glass (Specular Rim & Caustics)
                Circle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.35)
                    .frame(width: diameter, height: diameter)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    stops: [
                                        .init(color: Color.white.opacity(0.85), location: 0.0),
                                        .init(color: Color.white.opacity(0.30), location: 0.35),
                                        .init(color: Color.clear, location: 0.65),
                                        .init(color: Color.white.opacity(0.15), location: 1.0)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: Color.black.opacity(0.40), radius: 18, x: 0, y: 10)

                // 6. Micro-Onda Espectral Central cuando Livi habla
                if voice.isSpeaking {
                    HStack(spacing: 3) {
                        ForEach(0..<7) { bar in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white.opacity(0.95))
                                .frame(
                                    width: 3.5,
                                    height: max(6, 34 * CGFloat(voice.speechAmplitude) * CGFloat(sin(Double(bar) * 0.8 + phase) + 1.2))
                                )
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: diameter * 1.3, height: diameter * 1.3)
            .onAppear {
                withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
                    innerRotation = 360.0
                }
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    phase = Double.pi * 2
                }
            }

            // Indicador Dinámico de Estado
            if showDynamicPill {
                HStack(spacing: 8) {
                    Circle()
                        .fill(primaryAuraColor)
                        .frame(width: 8, height: 8)
                        .scaleEffect(voice.isSpeaking ? 1.4 : 1.0)
                        .animation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true), value: voice.isSpeaking)

                    Text(livi.currentState.statusText)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .liquidGlass(cornerRadius: 20, opacity: 0.85)
                .overlay(
                    Capsule()
                        .stroke(primaryAuraColor.opacity(0.45), lineWidth: 1.0)
                )
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: livi.currentState.statusText)
            }
        }
    }
}
