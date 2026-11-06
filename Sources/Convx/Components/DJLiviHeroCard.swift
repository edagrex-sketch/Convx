import SwiftUI

public struct DJLiviHeroCard: View {
    @ObservedObject var livi = DJLiviService.shared
    @ObservedObject var voice = DJLiviVoiceService.shared
    @ObservedObject var theme = ThemeManager.shared

    public init() {}

    public var body: some View {
        ZStack {
            // Fondo con degradado profundo y borde Liquid Glass
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            theme.activeAccentColor.opacity(0.22),
                            Color(red: 0.14, green: 0.08, blue: 0.32).opacity(0.85),
                            Color(red: 0.06, green: 0.06, blue: 0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            HStack(spacing: 16) {
                // Esfera Holográfica Viva en miniatura interactiva
                DJLiviHolographicSphere(diameter: 64, showDynamicPill: false)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("DJ LIVI")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(theme.activeAccentColor)
                            .textCase(.uppercase)

                        Circle()
                            .fill(livi.isDJSessionActive ? Color.green : Color.white.opacity(0.4))
                            .frame(width: 6, height: 6)

                        if voice.isSpeaking {
                            Text("HABLANDO")
                                .font(.system(size: 8, weight: .black))
                                .foregroundColor(Color(red: 1.0, green: 0.15, blue: 0.65))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color(red: 1.0, green: 0.15, blue: 0.65).opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }

                    Text("Tu curadora personal con IA")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(livi.currentSetName)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.70))
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        // Botón Iniciar / Cambiar Sesión
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                            if !livi.isDJSessionActive {
                                livi.startDJSession()
                            } else {
                                livi.triggerVibeShift()
                            }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: livi.isDJSessionActive ? "arrow.triangle.2.circlepath" : "play.fill")
                                    .font(.system(size: 11, weight: .bold))
                                Text(livi.isDJSessionActive ? "Cambiar Onda" : "Iniciar DJ Livi")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(theme.activeAccentColor)
                            .clipShape(Capsule())
                        }

                        // Botón Hablar / Preguntar
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            livi.isSheetPresented = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .font(.system(size: 11))
                                Text("Hablar")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.top, 4)
                }

                Spacer()
            }
            .padding(16)
        }
        .frame(height: 124)
        .liquidGlass(cornerRadius: 24, opacity: 0.90)
        .sheet(isPresented: $livi.isSheetPresented) {
            DJLiviChatSheet()
        }
    }
}
