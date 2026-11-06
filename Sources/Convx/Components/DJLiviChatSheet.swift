import SwiftUI

public struct DJLiviChatSheet: View {
    @ObservedObject var livi = DJLiviService.shared
    @ObservedObject var voice = DJLiviVoiceService.shared
    @ObservedObject var player = AudioPlayerService.shared
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var inputText: String = ""
    @FocusState private var isFieldFocused: Bool

    let quickChips = [
        "🔥 Más bailable para fiesta",
        "💡 Dato curioso de esta rola",
        "❓ ¿Por qué elegiste esta canción?",
        "🌸 Tokyo 80s City Pop",
        "🤠 Corridos Tumbados bélicos",
        "🎸 Rock en Español de los 90s",
        "🚫 No me gustó este género",
        "🎲 Sorpréndeme con algo nuevo"
    ]

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                // Fondo oscuro inmersivo
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Grabber
                    Capsule()
                        .fill(Color.white.opacity(0.30))
                        .frame(width: 36, height: 4)
                        .padding(.top, 10)
                        .padding(.bottom, 6)

                    // Header con Esfera Miniatura y Estado
                    HStack(spacing: 12) {
                        DJLiviHolographicSphere(diameter: 46, showDynamicPill: false)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("DJ Livi")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)

                                Text("IA ACTIVA")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundColor(theme.activeAccentColor)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(theme.activeAccentColor.opacity(0.18))
                                    .clipShape(Capsule())
                            }

                            Text(livi.currentState.statusText)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.70))
                                .lineLimit(1)
                        }

                        Spacer()

                        // Botón de voz (Activar/Mute)
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            voice.isVoiceEnabled.toggle()
                        }) {
                            Image(systemName: voice.isVoiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                .font(.system(size: 15))
                                .foregroundColor(voice.isVoiceEnabled ? theme.activeAccentColor : .gray)
                                .padding(8)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }

                        // Cerrar
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            dismiss()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.white.opacity(0.60))
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 10)

                    Divider().background(Color.white.opacity(0.12))

                    // Historial de Mensajes
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 14) {
                                ForEach(livi.chatMessages) { msg in
                                    chatBubble(msg)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .onChange(of: livi.chatMessages.count) { _, _ in
                            if let last = livi.chatMessages.last {
                                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                            }
                        }
                    }

                    // Chips de Sugerencia Rápida
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(quickChips, id: \.self) { chip in
                                Button(action: {
                                    livi.sendUserPrompt(chip)
                                }) {
                                    Text(chip)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.90))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(Color.white.opacity(0.08))
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.8))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                    }

                    // Barra de Entrada Táctil
                    HStack(spacing: 10) {
                        TextField("Pídele un cambio de onda, una trivia o un género...", text: $inputText)
                            .foregroundColor(.white)
                            .tint(theme.activeAccentColor)
                            .focused($isFieldFocused)
                            .submitLabel(.send)
                            .onSubmit {
                                sendCurrent()
                            }

                        Button(action: sendCurrent) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(inputText.isEmpty ? .white.opacity(0.25) : theme.activeAccentColor)
                        }
                        .disabled(inputText.isEmpty)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .liquidGlass(cornerRadius: 22, opacity: 0.85)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
        }
        .presentationDetents([.fraction(0.70), .large])
        .presentationDragIndicator(.hidden)
    }

    private func sendCurrent() {
        guard !inputText.isEmpty else { return }
        livi.sendUserPrompt(inputText)
        inputText = ""
    }

    @ViewBuilder
    private func chatBubble(_ msg: DJLiviChatMessage) -> some View {
        let isUser = (msg.sender == .user)
        HStack {
            if isUser { Spacer(minLength: 40) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
                Text(msg.text)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isUser
                            ? theme.activeAccentColor.opacity(0.35)
                            : Color.white.opacity(0.10)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .liquidGlass(cornerRadius: 16, opacity: 0.85)

                // Dato Curioso / Trivia Card
                if let trivia = msg.triviaData {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 14))
                            .padding(.top, 2)
                        Text(trivia)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.90))
                    }
                    .padding(10)
                    .background(Color.yellow.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.yellow.opacity(0.3), lineWidth: 0.8))
                }

                // Canciones Sugeridas Embebidas
                if let songs = msg.suggestedSongs, !songs.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(songs) { song in
                            HStack(spacing: 10) {
                                ArtworkImageView(urlString: song.thumbnail, size: 36, cornerRadius: 8)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(song.title)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Text(song.artistNames)
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.65))
                                        .lineLimit(1)
                                }
                                Spacer()
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    AudioPlayerService.shared.playTrack(song, inQueue: songs)
                                }) {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(theme.activeAccentColor)
                                }
                            }
                            .padding(8)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }

            if !isUser { Spacer(minLength: 40) }
        }
        .id(msg.id)
    }
}
