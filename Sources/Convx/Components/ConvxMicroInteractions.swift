import SwiftUI
import UIKit

// MARK: - 1. Breathing Artwork with Dynamic Aura Glow
public struct ConvxBreathingArtwork: View {
    let urlString: String?
    let songId: String?
    let isPlaying: Bool
    let size: CGFloat
    let accentColor: Color

    @State private var breathingPulse: Bool = false

    public init(urlString: String?, songId: String?, isPlaying: Bool, size: CGFloat = 260, accentColor: Color = .cyan) {
        self.urlString = urlString
        self.songId = songId
        self.isPlaying = isPlaying
        self.size = size
        self.accentColor = accentColor
    }

    public var body: some View {
        ZStack {
            // Dynamic back-glow matching accent/artwork
            ArtworkImageView(urlString: urlString, songId: songId, size: size, cornerRadius: isPlaying ? 24 : 18)
                .blur(radius: isPlaying ? 32 : 14)
                .opacity(isPlaying ? 0.65 : 0.20)
                .offset(y: isPlaying ? 14 : 4)

            // Sharp Primary Artwork with dynamic scale and subtle breathing
            ArtworkImageView(urlString: urlString, songId: songId, size: size, cornerRadius: isPlaying ? 24 : 18)
                .scaleEffect(isPlaying ? (breathingPulse ? 1.018 : 1.0) : 0.88)
                .shadow(color: Color.black.opacity(isPlaying ? 0.55 : 0.30), radius: isPlaying ? 32 : 12, x: 0, y: isPlaying ? 16 : 6)
        }
        .animation(.spring(response: 0.50, dampingFraction: 0.72), value: isPlaying)
        .onChange(of: isPlaying, initial: true) { _, playing in
            if playing {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    breathingPulse = true
                }
            } else {
                withAnimation(.spring(response: 0.40, dampingFraction: 0.80)) {
                    breathingPulse = false
                }
            }
        }
    }
}

// MARK: - 2. Retro Vinyl Record Mode
public struct RetroVinylView: View {
    let track: SongItem?
    let isPlaying: Bool
    let size: CGFloat

    @State private var rotationAngle: Double = 0.0
    @State private var timer: Timer? = nil

    public init(track: SongItem?, isPlaying: Bool, size: CGFloat = 260) {
        self.track = track
        self.isPlaying = isPlaying
        self.size = size
    }

    public var body: some View {
        ZStack {
            // Drop Shadow
            Circle()
                .fill(Color.black.opacity(0.50))
                .frame(width: size * 0.95, height: size * 0.95)
                .blur(radius: 18)
                .offset(y: 12)

            // 1. Vinyl Body (Deep Carbon Black)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(white: 0.16), Color(white: 0.07), Color(white: 0.02)],
                        center: .center,
                        startRadius: size * 0.2,
                        endRadius: size * 0.5
                    )
                )
                .frame(width: size, height: size)

            // 2. Concentric Grooves (Realistic LP Sound Tracks)
            ForEach(0..<6) { i in
                let grooveRadius = size * (0.23 + CGFloat(i) * 0.044)
                Circle()
                    .strokeBorder(Color.white.opacity(0.045), lineWidth: 0.7)
                    .frame(width: grooveRadius * 2, height: grooveRadius * 2)
            }

            // 3. Spun Light Sheen (45° Reflection Anisotropy)
            AngularGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: Color.white.opacity(0.14), location: 0.12),
                    .init(color: .clear, location: 0.25),
                    .init(color: .clear, location: 0.50),
                    .init(color: Color.white.opacity(0.14), location: 0.62),
                    .init(color: .clear, location: 0.75),
                    .init(color: .clear, location: 1.0)
                ],
                center: .center
            )
            .clipShape(Circle())
            .frame(width: size, height: size)
            .blendMode(.screen)

            // 4. Center Label with Track Artwork
            ZStack {
                ArtworkImageView(
                    urlString: track?.thumbnail,
                    songId: track?.id,
                    size: size * 0.40,
                    cornerRadius: size * 0.20
                )
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.black.opacity(0.4), lineWidth: 2.0))

                // Center Spindle Hole
                Circle()
                    .fill(Color(white: 0.08))
                    .frame(width: 18, height: 18)
                    .overlay(Circle().stroke(Color(white: 0.5), lineWidth: 1.2))
            }
        }
        .rotationEffect(.degrees(rotationAngle))
        .onAppear {
            if isPlaying { startSpinning() }
        }
        .onChange(of: isPlaying) { _, playing in
            if playing {
                startSpinning()
            } else {
                stopSpinningWithMomentum()
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private func startSpinning() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            Task { @MainActor in
                rotationAngle = (rotationAngle + 3.8).truncatingRemainder(dividingBy: 360)
            }
        }
    }

    private func stopSpinningWithMomentum() {
        timer?.invalidate()
        timer = nil
        // Realistic friction spin-down
        withAnimation(.easeOut(duration: 0.95)) {
            rotationAngle += 40.0
        }
    }
}

