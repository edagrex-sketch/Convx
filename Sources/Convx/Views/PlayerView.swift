import SwiftUI

public enum PlayerMode {
    case cover
    case lyrics
    case visualizer
    case queue
}

public struct PlayerView: View {
    @ObservedObject var player = AudioPlayerService.shared
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var sleepTimer = SleepTimerService.shared
    @ObservedObject var dsp = AudiophileDSPService.shared
    @ObservedObject var singAlong = SingAlongService.shared
    @ObservedObject var dj = DJEngineService.shared
    @ObservedObject var neuro = BrainwaveModulatorService.shared
    @ObservedObject var livi = DJLiviService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var mode: PlayerMode = .cover
    @State private var showingAddToPlaylist = false
    @State private var showingInspector = false
    @State private var showingArtistDetail = false
    @State private var showingAlbumDetail = false
    @State private var showingDSPSheet = false
    @State private var showingSingAlongSheet = false
    @State private var burstTrigger = 0

    public init() {}

    public var body: some View {
        ZStack {
            // Ambient Backdrop
            MeshGradientBackground()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                // Top Grabber
                Capsule()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 36, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 8)

                // Top Bar: Dismiss Chevron + Sleep Timer Pill + Menu
                HStack {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        player.isPresentingFullPlayer = false
                        dismiss()
                    }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white.opacity(0.75))
                            .frame(width: 40, height: 40)
                    }

                    Spacer()

                    // Audiophile DSP / Sing-Along Status Pills
                    HStack(spacing: 8) {
                        // DSP Equalizer Preset Pill
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showingDSPSheet = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: dsp.selectedPreset.icon)
                                    .font(.system(size: 10, weight: .bold))
                                Text(dsp.selectedPreset.rawValue)
                                    .font(.system(size: 11, weight: .bold))
                                    .lineLimit(1)
                            }
                            .foregroundColor(theme.activeAccentColor)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(theme.activeAccentColor.opacity(0.18))
                            .clipShape(Capsule())
                        }

                        // Sing-Along Pill (if active)
                        if singAlong.isSingAlongEnabled {
                            Button(action: {
                                showingSingAlongSheet = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "mic.fill")
                                        .font(.system(size: 10))
                                    Text("Karaoke")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .foregroundColor(.pink)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color.pink.opacity(0.2))
                                .clipShape(Capsule())
                            }
                        }

                        // Sleep Timer Active Pill (if active)
                        if sleepTimer.isActive {
                            HStack(spacing: 4) {
                                Image(systemName: "moon.fill")
                                    .font(.system(size: 10))
                                Text(sleepTimer.formattedRemainingTime)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                            }
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.orange.opacity(0.18))
                            .clipShape(Capsule())
                            .transition(.scale.combined(with: .opacity))
                        }
                    }

                    Spacer()

                    Menu {
                        // Sleep Timer Submenu
                        Menu {
                            ForEach(SleepTimerOption.allCases) { opt in
                                Button(action: { sleepTimer.setTimer(to: opt) }) {
                                    HStack {
                                        Text(opt.rawValue)
                                        if sleepTimer.currentOption == opt {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Label("Temporizador de Sueño", systemImage: "moon.stars")
                        }

                        // Player Mode Submenu
                        Menu {
                            ForEach(PlayerCoverStyle.allCases) { style in
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                        theme.selectedCoverStyle = style
                                    }
                                }) {
                                    HStack {
                                        Label(style.rawValue, systemImage: style.icon)
                                        if theme.selectedCoverStyle == style {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Label("Estilo de Reproductor", systemImage: "paintbrush")
                        }

                        Divider()

                        if let current = player.currentTrack {
                            if DownloadService.shared.isDownloaded(current.id) {
                                Button(role: .destructive, action: {
                                    DownloadService.shared.deleteDownload(for: current.id)
                                }) {
                                    Label("Eliminar descarga", systemImage: "trash")
                                }
                            } else {
                                Button(action: {
                                    DownloadService.shared.startDownload(for: current)
                                }) {
                                    Label("Descargar canción", systemImage: "arrow.down.circle")
                                }
                            }

                            if let firstArtist = current.artists.first, let artistId = firstArtist.id, !artistId.isEmpty {
                                Button(action: { showingArtistDetail = true }) {
                                    Label("Ver Artista: \(firstArtist.name)", systemImage: "person.circle")
                                }
                            }

                            if let album = current.album, !album.id.isEmpty {
                                Button(action: { showingAlbumDetail = true }) {
                                    Label("Ver Álbum: \(album.name)", systemImage: "opticaldisc")
                                }
                            }
                        }

                        Button(action: { showingAddToPlaylist = true }) {
                            Label("Agregar a Playlist...", systemImage: "text.badge.plus")
                        }

                        Button(action: { showingInspector = true }) {
                            Label("Detalles Técnicos", systemImage: "info.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white.opacity(0.75))
                            .frame(width: 40, height: 40)
                    }
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 6)

                // Main Center Stage: Modern Artwork, Retro Vinyl, or Visualizer
                Group {
                    switch mode {
                    case .cover:
                        ZStack {
                            switch theme.selectedCoverStyle {
                            case .modern:
                                ConvxBreathingArtwork(
                                    urlString: player.currentTrack?.thumbnail,
                                    songId: player.currentTrack?.id,
                                    isPlaying: player.isPlaying,
                                    size: 260,
                                    accentColor: theme.activeAccentColor
                                )
                            case .vinyl:
                                RetroVinylView(
                                    track: player.currentTrack,
                                    isPlaying: player.isPlaying,
                                    size: 260
                                )
                            case .visualizer:
                                MinimalistVisualizerView(
                                    track: player.currentTrack,
                                    isPlaying: player.isPlaying,
                                    accentColor: theme.activeAccentColor
                                )
                            case .djLivi:
                                // Comentado temporalmente: fallback a modern artwork
                                ConvxBreathingArtwork(
                                    urlString: player.currentTrack?.thumbnail,
                                    songId: player.currentTrack?.id,
                                    isPlaying: player.isPlaying,
                                    size: 260,
                                    accentColor: theme.activeAccentColor
                                )
                            }

                            // Micro-interaction: Double tap heart explosion overlay
                            HeartParticleBurstView(trigger: $burstTrigger)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            burstTrigger += 1
                            if !player.isLiked {
                                player.toggleLike()
                            }
                        }
                        .onLongPressGesture(minimumDuration: 0.45) {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            showingInspector = true
                        }

                    case .lyrics:
                        ConvxSyncedLyricsView()
                    case .visualizer:
                        VisualizerView()
                    case .queue:
                        QueueView()
                    }
                }
                .frame(maxHeight: 275)

                Spacer(minLength: 10)

                // Track Title & Like Row
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(player.currentTrack?.title ?? "Not Playing")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Button(action: {
                            if let current = player.currentTrack, let first = current.artists.first, let aId = first.id, !aId.isEmpty {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                showingArtistDetail = true
                            }
                        }) {
                            Text(player.currentTrack?.artistNames ?? "")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.65))
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    if let current = player.currentTrack {
                        DownloadButton(song: current, size: 24)
                            .padding(.trailing, 6)
                    }

                    // Like Button with Particle Explosion
                    ConvxHeartExplosionButton()
                }
                .padding(.horizontal, 28)

                Spacer(minLength: 10)

                // Tactile Scrubber with Magnification & Time Bubble
                ConvxTactileScrubber(accentColor: theme.activeAccentColor)

                Spacer(minLength: 10)

                // Transport Controls
                HStack {
                    // Shuffle
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        player.toggleShuffle()
                    }) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(player.isShuffled ? theme.activeAccentColor : .white.opacity(0.65))
                            .frame(width: 44, height: 44)
                    }

                    Spacer()

                    // Previous
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        player.skipPrevious()
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }

                    Spacer()

                    // Play / Pause with Bouncy Spring Physics
                    ConvxPlayPauseButton()

                    Spacer()

                    // Next
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        player.skipNext()
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }

                    Spacer()

                    // Repeat / Loop
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }) {
                        Image(systemName: "repeat")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.65))
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 10)

                // Tactile Volume Slider with Peak Boundary Haptics
                ConvxTactileVolumeSlider(accentColor: theme.activeAccentColor)

                Spacer(minLength: 10)

                // Bottom Toolbar: Lyrics, 120 FPS Visualizer, Sing-Along, DSP Suite, AirPlay, Queue
                HStack(spacing: 0) {
                    // Lyrics Toggle
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            mode = (mode == .lyrics) ? .cover : .lyrics
                        }
                    }) {
                        Image(systemName: "quote.bubble")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundColor(mode == .lyrics ? theme.activeAccentColor : .white.opacity(0.65))
                            .frame(width: 38, height: 38)
                            .background(mode == .lyrics ? theme.activeAccentColor.opacity(0.22) : Color.clear)
                            .clipShape(Circle())
                    }

                    Spacer()

                    // 120 FPS Real-Time Visualizer
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            mode = (mode == .visualizer) ? .cover : .visualizer
                        }
                    }) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(mode == .visualizer ? theme.activeAccentColor : .white.opacity(0.65))
                            .frame(width: 38, height: 38)
                            .background(mode == .visualizer ? theme.activeAccentColor.opacity(0.22) : Color.clear)
                            .clipShape(Circle())
                    }

                    Spacer()

                    // Sing-Along / Karaoke Button
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showingSingAlongSheet = true
                    }) {
                        Image(systemName: singAlong.isSingAlongEnabled ? "mic.fill" : "mic")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundColor(singAlong.isSingAlongEnabled ? .pink : .white.opacity(0.65))
                            .frame(width: 38, height: 38)
                            .background(singAlong.isSingAlongEnabled ? Color.pink.opacity(0.25) : Color.clear)
                            .clipShape(Circle())
                    }

                    Spacer()

                    // Audiophile DSP Suite Quick Button
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showingDSPSheet = true
                    }) {
                        Image(systemName: "slider.vertical.3")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.65))
                            .frame(width: 38, height: 38)
                            .clipShape(Circle())
                    }

                    Spacer()

                    // DJ Livi AI Curator Fast Trigger / Shift (Comentado temporalmente)
                    // DJLiviFloatingButton()
                    // Spacer()

                    // AirPlay
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }) {
                        Image(systemName: "airplayaudio")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.65))
                            .frame(width: 38, height: 38)
                    }

                    Spacer()

                    // Queue Toggle
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            mode = (mode == .queue) ? .cover : .queue
                        }
                    }) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundColor(mode == .queue ? theme.activeAccentColor : .white.opacity(0.65))
                            .frame(width: 38, height: 38)
                            .background(mode == .queue ? theme.activeAccentColor.opacity(0.22) : Color.clear)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 20)
            }
        }
        .clipped()
        .sheet(isPresented: $showingDSPSheet) {
            AudiophileDSPSheet()
        }
        .sheet(isPresented: $showingSingAlongSheet) {
            SingAlongSheet()
        }
        .sheet(isPresented: $showingAddToPlaylist) {
            if let track = player.currentTrack {
                AddToPlaylistSheet(song: track)
            }
        }
        .sheet(isPresented: $showingInspector) {
            if let track = player.currentTrack {
                TrackDetailsInspectorSheet(track: track)
            }
        }
        .sheet(isPresented: $showingArtistDetail) {
            if let track = player.currentTrack, let first = track.artists.first, let aId = first.id {
                ArtistDetailView(artistId: aId, initialName: first.name, initialThumbnail: track.thumbnail)
            }
        }
        .sheet(isPresented: $showingAlbumDetail) {
            if let track = player.currentTrack, let album = track.album, !album.id.isEmpty {
                AlbumDetailView(albumId: album.id, initialTitle: album.name, initialArtist: track.artistNames, initialThumbnail: track.thumbnail)
            }
        }
        // .sheet(isPresented: $livi.isSheetPresented) {
        //     DJLiviChatSheet()
        // }
        .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
            if theme.shakeToShuffleEnabled {
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                player.toggleShuffle()
            }
        }
    }
}
