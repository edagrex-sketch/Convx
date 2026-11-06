import SwiftUI
import UIKit

// MARK: - Notch Island (Adaptive Dynamic Notch for iPhone 16e & Notch Devices)
public struct ConvxNotchIsland: View {
    @ObservedObject var player = AudioPlayerService.shared
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var hud = HUDService.shared

    @AppStorage("notchIslandEnabled") private var notchIslandEnabled: Bool = true
    @State private var isExpanded: Bool = false
    @State private var dragYOffset: CGFloat = 0.0

    private let impactFeedback = UIImpactFeedbackGenerator(style: .rigid)
    private let mediumFeedback = UIImpactFeedbackGenerator(style: .medium)

    public init() {
        impactFeedback.prepare()
        mediumFeedback.prepare()
    }

    private var hasActiveTrack: Bool {
        player.currentTrack != nil
    }

    private var hasHUDItem: Bool {
        hud.currentItem != nil
    }

    private var isVisible: Bool {
        notchIslandEnabled && (hasActiveTrack || hasHUDItem)
    }

    public var body: some View {
        if isVisible {
            VStack(spacing: 0) {
                notchCapsule
                    .offset(y: max(0, dragYOffset * 0.3))
                    .gesture(
                        DragGesture(minimumDistance: 10)
                            .onChanged { g in
                                if isExpanded && g.translation.height < 0 {
                                    dragYOffset = g.translation.height
                                } else if !isExpanded && g.translation.height > 0 {
                                    dragYOffset = g.translation.height
                                }
                            }
                            .onEnded { g in
                                if isExpanded && g.translation.height < -30 {
                                    withAnimation(.spring(response: 0.38, dampingFraction: 0.75)) {
                                        isExpanded = false
                                        dragYOffset = 0
                                    }
                                    mediumFeedback.impactOccurred()
                                } else if !isExpanded && g.translation.height > 25 {
                                    withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
                                        isExpanded = true
                                        dragYOffset = 0
                                    }
                                    impactFeedback.impactOccurred()
                                } else {
                                    withAnimation(.spring(response: 0.30, dampingFraction: 0.80)) {
                                        dragYOffset = 0
                                    }
                                }
                            }
                    )
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .ignoresSafeArea(edges: .top)
            .animation(.spring(response: 0.42, dampingFraction: 0.74), value: isExpanded)
            .animation(.spring(response: 0.35, dampingFraction: 0.72), value: hud.currentItem)
            .animation(.spring(response: 0.40, dampingFraction: 0.78), value: player.isPlaying)
        }
    }

    // MARK: - Notch Capsule
    @ViewBuilder
    private var notchCapsule: some View {
        if let hudItem = hud.currentItem {
            // Mode 1: HUD Alert extending from the Notch
            hudAlertView(hudItem)
        } else if isExpanded {
            // Mode 2: Expanded Interactive Notch Player
            expandedPlayerView
        } else if let track = player.currentTrack {
            // Mode 3: Compact Notch Island (Active Music)
            compactIslandView(track)
        }
    }