// MARK: - 3. Minimalist Visualizer Mode
public struct MinimalistVisualizerView: View {
    let track: SongItem?
    let isPlaying: Bool
    let accentColor: Color

    private let barCount = 26

    public init(track: SongItem?, isPlaying: Bool, accentColor: Color) {
        self.track = track
        self.isPlaying = isPlaying
        self.accentColor = accentColor
    }

    public var body: some View {
        VStack(spacing: 22) {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isPlaying)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                HStack(alignment: .center, spacing: 4) {
                    ForEach(0..<barCount, id: \.self) { i in
                        let phase = Double(i) * 0.42
                        let wave = isPlaying ? (sin(time * 5.0 + phase) * cos(time * 2.8 - phase * 0.5) + 1.0) / 2.0 : 0.08
                        let h = max(6.0, CGFloat(wave * 115.0))

                        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [accentColor, accentColor.opacity(0.40)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 4.5, height: h)
                            .animation(.spring(response: 0.20, dampingFraction: 0.70), value: isPlaying)
                    }
                }
                .frame(height: 120)
            }
            .padding(.horizontal, 24)

            // Audiophile Specs Pill
            HStack(spacing: 8) {
                Label("AAC itag 140", systemImage: "waveform.badge.magnifyingglass")
                Text("•")
                Text("128 kbps")
                Text("•")
                Text("44.1 kHz")
                Text("•")
                Text("VisionOS Pure")
            }
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundColor(.white.opacity(0.70))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
        }
    }
}

// MARK: - 4. Heart Particle Explosion on Double Tap
public struct HeartParticle: Identifiable {
    public let id = UUID()
    public var x: CGFloat
    public var y: CGFloat
    public var scale: CGFloat
    public var opacity: Double
    public var rotation: Angle
}

public struct HeartParticleBurstView: View {
    @Binding var trigger: Int
    @State private var particles: [HeartParticle] = []
    @State private var centralHeartScale: CGFloat = 0.0
    @State private var centralHeartOpacity: Double = 0.0

    public init(trigger: Binding<Int>) {
        self._trigger = trigger
    }

    public var body: some View {
        ZStack {
            // Central Scaling Pop
            Image(systemName: "heart.fill")
                .font(.system(size: 80))
                .foregroundColor(Color(red: 1.0, green: 0.18, blue: 0.33))
                .scaleEffect(centralHeartScale)
                .opacity(centralHeartOpacity)
                .shadow(color: Color.red.opacity(0.5), radius: 16)

            // Orbiting Micro Particles
            ForEach(particles) { p in
                Image(systemName: "heart.fill")
                    .font(.system(size: 16))
                    .foregroundColor([Color(red: 1.0, green: 0.25, blue: 0.40), Color.pink, Color.white].randomElement()!)
                    .scaleEffect(p.scale)
                    .opacity(p.opacity)
                    .rotationEffect(p.rotation)
                    .offset(x: p.x, y: p.y)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in
            spawnBurst()
        }
    }

    private func spawnBurst() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        centralHeartScale = 0.1
        centralHeartOpacity = 1.0
        withAnimation(.spring(response: 0.35, dampingFraction: 0.52)) {
            centralHeartScale = 1.25
        }
        withAnimation(.easeOut(duration: 0.40).delay(0.20)) {
            centralHeartScale = 1.5
            centralHeartOpacity = 0.0
        }

        var newParticles: [HeartParticle] = []
        for _ in 0..<16 {
            let angle = Double.random(in: 0..<Double.pi * 2)
            let distance = CGFloat.random(in: 60...130)
            newParticles.append(HeartParticle(
                x: cos(angle) * distance,
                y: sin(angle) * distance,
                scale: CGFloat.random(in: 0.7...1.3),
                opacity: 1.0,
                rotation: .degrees(Double.random(in: -45...45))
            ))
        }
        particles = newParticles

        withAnimation(.easeOut(duration: 0.65)) {
            for i in particles.indices {
                particles[i].x *= 1.35
                particles[i].y *= 1.35
                particles[i].opacity = 0.0
            }
        }
    }
}

