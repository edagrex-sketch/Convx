import SwiftUI

public struct DJLiviFloatingButton: View {
    @ObservedObject var livi = DJLiviService.shared
    @ObservedObject var voice = DJLiviVoiceService.shared
    @ObservedObject var theme = ThemeManager.shared

    @State private var rotationAngle: Double = 0.0

    public init() {}

    public var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                rotationAngle += 180.0
            }
            if !livi.isDJSessionActive {
                livi.startDJSession()
            } else {
                livi.triggerVibeShift()
            }
        }) {
            ZStack {
                // Aura viva pulsante cuando Livi habla
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                (voice.isSpeaking ? Color(red: 1.0, green: 0.15, blue: 0.65) : theme.activeAccentColor).opacity(0.55),
                                .clear
                            ],
                            center: .center,
                            startRadius: 8,
                            endRadius: 36
                        )
                    )
                    .frame(width: 68, height: 68)
                    .scaleEffect(voice.isSpeaking ? 1.25 : 1.0)
                    .blur(radius: 6)

                // Núcleo Liquid Glass
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 48, height: 48)
                    .liquidGlass(cornerRadius: 24, opacity: 0.90)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.85),
                                        (voice.isSpeaking ? Color(red: 1.0, green: 0.15, blue: 0.65) : theme.activeAccentColor).opacity(0.5)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                    )

                // Icono central giratorio
                Image(systemName: "sparkles")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(voice.isSpeaking ? Color(red: 1.0, green: 0.15, blue: 0.65) : theme.activeAccentColor)
                    .rotationEffect(.degrees(rotationAngle))
            }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4)
                .onEnded { _ in
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    livi.isSheetPresented = true
                }
        )
    }
}