    // MARK: - Compact Mode (Embraces iPhone 16e Notch)
    private func compactIslandView(_ track: SongItem) -> some View {
        Button(action: {
            impactFeedback.impactOccurred()
            withAnimation(.spring(response: 0.40, dampingFraction: 0.72)) {
                isExpanded.toggle()
            }
        }) {
            HStack(spacing: 10) {
                // Left Wing: Micro Artwork or Vinyl
                ArtworkImageView(urlString: track.thumbnail, songId: track.id, size: 26, cornerRadius: 7)
                    .scaleEffect(player.isPlaying ? 1.05 : 0.95)
                    .shadow(color: theme.activeAccentColor.opacity(0.35), radius: 4)

                // Center Title
                Text(track.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(maxWidth: 130, alignment: .leading)

                Spacer(minLength: 4)

                // Right Wing: Mini Equalizer Pulse
                ConvxMiniEqualizerView(isPlaying: player.isPlaying, accentColor: theme.activeAccentColor)
                    .frame(width: 16, height: 16)
                    .padding(.trailing, 2)
            }
            .padding(.horizontal, 14)
            .padding(.top, 38) // Clears the physical notch camera/sensor area
            .padding(.bottom, 10)
            .frame(width: 236)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.black)
                    .shadow(color: Color.black.opacity(0.5), radius: 10, x: 0, y: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.20),
                                theme.activeAccentColor.opacity(0.30),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )
            )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                impactFeedback.impactOccurred()
                player.isPresentingFullPlayer = true
            }
        )
    }

    // MARK: - Expanded Interactive Notch Island
    private var expandedPlayerView: some View {
        VStack(spacing: 12) {
            if let track = player.currentTrack {
                // Header Row: Cover, Info & Full Screen Jump
                HStack(spacing: 14) {
                    ArtworkImageView(urlString: track.thumbnail, songId: track.id, size: 52, cornerRadius: 12)
                        .shadow(color: theme.activeAccentColor.opacity(0.4), radius: 8, x: 0, y: 3)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(track.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(track.artistNames)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.65))
                            .lineLimit(1)
                    }

                    Spacer()

                    // Expand to Full Player Icon
                    Button(action: {
                        impactFeedback.impactOccurred()
                        isExpanded = false
                        player.isPresentingFullPlayer = true
                    }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white.opacity(0.70))
                            .padding(8)
                            .background(Color.white.opacity(0.10))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                // Micro Scrubber Bar
                GeometryReader { barGeo in
                    let progress = player.duration > 0 ? max(0.0, min(1.0, player.currentTime / player.duration)) : 0.0
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.18))
                            .frame(height: 4)

                        Capsule()
                            .fill(theme.activeAccentColor)
                            .frame(width: max(0, barGeo.size.width * CGFloat(progress)), height: 4)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, 4)

                // Controls Row
                HStack(spacing: 24) {
                    // Like Button
                    Button(action: {
                        impactFeedback.impactOccurred()
                        player.toggleLike()
                    }) {
                        Image(systemName: player.isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 18))
                            .foregroundColor(player.isLiked ? Color(red: 1.0, green: 0.22, blue: 0.38) : .white.opacity(0.75))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // Previous Track
                    Button(action: {
                        impactFeedback.impactOccurred()
                        player.skipPrevious()
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)

                    // Play / Pause Button
                    Button(action: {
                        impactFeedback.impactOccurred()
                        player.togglePlayPause()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 40, height: 40)

                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                                .offset(x: player.isPlaying ? 0 : 1.5)
                        }
                    }
                    .buttonStyle(.plain)

                    // Next Track
                    Button(action: {
                        impactFeedback.impactOccurred()
                        player.skipNext()
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // Retract / Dismiss to Notch Button
                    Button(action: {
                        mediumFeedback.impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.80)) {
                            isExpanded = false
                        }
                    }) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.60))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 46) // Flush below notch hardware
        .padding(.bottom, 16)
        .frame(maxWidth: 365)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.black)
                .shadow(color: Color.black.opacity(0.65), radius: 18, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.24),
                            theme.activeAccentColor.opacity(0.40),
                            Color.white.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
    }

    // MARK: - HUD Alert Mode (Morphed from Notch)
    private func hudAlertView(_ item: HUDService.HUDItem) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(item.iconColor.opacity(0.20))
                    .frame(width: 32, height: 32)
                Image(systemName: item.icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(item.iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                if let sub = item.subtitle, !sub.isEmpty {
                    Text(sub)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.70))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 6)
        }
        .padding(.horizontal, 16)
        .padding(.top, 40) // Emerges cleanly from notch
        .padding(.bottom, 12)
        .frame(maxWidth: 320)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.black)
                .shadow(color: Color.black.opacity(0.55), radius: 14, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(item.iconColor.opacity(0.35), lineWidth: 1.0)
        )
    }
}