// MARK: - 4b. Heart Button with Spring Pop
public struct ConvxHeartExplosionButton: View {
    @ObservedObject var player = AudioPlayerService.shared
    @State private var isScaled = false

    public init() {}

    public var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.30, dampingFraction: 0.45)) {
                isScaled = true
                player.toggleLike()
            }
            if player.isLiked {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } else {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.70)) {
                    isScaled = false
                }
            }
        }) {
            Image(systemName: player.isLiked ? "heart.fill" : "heart")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(player.isLiked ? Color(red: 1.0, green: 0.22, blue: 0.38) : .white.opacity(0.8))
                .scaleEffect(isScaled ? 1.35 : 1.0)
                .contentTransition(.symbolEffect(.replace.downUp.byLayer))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 5. Tactile Scrubber with Magnification & Floating Time Bubble
public struct ConvxTactileScrubber: View {
    @ObservedObject var player = AudioPlayerService.shared
    let accentColor: Color

    @State private var isScrubbing = false
    @State private var scrubTime: Double = 0.0
    @State private var lastHapticStep: Int = 0

    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)

    public init(accentColor: Color = .white) {
        self.accentColor = accentColor
        selectionFeedback.prepare()
        impactFeedback.prepare()
    }

    public var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let width = geo.size.width
                let progress = player.duration > 0 ? (isScrubbing ? scrubTime : player.currentTime) / player.duration : 0.0
                let clampedProgress = max(0.0, min(1.0, progress))
                let currentThumbX = width * CGFloat(clampedProgress)

                ZStack(alignment: .leading) {
                    // Floating Time Bubble above touch point
                    if isScrubbing {
                        VStack(spacing: 2) {
                            Text(formatSeconds(scrubTime))
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Text("-\(formatSeconds(max(0, player.duration - scrubTime)))")
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.65))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 0.8))
                        .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)
                        .position(x: min(max(36, currentThumbX), width - 36), y: -26)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                    }

                    // Background Track
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(height: isScrubbing ? 9 : 5)

                    // Progress Fill Bar
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [accentColor.opacity(0.85), accentColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, currentThumbX), height: isScrubbing ? 9 : 5)

                    // Magnified Thumb
                    Circle()
                        .fill(Color.white)
                        .frame(width: isScrubbing ? 16 : 8, height: isScrubbing ? 16 : 8)
                        .shadow(color: Color.black.opacity(0.35), radius: 4, x: 0, y: 2)
                        .overlay(Circle().stroke(accentColor.opacity(0.3), lineWidth: 1.5))
                        .position(x: currentThumbX, y: (isScrubbing ? 9 : 5) / 2)
                        .scaleEffect(isScrubbing ? 1.25 : 1.0)
                }
                .frame(height: 20)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            if !isScrubbing {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                    isScrubbing = true
                                }
                                selectionFeedback.selectionChanged()
                            }
                            let frac = max(0.0, min(1.0, Double(g.location.x / width)))
                            scrubTime = frac * player.duration

                            let step = Int(frac * 20)
                            if step != lastHapticStep {
                                selectionFeedback.selectionChanged()
                                lastHapticStep = step
                            }
                        }
                        .onEnded { g in
                            let frac = max(0.0, min(1.0, Double(g.location.x / width)))
                            player.seek(to: frac * player.duration)
                            impactFeedback.impactOccurred()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                isScrubbing = false
                            }
                        }
                )
            }
            .frame(height: 20)

            // Monospaced Timestamp Footers
            HStack {
                Text(formatSeconds(isScrubbing ? scrubTime : player.currentTime))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(isScrubbing ? 0.95 : 0.55))

                Spacer()

                let remaining = max(0.0, player.duration - (isScrubbing ? scrubTime : player.currentTime))
                Text("-\(formatSeconds(remaining))")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(isScrubbing ? 0.95 : 0.55))
            }
        }
        .padding(.horizontal, 28)
    }

    private func formatSeconds(_ seconds: Double) -> String {
        guard seconds > 0 && seconds.isFinite else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - 6. Play/Pause Bouncy Spring Button
public struct ConvxPlayPauseButton: View {
    @ObservedObject var player = AudioPlayerService.shared
    @State private var isPressed = false
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)

    public init() {
        impactFeedback.prepare()
    }

    public var body: some View {
        Button(action: {
            impactFeedback.impactOccurred()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.60)) {
                player.togglePlayPause()
            }
        }) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 66, height: 66)
                    .shadow(color: Color.white.opacity(player.isPlaying ? 0.35 : 0.15), radius: player.isPlaying ? 16 : 8, x: 0, y: 4)

                if player.isLoading {
                    ProgressView()
                        .tint(.black)
                } else {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.black)
                        .offset(x: player.isPlaying ? 0 : 2)
                        .contentTransition(.symbolEffect(.replace.downUp.byLayer))
                }
            }
            .scaleEffect(isPressed ? 0.88 : (player.isPlaying ? 1.0 : 0.98))
        }
        .buttonStyle(BouncyButtonStyle(isPressed: $isPressed))
    }
}

