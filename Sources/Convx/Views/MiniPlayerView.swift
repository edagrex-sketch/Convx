import SwiftUI

public struct MiniPlayerView: View {
    @ObservedObject var player = AudioPlayerService.shared
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var livi = DJLiviService.shared
    @ObservedObject var voice = DJLiviVoiceService.shared

    @State private var horizontalOffset: CGFloat = 0.0
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)

    public init() {
        impactFeedback.prepare()
    }

    public var body: some View {
        if let track = player.currentTrack {
            ZStack {
                // Background gesture hints when swiping
                HStack {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(theme.activeAccentColor.opacity(horizontalOffset > 40 ? 0.95 : 0.25))
                        .scaleEffect(horizontalOffset > 40 ? 1.25 : 0.85)
                        .padding(.leading, 32)

                    Spacer()

                    Image(systemName: "forward.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(theme.activeAccentColor.opacity(horizontalOffset < -40 ? 0.95 : 0.25))
                        .scaleEffect(horizontalOffset < -40 ? 1.25 : 0.85)
                        .padding(.trailing, 32)
                }

                Button(action: {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
                        player.isPresentingFullPlayer = true
                    }
                }) {
                    HStack(spacing: 12) {
                        // Artwork with subtle play pulse
                        ArtworkImageView(urlString: track.thumbnail, songId: track.id, size: 44, cornerRadius: 10)
                            .shadow(color: theme.activeAccentColor.opacity(player.isPlaying ? 0.35 : 0.15), radius: 6, x: 0, y: 3)
                            .scaleEffect(player.isPlaying ? 1.0 : 0.94)
                            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: player.isPlaying)

                        // Track & Artist Info + Mini Equalizer
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                MarqueeText(
                                    text: track.title,
                                    font: .system(size: 15, weight: .semibold),
                                    color: .white
                                )

                                ConvxMiniEqualizerView(isPlaying: player.isPlaying, accentColor: theme.activeAccentColor)

                                // if livi.isDJSessionActive {
                                //     Image(systemName: "sparkles")
                                //         .font(.system(size: 10, weight: .bold))
                                //         .foregroundColor(voice.isSpeaking ? Color(red: 1.0, green: 0.15, blue: 0.65) : theme.activeAccentColor)
                                //         .scaleEffect(voice.isSpeaking ? 1.3 : 1.0)
                                //         .animation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true), value: voice.isSpeaking)
                                // }
                            }

                            Text(track.artistNames)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.white.opacity(0.65))
                                .lineLimit(1)
                        }

                        Spacer()

                        // Play/Pause Button
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            player.togglePlayPause()
                        }) {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        // Skip Next Button
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            player.skipNext()
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white.opacity(0.85))
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(height: 64)
                    .overlay(alignment: .bottom) {
                        GeometryReader { barGeo in
                            let progress = player.duration > 0 ? max(0.0, min(1.0, player.currentTime / player.duration)) : 0.0
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.12))
                                    .frame(height: 2.2)

                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [theme.activeAccentColor.opacity(0.7), theme.activeAccentColor, Color.white],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(0, barGeo.size.width * CGFloat(progress)), height: 2.2)
                                    .shadow(color: theme.activeAccentColor.opacity(0.8), radius: 3, x: 0, y: 0)
                            }
                        }
                        .frame(height: 2.2)
                        .padding(.horizontal, 28)
                        .offset(y: -5)
                    }
                    .liquidGlass(cornerRadius: 32, opacity: 0.90)
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)
                .offset(x: horizontalOffset)
                .gesture(
                    DragGesture(minimumDistance: 12)
                        .onChanged { g in
                            let raw = g.translation.width
                            if abs(raw) > 80 {
                                let sign: CGFloat = raw > 0 ? 1 : -1
                                horizontalOffset = sign * (80 + pow(abs(raw) - 80, 0.65))
                            } else {
                                horizontalOffset = raw
                            }
                        }
                        .onEnded { g in
                            let translation = g.translation.width
                            if translation < -65 {
                                impactFeedback.impactOccurred()
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                    horizontalOffset = -260
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                                    player.skipNext()
                                    horizontalOffset = 260
                                    withAnimation(.spring(response: 0.36, dampingFraction: 0.78)) {
                                        horizontalOffset = 0
                                    }
                                }
                            } else if translation > 65 {
                                impactFeedback.impactOccurred()
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                    horizontalOffset = 260
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                                    player.skipPrevious()
                                    horizontalOffset = -260
                                    withAnimation(.spring(response: 0.36, dampingFraction: 0.78)) {
                                        horizontalOffset = 0
                                    }
                                }
                            } else {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    horizontalOffset = 0
                                }
                            }
                        }
                )
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