fileprivate struct BouncyButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, pressed in
                withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                    isPressed = pressed
                }
            }
    }
}

// MARK: - 7. Tactile Volume Slider with Peak Boundary Haptics
public struct ConvxTactileVolumeSlider: View {
    @ObservedObject var player = AudioPlayerService.shared
    let accentColor: Color

    @State private var volume: Double = 0.80
    @State private var isDragging = false
    @State private var overdragOffset: CGFloat = 0.0

    private let rigidFeedback = UIImpactFeedbackGenerator(style: .rigid)

    public init(accentColor: Color = .white) {
        self.accentColor = accentColor
        rigidFeedback.prepare()
    }

    private var speakerIconName: String {
        if volume <= 0.001 { return "speaker.slash.fill" }
        if volume < 0.33 { return "speaker.fill" }
        if volume < 0.66 { return "speaker.wave.1.fill" }
        return "speaker.wave.3.fill"
    }

    public var body: some View {
        HStack(spacing: 14) {
            Image(systemName: speakerIconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(volume <= 0.001 ? 0.35 : 0.75))
                .frame(width: 22)
                .contentTransition(.symbolEffect(.replace.downUp.byLayer))

            GeometryReader { geo in
                let width = geo.size.width
                let clampedVol = max(0.0, min(1.0, volume))

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(height: isDragging ? 8 : 5)

                    Capsule()
                        .fill(accentColor)
                        .frame(width: max(0, width * CGFloat(clampedVol)) + overdragOffset, height: isDragging ? 8 : 5)
                }
                .frame(height: 20)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            if !isDragging {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                    isDragging = true
                                }
                            }
                            let rawFraction = Double(g.location.x / width)
                            if rawFraction < 0.0 {
                                overdragOffset = -pow(abs(CGFloat(rawFraction)), 0.65) * 16
                                if volume > 0.0 {
                                    volume = 0.0
                                    rigidFeedback.impactOccurred()
                                }
                            } else if rawFraction > 1.0 {
                                overdragOffset = pow(CGFloat(rawFraction - 1.0), 0.65) * 16
                                if volume < 1.0 {
                                    volume = 1.0
                                    rigidFeedback.impactOccurred()
                                }
                            } else {
                                overdragOffset = 0.0
                                volume = rawFraction
                                player.setVolume(Float(rawFraction))
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.65)) {
                                overdragOffset = 0.0
                                isDragging = false
                            }
                        }
                )
            }
            .frame(height: 20)

            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(volume >= 0.99 ? 1.0 : 0.6))
                .frame(width: 22)
        }
        .padding(.horizontal, 28)
    }
}

// MARK: - 8. Mini Live Equalizer in MiniPlayer
public struct ConvxMiniEqualizerView: View {
    let isPlaying: Bool
    let accentColor: Color

    public init(isPlaying: Bool, accentColor: Color = .white) {
        self.isPlaying = isPlaying
        self.accentColor = accentColor
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isPlaying)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 2.2) {
                ForEach(0..<3, id: \.self) { i in
                    let phase = Double(i) * 1.5
                    let val = isPlaying ? (sin(time * 7.0 + phase) * 0.5 + 0.5) : 0.15
                    let height = max(3.0, CGFloat(val * 12.0))

                    RoundedRectangle(cornerRadius: 1.2)
                        .fill(accentColor.opacity(0.90))
                        .frame(width: 2.5, height: height)
                }
            }
            .frame(width: 14, height: 14, alignment: .bottom)
        }
    }
}

// MARK: - 9. Track Details Technical Inspector Sheet
public struct TrackDetailsInspectorSheet: View {
    let track: SongItem
    @Environment(\.dismiss) private var dismiss

    public init(track: SongItem) {
        self.track = track
    }

    public var body: some View {
        ZStack {
            MeshGradientBackground().allowsHitTesting(false)

            VStack(spacing: 20) {
                Capsule()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 36, height: 5)
                    .padding(.top, 14)

                HStack(spacing: 16) {
                    ArtworkImageView(urlString: track.thumbnail, songId: track.id, size: 68, cornerRadius: 14)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(track.artistNames)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)

                VStack(spacing: 14) {
                    detailRow(title: "Media ID", value: track.id)
                    detailRow(title: "Audio Stream Codec", value: "AAC (mp4a.40.2)")
                    detailRow(title: "Nominal Bitrate", value: "128-160 kbps Variable")
                    detailRow(title: "Sample Rate", value: "44.1 kHz Stereo")
                    detailRow(title: "Provider Engine", value: "VisionOS Unthrottled")
                    detailRow(title: "Offline Storage", value: DownloadService.shared.isDownloaded(track.id) ? "Downloaded (.m4a)" : "Streaming Cache")
                }
                .padding(18)
                .liquidGlass(cornerRadius: 20, opacity: 0.85)
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title).font(.system(size: 13, weight: .medium)).foregroundColor(.white.opacity(0.6))
            Spacer()
            Text(value).font(.system(size: 13, weight: .semibold, design: .monospaced)).foregroundColor(.white)
        }
    }
}

// MARK: - 10. Swipe-to-Queue Ergonomic Song Row
public struct SwipeableSongRow<Content: View>: View {
    let song: SongItem
    let onPlayNext: () -> Void
    let content: Content

    @State private var dragOffset: CGFloat = 0.0
    @State private var hasPassedThreshold = false

    private let threshold: CGFloat = 75.0
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let rigidFeedback = UIImpactFeedbackGenerator(style: .rigid)

    public init(song: SongItem, onPlayNext: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.song = song
        self.onPlayNext = onPlayNext
        self.content = content()
        selectionFeedback.prepare()
        rigidFeedback.prepare()
    }

    public var body: some View {
        ZStack(alignment: .leading) {
            // Action background revealed behind swipe
            if dragOffset > 4 {
                HStack(spacing: 8) {
                    Image(systemName: "text.line.first.and.arrowtriangle.forward")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(hasPassedThreshold ? .white : .cyan)
                    Text("A continuación")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(hasPassedThreshold ? .white : .cyan)
                    Spacer()
                }
                .padding(.leading, 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(hasPassedThreshold ? Color.cyan.opacity(0.85) : Color.cyan.opacity(0.25))
                )
            }

            // Foreground Content
            content
                .offset(x: dragOffset)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 15, coordinateSpace: .local)
                        .onChanged { value in
                            let horizontal = value.translation.width
                            let vertical = value.translation.height
                            if abs(vertical) < abs(horizontal) && horizontal > 0 {
                                let resistance = horizontal < threshold ? horizontal : (threshold + pow(horizontal - threshold, 0.65))
                                dragOffset = max(0, resistance)

                                if horizontal >= threshold && !hasPassedThreshold {
                                    hasPassedThreshold = true
                                    selectionFeedback.selectionChanged()
                                } else if horizontal < threshold && hasPassedThreshold {
                                    hasPassedThreshold = false
                                }
                            }
                        }
                        .onEnded { value in
                            if hasPassedThreshold {
                                rigidFeedback.impactOccurred()
                                onPlayNext()
                            }
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                                dragOffset = 0
                                hasPassedThreshold = false
                            }
                        }
                )
        }
    }
}
